import SwiftUI

// MARK: - Search sheet (full-screen)

struct SearchSheet: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var engine: PlayerEngine
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var searching = false
    @State private var songs: [Song] = []
    @State private var albums: [Album] = []
    @State private var artists: [Artist] = []
    @State private var playlists: [Playlist] = []
    @State private var genres: [MusicGenre] = []
    @State private var error: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                results
            }
            .background(Theme.bg)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("Close search")
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.themeMutedFg)
            TextField("Songs, albums, artists…", text: $query)
                .textFieldStyle(.plain)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .accessibilityLabel("Search your library")
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .foregroundStyle(Color.themeMutedFg)
                    .accessibilityLabel("Clear search")
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 24).fill(Theme.muted))
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .onChange(of: query) { _, q in runSearch(q) }
    }

    @ViewBuilder
    private var results: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    EmptyState(icon: "music.note", title: "Your whole library",
                               text: "Search every song, album, artist, playlist and genre.")
                } else if let error {
                    EmptyState(icon: "wifi.exclamationmark", title: "Can't search", text: error)
                } else if isAllEmpty {
                    EmptyState(icon: "magnifyingglass", title: "No results",
                               text: "Nothing in your library matches “\(query)”.")
                } else {
                    if !songs.isEmpty { group("Songs") { ForEach(songs) { row($0) } } }
                    if !albums.isEmpty { group("Albums") { ForEach(albums) { albumRow($0) } } }
                    if !artists.isEmpty { group("Artists") { ForEach(artists) { artistRow($0) } } }
                    if !playlists.isEmpty { group("Playlists") { ForEach(playlists) { playlistRow($0) } } }
                    if !genres.isEmpty { group("Genres") { ForEach(genres) { genreRow($0) } } }
                }
            }
            .padding(.bottom, 40)
        }
    }

    private var isAllEmpty: Bool {
        songs.isEmpty && albums.isEmpty && artists.isEmpty && playlists.isEmpty && genres.isEmpty
    }

    private func group(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(1.8)
                .textCase(.uppercase)
                .foregroundStyle(Theme.cream)
                .padding(.bottom, 6)
            VStack(spacing: 0) { content() }
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    private func row(_ song: Song) -> some View {
        Button {
            Haptics.tap()
            play(song, in: song.albumName)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                ArtThumb(url: artURL(song.albumId ?? song.id), sample: sampleArt(song))
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title).font(.system(size: 14, weight: .medium)).lineLimit(1).foregroundStyle(Theme.fg)
                    Text("\(song.artistName) · \(song.albumName)").font(.system(size: 12)).lineLimit(1).foregroundStyle(Color.themeMutedFg)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "shuffle").font(.system(size: 13)).foregroundStyle(Theme.cream)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Play \(song.title) by \(song.artistName), shuffled")
    }

    private func albumRow(_ a: Album) -> some View {
        Button {
            Haptics.tap()
            Task { await playAlbum(a) }
            dismiss()
        } label: { genericRow(title: a.name, detail: "\(a.artist ?? "") · \(a.year.map(String.init) ?? "")", art: artURL(a.id)) }
            .accessibilityLabel("Shuffle play album \(a.name)")
    }

    private func artistRow(_ a: Artist) -> some View {
        Button {
            Haptics.tap()
            Task { await playArtist(a) }
            dismiss()
        } label: { genericRow(title: a.name, detail: "Artist · \(a.albumCount ?? 0) albums", art: artURL(a.id)) }
            .accessibilityLabel("Shuffle play artist \(a.name)")
    }

    private func playlistRow(_ p: Playlist) -> some View {
        Button {
            Haptics.tap()
            Task { await playPlaylist(p) }
            dismiss()
        } label: { genericRow(title: p.name, detail: "Playlist · \(p.songCount ?? 0) songs", art: nil) }
            .accessibilityLabel("Shuffle play playlist \(p.name)")
    }

    private func genreRow(_ g: MusicGenre) -> some View {
        Button {
            Haptics.tap()
            Task { await playGenre(g.value) }
            dismiss()
        } label: { genericRow(title: g.value, detail: "Genre · \(g.songCount ?? 0) songs", art: nil) }
            .accessibilityLabel("Shuffle play genre \(g.value)")
    }

    private func genericRow(title: String, detail: String, art: URL?) -> some View {
        HStack(spacing: 12) {
            ArtThumb(url: art, sample: nil).frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .medium)).lineLimit(1).foregroundStyle(Theme.fg)
                Text(detail).font(.system(size: 12)).lineLimit(1).foregroundStyle(Color.themeMutedFg)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "shuffle").font(.system(size: 13)).foregroundStyle(Theme.cream)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - Actions

    private func runSearch(_ q: String) {
        searchTask?.cancel()
        let trimmed = q.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            songs = []; albums = []; artists = []; playlists = []; genres = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // debounce
            guard !Task.isCancelled else { return }
            await performSearch(trimmed)
        }
    }

    private func performSearch(_ q: String) async {
        guard app.server.isValid, let client = engine.clientForViews ?? client() else {
            // Sample mode: filter built-in tracks.
            let needle = q.lowercased()
            songs = AppModel.sampleTracks.filter {
                [$0.title, $0.albumName, $0.artistName, $0.composer ?? "", $0.genre ?? ""]
                    .contains { $0.lowercased().contains(needle) }
            }
            albums = []; artists = []; playlists = []; genres = []
            return
        }
        do {
            let r = try await client.search3(q)
            songs = r.searchResult3.song ?? []
            albums = r.searchResult3.album ?? []
            artists = r.searchResult3.artist ?? []
            error = nil
            if playlists.isEmpty, genres.isEmpty {
                playlists = (try? await client.getPlaylists())?.filter { $0.name.lowercased().contains(q.lowercased()) } ?? []
                genres = (try? await client.genres())?.filter { $0.value.lowercased().contains(q.lowercased()) } ?? []
            }
        } catch {
            if !Task.isCancelled { self.error = (error as? SubsonicError)?.errorDescription ?? "Search failed." }
        }
    }

    private func client() -> SubsonicClient? { app.server.isValid ? SubsonicClient(config: app.server) : nil }

    private func artURL(_ id: String) -> URL? {
        guard app.server.isValid else { return nil }
        return (engine.clientForViews ?? client())?.coverArtURL(id: id, size: 128)
    }

    private func sampleArt(_ song: Song) -> String? {
        app.sampleMode ? AppModel.sampleArt(for: song) : nil
    }

    @MainActor
    private func play(_ song: Song, in collection: String) {
        if app.sampleMode || !app.server.isValid {
            engine.setQueue(AppModel.sampleTracks, startID: song.id, shuffled: false, collectionName: collection)
            engine.play()
        } else {
            engine.setQueue([song] + songs.filter { $0.id != song.id }, startID: song.id, shuffled: false, collectionName: collection)
            engine.play()
        }
    }

    @MainActor
    private func playAlbum(_ a: Album) async {
        guard let client = engine.clientForViews ?? client() else { return }
        if let full = try? await client.getAlbum(id: a.id), let list = full.song, !list.isEmpty {
            engine.setQueue(list, startID: nil, shuffled: true, collectionName: a.name)
            engine.play()
        }
    }

    @MainActor
    private func playArtist(_ a: Artist) async {
        guard let client = engine.clientForViews ?? client() else { return }
        var all: [Song] = []
        if let artist = try? await client.getArtist(id: a.id), let albums = artist.album {
            for alb in albums {
                if let full = try? await client.getAlbum(id: alb.id), let s = full.song { all += s }
            }
        }
        if !all.isEmpty {
            engine.setQueue(all, startID: nil, shuffled: true, collectionName: a.name)
            engine.play()
        }
    }

    @MainActor
    private func playPlaylist(_ p: Playlist) async {
        guard let client = engine.clientForViews ?? client() else { return }
        if let full = try? await client.getPlaylist(id: p.id), let list = full.song, !list.isEmpty {
            engine.setQueue(list, startID: nil, shuffled: true, collectionName: p.name)
            engine.play()
        }
    }

    @MainActor
    private func playGenre(_ g: String) async {
        guard let client = engine.clientForViews ?? client() else { return }
        if let list = try? await client.getRandomSongs(genre: g), !list.isEmpty {
            engine.setQueue(list, startID: nil, shuffled: true, collectionName: g)
            engine.play()
        }
    }
}

// MARK: - Shared bits

struct ArtThumb: View {
    let url: URL?
    let sample: String?
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Theme.muted
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "music.note").font(.system(size: 16)).foregroundStyle(Color.themeMutedFg)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .task(id: url?.absoluteString ?? sample) {
            if let sample { image = UIImage(named: sample); return }
            guard let url else { return }
            if let (data, _) = try? await URLSession.shared.data(from: url) { image = UIImage(data: data) }
        }
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(Theme.cream)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Theme.muted))
            Text(title).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(Theme.fg)
            Text(text).font(.system(size: 13)).foregroundStyle(Color.themeMutedFg)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}