import Foundation
import CryptoKit

enum SubsonicError: LocalizedError {
    case badURL
    case serverUnreachable
    case authFailed
    case apiError(String)
    case emptyResults
    case decoding

    var errorDescription: String? {
        switch self {
        case .badURL: return "The server URL is not valid."
        case .serverUnreachable: return "Server unreachable. Check the address and your network."
        case .authFailed: return "Sign-in failed. Check the username and password."
        case .apiError(let m): return m
        case .emptyResults: return "No results."
        case .decoding: return "The server sent data this app could not read."
        }
    }
}

struct ServerConfig: Codable, Equatable {
    var name: String
    var url: String
    var username: String
    var password: String

    static let placeholder = ServerConfig(name: "SmartHub", url: "", username: "", password: "")

    var isValid: Bool {
        guard let base = URL(string: url), let scheme = base.scheme,
              scheme == "http" || scheme == "https", !username.isEmpty, !password.isEmpty
        else { return false }
        return true
    }
}

struct SubsonicResponse<T: Codable>: Codable {
    var subsonicResponse: T
}

/// Status fields present in every subsonic-response envelope.
struct SubsonicStatus: Codable {
    let status: String
    let version: String?
    let openSubsonicExtensions: [OpenSubsonicExtension]?
    var error: SubsonicAPIError?
    let type: String?
    let serverVersion: String?
}
struct OpenSubsonicExtension: Codable {
    let name: String
    let versions: [Int]
}
struct SubsonicAPIError: Codable {
    let code: Int
    let message: String?
}

/// Subsonic API client — salt + md5 token auth, async/await URLSession, direct streaming.
final class SubsonicClient: @unchecked Sendable {
    private(set) var config: ServerConfig
    private let session: URLSession

    init(config: ServerConfig) {
        self.config = config
        let s = URLSessionConfiguration.default
        s.timeoutIntervalForRequest = 15
        s.waitsForConnectivity = false
        self.session = URLSession(configuration: s)
    }

    func update(config: ServerConfig) { self.config = config }

    // MARK: - Auth helpers

    private func salt() -> String {
        (0..<12).map { _ in String(format: "%c", Int.random(in: 97...122)) }.joined()
    }

