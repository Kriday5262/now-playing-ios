import SwiftUI
import AVKit

/// Single-screen app: Now Playing is the landing screen. Sheets: Search (full-screen),
/// Up Next / Track Info / Settings / Lyrics (bottom).
struct NowPlayingScreen: View {
    @EnvironmentObject private var engine: PlayerEngine
    @EnvironmentObject private var app: AppModel

    enum Panel: String, Identifiable {
        case search, queue, info, settings, lyrics
        var id: String { rawValue }
    }

    @State private var panel: Panel?
    @State private var metaIndex = 0
    @State private var metaTimer: Timer?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                if app.showUnreachableBanner {
                    UnreachableBanner()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                header
                artBlock
                trackBlock
                controlsBlock
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: app.showUnreachableBanner)
        .sheet(item: $panel) { p in sheetContent(p) }
        .onAppear { startMetaRotation() }
        .onDisappear { metaTimer?.invalidate() }
    }

    private var currentTrack: Song? { engine.currentTrack }
    private var isSample: Bool { app.sampleMode }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { Haptics.soft(); panel = .search } label: {
                Image(systemName: "magnifyingglass").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Search library")

            VStack(spacing: 2) {
                Button { Haptics.soft(); panel = .settings } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape").font(.system(size: 11))
                        Text(app.server.name)
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(2.5)
                            .textCase(.uppercase)
                    }
                    .foregroundStyle(Color.themeMutedFg)
                }
                .accessibilityLabel("Settings for \(app.server.name)")
                Text("Now Playing")
                    .font(.system(size: 24, weight: .bold, design: .condensed))
                    .foregroundStyle(Theme.fg)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            Button { Haptics.soft(); panel = .info } label: {
                Image(systemName: "info.circle").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Track information")
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    // MARK: - Album art

    @ViewBuilder
    private var artBlock: some View {
        RemoteArt(song: currentTrack, sampleMode: isSample, size: nil)
            .frame(maxWidth: 315)
            .aspectRatio(1, contentMode: .fit)
            .modifier(AlbumFrame())
            .overlay(ScanlineOverlay())
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .accessibilityHidden(true) // decorative; title is announced below
    }

    // MARK: - Track block

    private var metaLines: [String] {
        guard let t = currentTrack else { return [] }
        return [
            "\(t.albumName) (\(t.year.map(String.init) ?? "—"))",
            t.artistName,
            "Composed by \(t.composer ?? "Unknown")",
            t.genre ?? "Unknown genre",
        ]
    }

    private var trackBlock: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ComposerAvatar(song: currentTrack, sampleMode: isSample)
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Theme.cream, lineWidth: 2))

                VStack(alignment: .leading, spacing: 4) {
                    Text(currentTrack?.title ?? "Nothing queued")
                        .font(.system(size: 20, weight: .bold, design: .condensed))
                        .foregroundStyle(Theme.fg)
                        .lineLimit(1)
                    // Rotating meta line (2.8 s cadence, fade) — one a11y element.
                    Text(metaLines[min(metaIndex, max(metaLines.count - 1, 0))])
                        .font(.system(size: 14))
                        .foregroundStyle(Color.themeMutedFg)
                        .lineLimit(1)
                        .id(metaIndex)
                        .transition(reduceMotion ? .opacity : .opacity)
                        .animation(reduceMotion ? nil : .easeIn(duration: 0.4), value: metaIndex)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)

                if currentTrack?.isHiRes == true {
                    Text("Hi-Res")
                        .font(.system(size: 10, design: .monospaced))
                        .textCase(.uppercase)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
                        .accessibilityLabel("High resolution audio")
                }
            }
            .padding(.vertical, 12)

            Scrubber()
                .padding(.top, 6)

            HStack {
                Text(timeString(engine.position))
                Spacer()
                Text("−\(timeString(max(0, engine.duration - engine.position)))")
            }
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(Color.themeMutedFg)
            .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    // MARK: - Controls

    private var controlsBlock: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                VStack(spacing: 12) {
                    sideButton("text.bubble") { panel = .lyrics }
                        .accessibilityLabel("Show lyrics")
                    sideButton("repeat", active: engine.repeatOne) { engine.toggleRepeat() }
                        .accessibilityLabel(engine.repeatOne ? "Repeat on" : "Repeat off")
                }

                ControlDial()
                    .frame(width: 192, height: 192)
                    .environmentObject(engine)

                VStack(spacing: 16) {
                    sideButton("list.music") { panel = .queue }
                        .accessibilityLabel("Show queue")
                    sideButton("shuffle", active: engine.shuffle) { engine.toggleShuffle() }
                        .accessibilityLabel(engine.shuffle ? "Shuffle on" : "Shuffle off")
                }
            }
            .padding(.horizontal, 20)

            upNextPill
                .padding(.top, 14)
                .padding(.bottom, 16)
        }
        .padding(.bottom, 24)
    }

    private func sideButton(_ system: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: system)
                .font(.system(size: 18, weight: .medium))
                .frame(width: 44, height: 44)
                .foregroundStyle(active ? Theme.cream : Theme.fg)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(active ? Theme.muted : Theme.card)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.border, lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }

    private var upNextPill: some View {
        Button {
            Haptics.soft()
            panel = .queue
        } label: {
            Group {
                if let next = engine.nextTrack {
                    (Text("Up next: ").fontWeight(.semibold).foregroundStyle(Theme.fg)
                     + Text(next.title).foregroundStyle(Color.themeMutedFg))
                } else {
                    Text("Queue empty").fontWeight(.semibold).foregroundStyle(Theme.fg)
                }
            }
            .font(.system(size: 12))
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().strokeBorder(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(engine.nextTrack.map { "Up next: \($0.title)" } ?? "Queue empty")
    }

    // MARK: - Sheets

    @ViewBuilder
    private func sheetContent(_ p: Panel) -> some View {
        switch p {
        case .search: SearchSheet().presentationDetentsCompat()
        case .queue: QueueSheet().presentationDetentsCompat()
        case .info: InfoSheet().presentationDetentsCompat()
        case .settings: SettingsSheet().presentationDetents([.large])
        case .lyrics: LyricsSheet().presentationDetentsCompat()
        }
    }

    private func startMetaRotation() {
        metaTimer?.invalidate()
        metaTimer = Timer.scheduledTimer(withTimeInterval: 2.8, repeats: true) { _ in
            Task { @MainActor in
                metaIndex = (metaIndex + 1) % max(metaLines.count, 1)
            }
        }
    }

    private func timeString(_ t: Double) -> String {
        let s = max(0, Int(t.rounded()))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

private extension View {
    /// Bottom sheets default to a comfortable detent + expandable.
    func presentationDetentsCompat() -> some View {
        presentationDetents([.medium, .large])
    }
}

// MARK: - Supporting views

struct UnreachableBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.exclamationmark")
            Text("Server unreachable — check Settings").font(.system(size: 13))
        }
        .foregroundStyle(Theme.fg)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Theme.muted)
    }
}

