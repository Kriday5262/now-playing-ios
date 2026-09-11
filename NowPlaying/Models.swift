import Foundation

/// Decodes a Subsonic date that may arrive as an ISO-8601 string, an epoch
/// number (seconds or milliseconds), or be absent — Navidrome varies by field.
enum FlexibleDate: Codable, Equatable {
    case date(Date)

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) {
            if let d = SubsonicDateParser.parse(s) { self = .date(d); return }
            throw DecodingError.typeMismatch(Date.self, .init(codingPath: decoder.codingPath, debugDescription: "unparseable date string \(s)"))
        }
        if let n = try? c.decode(Double.self) {
            let seconds = n > 99_999_999_999 ? n / 1000 : n
            self = .date(Date(timeIntervalSince1970: seconds)); return
        }
        self = .date(Date(timeIntervalSince1970: 0))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(timeIntervalSince1970)
    }

    var timeIntervalSince1970: TimeInterval {
        if case .date(let d) = self { return d.timeIntervalSince1970 }
        return 0
    }
}

enum SubsonicDateParser {
    static let formats = ["yyyy-MM-dd'T'HH:mm:ss.SSSZ", "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ", "yyyy-MM-dd'T'HH:mm:ssZZZZZ"]
    static func parse(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        if let d = f.date(from: s) { return d }
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f2.date(from: s) { return d }
        for fmt in formats {
            let df = DateFormatter()
            df.dateFormat = fmt
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone(identifier: "UTC")
            if let d = df.date(from: s) { return d }
        }
        return nil
    }
}


/// A song returned by the Subsonic API (search3 / getAlbum / getRandomSongs / getPlaylist).
struct Song: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let title: String
    var album: String?
    var albumId: String?
    var artist: String?
    var artistId: String?
    var year: Int?
    var genre: String?
    var composer: String?
    var track: Int?
    var duration: Int?
    var bitRate: Int?
    var suffix: String?
    var size: Int?
    var path: String?
    var isVideo: Bool?
    var starred: FlexibleDate?
    var discNumber: Int?
    var created: FlexibleDate?
    var parent: String?

    var durationSeconds: Int { duration ?? 0 }
    /// Sample-protocol threshold: ≥ 256 kbps counts as Hi-Res for the badge.
    var isHiRes: Bool { (bitRate ?? 0) >= 256 }
    var artistName: String { artist ?? "Unknown artist" }
    var albumName: String { album ?? "Unknown album" }
}

struct Album: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    var artist: String?
    var artistId: String?
    var year: Int?
    var genre: String?
    var songCount: Int?
    var duration: Int?
    var created: FlexibleDate?
    var song: [Song]?
}

struct Artist: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    var albumCount: Int?
    var starred: FlexibleDate?
    var album: [Album]?
}

struct Playlist: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    var songCount: Int?
    var duration: Int?
    var owner: String?
    var song: [Song]?
}

struct MusicGenre: Identifiable, Codable, Equatable, Hashable {
    var id: String { value }
    let value: String
    var songCount: Int?
    var albumCount: Int?
}

enum MusicCollection: Equatable {
    case album(String)
    case artist(String)
    case playlist(String)
    case genre(String)
    case random

    var label: String {
        switch self {
        case .album(let v): return v
        case .artist(let v): return v
        case .playlist(let v): return v
        case .genre(let v): return v
        case .random: return "Random"
        }
    }
}