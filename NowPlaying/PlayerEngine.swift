import AVFoundation
import MediaPlayer
import Foundation

/// AVPlayer-based streaming engine + lock-screen (Now Playing) integration.
/// Queue logic honouring repeat and shuffle; never auto-plays on launch.
@MainActor
final class PlayerEngine: NSObject, ObservableObject {
    // MARK: Published state

    @Published var currentTrack: Song?
    @Published var isPlaying = false
    @Published var position: Double = 0
    @Published var duration: Double = 0
    @Published var repeatOne = false
    @Published var shuffle = false
    @Published var isFavourite = false
    @Published var collectionName = ""

    // Queue in play order (ids). With shuffle on, `shuffledOrder` is used for navigation.
    @Published var queue: [Song] = []
    private var shuffledOrder: [String] = []

    private let player = AVPlayer()
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var client: SubsonicClient?
    private let persistence: PersistenceStore
    private var saveTask: Task<Void, Never>?

    var onTrackChanged: ((Song) -> Void)?

    /// Read-only client access for view-level fetches (art, lyrics, search).
    var clientForViews: SubsonicClient? { client }

    init(persistence: PersistenceStore = PersistenceStore()) {
        self.persistence = persistence
        super.init()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
        setupRemoteCommands()
        addPeriodicTimeObserver()
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleTrackEnded() }
        }
    }

    // MARK: - Configuration

    func configure(client: SubsonicClient) {
        self.client = client
    }

    func configure(server: ServerConfig) {
        configure(client: SubsonicClient(config: server))
    }

    // MARK: - Queue management

    var nextTrack: Song? {
        guard let current = currentTrack, !queue.isEmpty else { return nil }
        let order = effectiveOrder()
        guard let idx = order.firstIndex(of: current.id) else { return nil }
        let next = (idx + 1) % order.count
        return queue.first { $0.id == order[next] }
    }

    private func effectiveOrder() -> [String] {
        shuffle && !shuffledOrder.isEmpty ? shuffledOrder : queue.map { $0.id }
    }

    func setQueue(_ songs: [Song], startID: String?, shuffled: Bool, collectionName name: String) {
        queue = songs
        collectionName = name
        shuffle = shuffled
        reshuffle(keepCurrent: startID)
        if let startID {
            if let song = songs.first(where: { $0.id == startID }) {
                load(song: song, autoplay: false, seekTo: 0)
            }
        }
        persist()
    }

    private func reshuffle(keepCurrent: String?) {
        guard shuffle else { shuffledOrder = []; return }
        var ids = queue.map { $0.id }
        ids.shuffle()
        if let cur = keepCurrent, let idx = ids.firstIndex(of: cur) {
            ids.remove(at: idx)
            ids.insert(cur, at: 0)
        }
        shuffledOrder = ids
    }

    // MARK: - Playback

    func load(song: Song, autoplay: Bool, seekTo: Double = 0) {
        currentTrack = song
        isFavourite = song.starred != nil
        duration = Double(song.durationSeconds)
        position = seekTo
        guard let client, let url = client.streamURL(songID: song.id) else { return }
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        if seekTo > 0 {
            let target = CMTime(seconds: seekTo, preferredTimescale: 600)
            if autoplay {
                player.seek(to: target, toleranceBefore: .zero, toleranceAfter: CMTime(seconds: 2, preferredTimescale: 600)) { [weak self] _ in
                    self?.player.play()
                }
            } else {
                player.seek(to: target)
            }
        } else if autoplay {
            player.play()
        }
        if !autoplay { player.pause() }
        syncPlayingFlag()
        updateNowPlayingInfo()
        persist()
    }

    func play() {
        if currentTrack == nil { return }
        if player.currentItem == nil, let current = currentTrack { load(song: current, autoplay: true) } else { player.play() }
        syncPlayingFlag()
        updateNowPlayingInfo()
        persist()
    }

    func pause() {
        player.pause()
        syncPlayingFlag()
        updateNowPlayingInfo()
        persist()
    }

    func togglePlayPause() { isPlaying ? pause() : play() }

    func skipNext() {
        guard let current = currentTrack, !queue.isEmpty else { return }
        let order = effectiveOrder()
        guard let idx = order.firstIndex(of: current.id) else { return }
        let nextIdx = (idx + 1) % order.count
        if let song = queue.first(where: { $0.id == order[nextIdx] }) {
            load(song: song, autoplay: true)
            onTrackChanged?(song)
        }
    }

    func skipPrevious() {
        // iOS convention: within 3s of start → previous track; else restart.
        if position > 3, let current = currentTrack { load(song: current, autoplay: isPlaying, seekTo: 0) }
        else {
            guard let current = currentTrack, !queue.isEmpty else { return }
            let order = effectiveOrder()
            guard let idx = order.firstIndex(of: current.id) else { return }
            let prevIdx = (idx - 1 + order.count) % order.count
            if let song = queue.first(where: { $0.id == order[prevIdx] }) {
                load(song: song, autoplay: true)
                onTrackChanged?(song)
            }
        }
    }

    func seek(to seconds: Double) {
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: CMTime(seconds: 0.5, preferredTimescale: 600), toleranceAfter: CMTime(seconds: 0.5, preferredTimescale: 600))
        position = seconds
        persist()
    }

    private func handleTrackEnded() {
        if repeatOne { seek(to: 0); play(); return }
        skipNext()
    }

    private func syncPlayingFlag() {
        isPlaying = player.timeControlStatus == .playing || player.rate > 0
    }

    func toggleRepeat() { repeatOne.toggle(); persist() }
    func toggleShuffle() {
        shuffle.toggle()
        reshuffle(keepCurrent: currentTrack?.id)
        persist()
    }

    func setFavourite(_ on: Bool) {
        isFavourite = on
        guard let client, let id = currentTrack?.id else { persist(); return }
        persist()
        Task {
            if on {
                try? await client.star(id: id)
            } else {
                try? await client.unstar(id: id)
            }
        }
    }

    // MARK: - Queue edits (Up Next sheet)

    func removeFromQueue(at offsets: IndexSet) {
        for i in offsets.sorted(by: >) where queue[i].id != currentTrack?.id {
            queue.remove(at: i)
            if shuffle { reshuffle(keepCurrent: currentTrack?.id) }
        }
        persist()
    }

    func moveInQueue(from: IndexSet, to: Int) {
        queue.move(fromOffsets: from, toOffset: to)
        if shuffle { reshuffle(keepCurrent: currentTrack?.id) }
        persist()
    }

    // MARK: - Time observation

    private func addPeriodicTimeObserver() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                self.position = time.seconds
                if let d = self.player.currentItem?.duration.seconds, d.isFinite, d > 0 { self.duration = d }
                self.syncPlayingFlag()
            }
        }
    }

    // MARK: - Remote commands / Now Playing info

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in Task { @MainActor in self?.play() }; return .success }
        center.pauseCommand.addTarget { [weak self] _ in Task { @MainActor in self?.pause() }; return .success }
        center.nextTrackCommand.addTarget { [weak self] _ in Task { @MainActor in self?.skipNext() }; return .success }
        center.previousTrackCommand.addTarget { [weak self] _ in Task { @MainActor in self?.skipPrevious() }; return .success }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let sec = e.positionTime
            Task { @MainActor in self?.seek(to: sec) }
            return .success
        }
        center.changePlaybackRateCommand.isEnabled = false
    }

    private func updateNowPlayingInfo() {
        var info: [String: Any] = [:]
        if let t = currentTrack {
            info[MPMediaItemPropertyTitle] = t.title
            info[MPMediaItemPropertyArtist] = t.artistName
            info[MPMediaItemPropertyAlbumTitle] = t.albumName
            info[MPMediaItemPropertyPlaybackDuration] = duration
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position
            info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        } else {
            info[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        loadArtworkIntoNowPlaying()
    }

    private func loadArtworkIntoNowPlaying() {
        guard let client, let song = currentTrack else { return }
        let coverID = song.albumId ?? song.id
        guard let url = client.coverArtURL(id: coverID, size: 512) else { return }
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data) else { return }
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
            info[MPMediaItemPropertyArtwork] = artwork
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
    }

    // MARK: - Persistence

    var snapshot: PlayerSnapshot {
        PlayerSnapshot(
            currentTrackId: currentTrack?.id,
            positionSec: position,
            queueIds: queue.map { $0.id },
            repeatOne: repeatOne,
            shuffle: shuffle,
            favourite: isFavourite,
            collectionName: collectionName
        )
    }

    func persist(immediate: Bool = false) {
        let snap = snapshot
        if immediate {
            persistence.save(snap)
            return
        }
        saveTask?.cancel()
        saveTask = Task { [persistence] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            persistence.save(snap)
        }
    }

    func flushPersist() { persistence.save(snapshot) }

    func restoreSnapshot(
        _ snap: PlayerSnapshot,
        tracksByID: [String: Song],
        client: SubsonicClient
    ) {
        configure(client: client)
        repeatOne = snap.repeatOne
        shuffle = snap.shuffle
        collectionName = snap.collectionName
        isFavourite = snap.favourite
        queue = snap.queueIds.compactMap { tracksByID[$0] }
        if shuffle { reshuffle(keepCurrent: snap.currentTrackId) }
        guard let id = snap.currentTrackId, let song = tracksByID[id] else { return }
        load(song: song, autoplay: false, seekTo: snap.positionSec)
    }

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }
}