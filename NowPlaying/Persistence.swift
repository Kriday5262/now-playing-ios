import Foundation

/// Persisted player snapshot — saved on every change and on scenePhase .background.
struct PlayerSnapshot: Codable, Equatable {
    var currentTrackId: String?
    var positionSec: Double
    var queueIds: [String]
    var repeat: Bool
    var shuffle: Bool
    var favourite: Bool
    var collectionName: String
    var serverConfig: ServerConfig?
}

final class PersistenceStore {
    private let url: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NowPlaying", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("player-state.json")
    }

    func save(_ snapshot: PlayerSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func load() -> PlayerSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(PlayerSnapshot.self, from: data)
    }

    func clear() { try? FileManager.default.removeItem(at: url) }
}