    /// token = md5(password + salt), hex lowercase — per the Subsonic auth scheme.
    private func token(salt: String) -> String {
        let digest = Insecure.MD5.hash(data: Data((config.password + salt).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func baseParams() -> [URLQueryItem] {
        let s = salt()
        return [
            .init(name: "u", value: config.username),
            .init(name: "t", value: token(salt: s)),
            .init(name: "s", value: s),
            .init(name: "v", value: "1.16.1"),
            .init(name: "c", value: "NowPlaying"),
            .init(name: "f", value: "json"),
        ]
    }

    func endpoint(_ path: String, _ extra: [URLQueryItem] = []) throws -> URL {
        guard var comps = URLComponents(string: config.url) else { throw SubsonicError.badURL }
        comps.path = (comps.path.isEmpty ? "" : comps.path) + "/rest/" + path
        var items = baseParams()
        items.append(contentsOf: extra)
        comps.queryItems = items
        guard let url = comps.url else { throw SubsonicError.badURL }
        return url
    }

    // MARK: - Generic request

    @discardableResult
    private func request<T: Codable>(_ path: String, _ extra: [URLQueryItem] = []) async throws -> T {
        let url = try endpoint(path, extra)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw SubsonicError.serverUnreachable
        }
        if let http = response as? HTTPURLResponse, http.statusCode == 401 || http.statusCode == 403 {
            throw SubsonicError.authFailed
        }
        // Check the API-level error/status first, using a plain status envelope,
        // so a server error isn't masked as a decoding failure.
        if let status = try? JSONDecoder().decode(SubsonicResponse<SubsonicStatus>.self, from: data).subsonicResponse, let err = status.error {
            if err.code == 40 || err.code == 50 { throw SubsonicError.authFailed }
            throw SubsonicError.apiError(err.message ?? "Server error \(err.code)")
        }
        let decoded: SubsonicResponse<T>
        do {
            decoded = try JSONDecoder().decode(SubsonicResponse<T>.self, from: data)
        } catch {
            throw SubsonicError.decoding
        }
        return decoded.subsonicResponse
    }

    // MARK: - API calls

    struct PingResult: Equatable {
        let serverVersion: String
        let isNavidrome: Bool
    }

    func ping() async throws -> PingResult {
        let url = try endpoint("ping")
        let data: Data
        do { (data, _) = try await session.data(from: url) } catch { throw SubsonicError.serverUnreachable }
        let decoded: SubsonicResponse<SubsonicStatus>
        do { decoded = try JSONDecoder().decode(SubsonicResponse<SubsonicStatus>.self, from: data) } catch { throw SubsonicError.decoding }
        if let err = decoded.subsonicResponse.error {
            if err.code == 40 || err.code == 50 { throw SubsonicError.authFailed }
            throw SubsonicError.apiError(err.message ?? "Server error \(err.code)")
        }
        let isNavidrome = (decoded.subsonicResponse.type ?? "").lowercased().contains("navidrome")
        return PingResult(serverVersion: decoded.subsonicResponse.version ?? "unknown", isNavidrome: isNavidrome)
    }

    private struct Empty: Codable { }

    struct SearchResult: Codable {
        struct Result: Codable {
            var artist: [Artist]?
            var album: [Album]?
            var song: [Song]?
        }
        let searchResult3: Result
    }

    /// Universal search: songs + albums + artists, grouped by the caller.
    func search3(_ query: String, limit: Int = 30) async throws -> SearchResult {
        let r: SearchResult = try await request("search3", [
            .init(name: "query", value: query),
            .init(name: "songCount", value: String(limit)),
            .init(name: "albumCount", value: "20"),
            .init(name: "artistCount", value: "15"),
        ])
        return r
    }

    func getAlbum(id: String) async throws -> Album {
        struct W: Codable { let album: Album }
        let w: W = try await request("getAlbum", [.init(name: "id", value: id)])
        return w.album
    }

    func getArtist(id: String) async throws -> Artist {
        struct W: Codable { let artist: Artist }
        let w: W = try await request("getArtist", [.init(name: "id", value: id)])
        return w.artist
    }

    func getRandomSongs(genre: String? = nil, count: Int = 50) async throws -> [Song] {
        struct W: Codable { let randomSongs: SongList }
        struct SongList: Codable { let song: [Song] }
        var extra: [URLQueryItem] = [.init(name: "size", value: String(count))]
        if let genre { extra.append(.init(name: "genre", value: genre)) }
        let w: W = try await request("getRandomSongs", extra)
        return w.randomSongs.song
    }

    func getPlaylists() async throws -> [Playlist] {
        struct W: Codable { let playlists: PlaylistList }
        struct PlaylistList: Codable { let playlist: [Playlist] }
        let w: W = try await request("getPlaylists")
        return w.playlists.playlist
    }

    func getPlaylist(id: String) async throws -> Playlist {
        struct W: Codable { let playlist: Playlist }
        let w: W = try await request("getPlaylist", [.init(name: "id", value: id)])
        return w.playlist
    }

    func star(id: String) async throws { let _: Empty = try await request("star", idParams(id)) }
    func unstar(id: String) async throws { let _: Empty = try await request("unstar", idParams(id)) }

    private func idParams(_ id: String) -> [URLQueryItem] { [.init(name: "id", value: id)] }

    func genres() async throws -> [MusicGenre] {
        struct W: Codable { let genres: GenreList }
        struct GenreList: Codable { let genre: [MusicGenre] }
        let w: W = try await request("getGenres")
        return w.genres.genre
    }

    /// OpenSubsonic lyrics-by-song (Navidrome serves .lrc sidecars through this).
    struct LyricsResult: Codable {
        struct Structured: Codable {
            let artist: String?
            let title: String?
            var line: [Line]?
            struct Line: Codable {
                let start: Int?
                let value: String
            }
        }
        let artist: String?
        let title: String?
        var value: String?
        var structuredContent: [Structured]?

        var hasContent: Bool {
            !(structuredContent?.isEmpty ?? true) || !(value?.isEmpty ?? true)
        }
        /// (startMillis, text) pairs; start nil → unsynced.
        var lines: [(Int?, String)] {
            if let sc = structuredContent, !sc.isEmpty {
                return sc.flatMap { block in (block.line ?? []).map { ($0.start, $0.value) } }
            }
            return (value ?? "").split(separator: "\n", omittingEmptySubsequences: true).map { (nil as Int?, String($0)) }
        }
        var isSynced: Bool { lines.contains { $0.0 != nil } }
    }

    func getLyricsBySongId(id: String) async throws -> LyricsResult? {
        struct W: Codable { let lyricsList: LyricsList }
        struct LyricsList: Codable { let structuredLyrics: [LyricsResult]? }
        let wrapper: W = try await request("getLyricsBySongId", [.init(name: "id", value: id)])
        if let l = wrapper.lyricsList.structuredLyrics?.first { return l }
        return nil
    }

    // MARK: - Media URLs (built, not fetched)

    func streamURL(songID: String) -> URL? {
        try? endpoint("stream", [.init(name: "id", value: songID)])
    }

    func coverArtURL(id: String, size: Int = 1024) -> URL? {
        try? endpoint("getCoverArt", [.init(name: "id", value: id), .init(name: "size", value: String(size))])
    }
}