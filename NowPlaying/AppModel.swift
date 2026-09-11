import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var server: ServerConfig {
        didSet { persistServer() }
    }
    @Published var serverStatus: String = ""
    @Published var showUnreachableBanner = false
    @Published var sampleMode = false

    private let persistence = PersistenceStore()
    private let serverKey = "server-config"
    var engine: PlayerEngine?

    init() {
        if let data = UserDefaults.standard.data(forKey: serverKey),
           let cfg = try? JSONDecoder().decode(ServerConfig.self, from: data) {
            server = cfg
        } else {
            server = .placeholder
        }
    }

    func persistServer() {
        if let data = try? JSONEncoder().encode(server) {
            UserDefaults.standard.set(data, forKey: serverKey)
        }
    }

    var hasValidServer: Bool { server.isValid }

    // MARK: - Sample library (until a server is configured / reachable)

    static let sampleTracks: [Song] = [
        Song(id: "s1", title: "Ab Tere Bin Jee Lenge Hum", album: "Aashiqui", albumId: "alb1", artist: "Kumar Sanu", artistId: "ar1", year: 1990, genre: "Filmi Romance", composer: "Nadeem–Shravan", track: 1, duration: 305, bitRate: 320, suffix: "flac"),
        Song(id: "s2", title: "Dheere Dheere Se Meri Zindagi", album: "Aashiqui", albumId: "alb1", artist: "Kumar Sanu, Anuradha Paudwal", artistId: "ar1", year: 1990, genre: "Filmi Romance", composer: "Nadeem–Shravan", track: 2, duration: 388, bitRate: 320, suffix: "flac"),
        Song(id: "s3", title: "Nazar Ke Saamne", album: "Aashiqui", albumId: "alb1", artist: "Kumar Sanu, Anuradha Paudwal", artistId: "ar1", year: 1990, genre: "Filmi Romance", composer: "Nadeem–Shravan", track: 3, duration: 341, bitRate: 320, suffix: "flac"),
        Song(id: "s4", title: "Tanha Tanha", album: "Rangeela", albumId: "alb2", artist: "Asha Bhosle", artistId: "ar2", year: 1995, genre: "Filmi Pop", composer: "A. R. Rahman", track: 1, duration: 340, bitRate: 320, suffix: "flac"),
        Song(id: "s5", title: "Yaaro Sun Lo Zara", album: "Rangeela", albumId: "alb2", artist: "Udit Narayan, K. S. Chithra", artistId: "ar3", year: 1995, genre: "Filmi Pop", composer: "A. R. Rahman", track: 2, duration: 351, bitRate: 320, suffix: "flac"),
        Song(id: "s6", title: "Hai Rama", album: "Rangeela", albumId: "alb2", artist: "Hariharan, Swarnalatha", artistId: "ar4", year: 1995, genre: "Filmi Pop", composer: "A. R. Rahman", track: 3, duration: 310, bitRate: 320, suffix: "flac"),
        Song(id: "s7", title: "Tujhe Dekha To Ye Jaana Sanam", album: "Dilwale Dulhania Le Jayenge", albumId: "alb3", artist: "Lata Mangeshkar, Kumar Sanu", artistId: "ar5", year: 1995, genre: "Filmi Soundtrack", composer: "Jatin–Lalit", track: 1, duration: 292, bitRate: 320, suffix: "flac"),
        Song(id: "s8", title: "Mehndi Laga Ke Rakhna", album: "Dilwale Dulhania Le Jayenge", albumId: "alb3", artist: "Lata Mangeshkar, Udit Narayan", artistId: "ar5", year: 1995, genre: "Filmi Soundtrack", composer: "Jatin–Lalit", track: 2, duration: 380, bitRate: 320, suffix: "flac"),
        Song(id: "s9", title: "Ho Gaya Hai Tujhko To Pyar Sajna", album: "Dilwale Dulhania Le Jayenge", albumId: "alb3", artist: "Lata Mangeshkar, Udit Narayan", artistId: "ar5", year: 1995, genre: "Filmi Soundtrack", composer: "Jatin–Lalit", track: 3, duration: 405, bitRate: 320, suffix: "flac"),
    ]

    static func sampleArt(for song: Song) -> String {
        switch song.albumId {
        case "alb1": return "AlbumAashiqui"
        case "alb2": return "AlbumRangeela"
        case "alb3": return "AlbumDDLJ"
        default: return "AlbumAashiqui"
        }
    }

    /// Restore the persisted snapshot. With a configured server the queue is
    /// rebuilt from the server after the first library fetch; offline/sample mode
    /// restores against the built-in sample tracks.
    func restoreIfNeeded() {
        guard let engine else { return }
        guard let snap = persistence.load() else {
            sampleMode = true
            engine.setQueue(Self.sampleTracks, startID: nil, shuffled: false, collectionName: "Aashiqui")
            if let first = Self.sampleTracks.first {
                engine.load(song: first, autoplay: false) // paused, position 0 — never auto-play
            }
            return
        }
        if let cfg = snap.serverConfig, cfg.isValid { server = cfg }
        if server.isValid {
            engine.configure(server: server)
        } else {
            sampleMode = true
            var byID: [String: Song] = [:]
            for t in Self.sampleTracks { byID[t.id] = t }
            engine.restoreSnapshot(snap, tracksByID: byID, client: SubsonicClient(config: .placeholder))
        }
    }
}