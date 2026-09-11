import Foundation

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
    var starred: Date?
    var discNumber: Int?
    var created: Date?
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
    var created: Date?
    var song: [Song]?
}

struct Artist: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    var albumCount: Int?
    var starred: Date?
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