/// Remote album art from getCoverArt, with sample-placeholder fallback.
struct RemoteArt: View {
    let song: Song?
    let sampleMode: Bool
    let size: CGFloat?

    @State private var image: UIImage?
    @EnvironmentObject private var app: AppModel

    var body: some View {
        ZStack {
            Theme.card
            if let image {
                Image(uiImage: image).resizable().scaledToFill().transition(.opacity)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.themeMutedFg)
            }
        }
        .task(id: song?.id) {
            guard let song else { return }
            if sampleMode {
                image = UIImage(named: AppModel.sampleArt(for: song))
                return
            }
            guard let engine = (app.engine),
                  let client = clientOf(engine),
                  let url = client.coverArtURL(id: song.albumId ?? song.id, size: 1024) else { return }
            let (data, _) = try? await URLSession.shared.data(from: url)
            if let data, let img = UIImage(data: data) {
                withAnimation(.easeIn(duration: 0.3)) { image = img }
            }
        }
    }

    private func clientOf(_ engine: PlayerEngine) -> SubsonicClient? { engine.clientForViews }
}

struct ComposerAvatar: View {
    let song: Song?
    let sampleMode: Bool

    @State private var image: UIImage?
    @EnvironmentObject private var app: AppModel

    var body: some View {
        ZStack {
            Theme.muted
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.cream)
            }
        }
        .task(id: song?.composer) {
            guard let song else { return }
            if sampleMode {
                image = UIImage(named: "ComposerPortrait")
                return
            }
            // Composer art falls back to artist image when missing (approved decision).
            guard let engine = app.engine, let client = engine.clientForViews else { return }
            if let artistID = song.artistId, let url = client.coverArtURL(id: artistID, size: 256) {
                if let (data, _) = try? await URLSession.shared.data(from: url), let img = UIImage(data: data) {
                    image = img
                    return
                }
            }
            if let albumID = song.albumId, let url = client.coverArtURL(id: albumID, size: 256) {
                if let (data, _) = try? await URLSession.shared.data(from: url), let img = UIImage(data: data) {
                    image = img
                }
            }
        }
    }
}

/// Scrubber honouring the adjustable VoiceOver trait.
struct Scrubber: View {
    @EnvironmentObject private var engine: PlayerEngine

    var body: some View {
        GeometryReader { geo in
            let d = max(engine.duration, 1)
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.muted).frame(height: 4)
                Capsule().fill(Theme.cream)
                    .frame(width: geo.size.width * CGFloat(min(engine.position / d, 1)), height: 4)
            }
            .frame(height: 24, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { g in
                        let frac = min(max(g.location.x / geo.size.width, 0), 1)
                        Haptics.soft()
                        engine.seek(to: Double(frac) * d)
                    }
            )
            .accessibilityElement()
            .accessibilityLabel("Track progress")
            .accessibilityValue(Text(timeString(engine.position) + " of " + timeString(engine.duration)))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: engine.seek(to: min(engine.position + 10, engine.duration))
                case .decrement: engine.seek(to: max(engine.position - 10, 0))
                @unknown default: break
                }
            }
        }
        .frame(height: 24)
    }

    private func timeString(_ t: Double) -> String {
        let s = max(0, Int(t.rounded()))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}