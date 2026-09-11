import SwiftUI

// MARK: - Up Next queue sheet

struct QueueSheet: View {
    @EnvironmentObject private var engine: PlayerEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                if engine.queue.isEmpty {
                    EmptyState(icon: "list.music", title: "Queue is empty",
                               text: "Choose something from search to start a new queue.")
                    Spacer()
                } else {
                    Text("Up next in ")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.themeMutedFg)
                        + Text(engine.collectionName).fontWeight(.semibold).foregroundStyle(Theme.fg)
                    List {
                        ForEach(Array(engine.queue.enumerated()), id: \.element.id) { idx, song in
                            QueueRow(song: song, isCurrent: engine.currentTrack?.id == song.id) {
                                Haptics.tap()
                                engine.load(song: song, autoplay: true)
                            }
                        }
                        .onDelete { offsets in
                            Haptics.soft()
                            engine.removeFromQueue(at: offsets)
                        }
                        .onMove { from, to in
                            Haptics.soft()
                            engine.moveInQueue(from: from, to: to)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .environment(\.editMode, .constant(.active))
                }
            }
            .padding(.horizontal, 16)
            .background(Theme.bg)
            .navigationTitle("Up Next")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close queue")
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct QueueRow: View {
    let song: Song
    let isCurrent: Bool
    let play: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 13))
                .foregroundStyle(Color.themeMutedFg)
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.system(size: 14, weight: isCurrent ? .bold : .medium))
                    .foregroundStyle(isCurrent ? Theme.cream : Theme.fg)
                    .lineLimit(1)
                Text(song.artistName).font(.system(size: 12)).foregroundStyle(Color.themeMutedFg).lineLimit(1)
            }
            Spacer()
            Text(duration).font(.system(size: 11, design: .monospaced)).foregroundStyle(Color.themeMutedFg)
        }
        .contentShape(Rectangle())
        .onTapGesture { play() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isCurrent ? "Now playing \(song.title)" : "Play \(song.title)")
    }

    private var duration: String {
        let s = song.durationSeconds
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Track info sheet

struct InfoSheet: View {
    @EnvironmentObject private var engine: PlayerEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let t = engine.currentTrack {
                        HStack(spacing: 14) {
                            ArtThumb(url: nil, sample: AppModel.sampleArt(for: t))
                                .frame(width: 88, height: 88)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(t.title).font(.system(size: 22, weight: .bold, design: .rounded)).lineLimit(2).foregroundStyle(Theme.fg)
                                Text(t.artistName).font(.system(size: 13)).foregroundStyle(Color.themeMutedFg).lineLimit(1)
                            }
                        }
                        infoRows(t)
                    } else {
                        EmptyState(icon: "music.note", title: "Nothing playing", text: "Queue a song first.")
                    }
                }
                .padding(20)
            }
            .background(Theme.bg)
            .navigationTitle("Track Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close track info")
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func infoRows(_ t: Song) -> some View {
        let rows: [(String, String)] = [
            ("Title", t.title),
            ("Album", t.albumName),
            ("Year", t.year.map(String.init) ?? "—"),
            ("Artist", t.artistName),
            ("Composer", t.composer ?? "—"),
            ("Genre", t.genre ?? "—"),
            ("Track", t.track.map { "\($0)" } ?? "—"),
            ("Duration", timeString(t.durationSeconds)),
            ("Bitrate", t.bitRate.map { "\($0) kbps" } ?? "—"),
            ("Format", (t.suffix ?? "—").uppercased()),
            ("Size", t.size.map { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file) } ?? "—"),
            ("Path", t.path ?? "—"),
        ]
        return VStack(spacing: 0) {
            ForEach(rows, id: \.0) { label, value in
                HStack(alignment: .top) {
                    Text(label)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.themeMutedFg)
                        .frame(width: 88, alignment: .leading)
                    Text(value)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.fg)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .textSelection(.enabled)
                }
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func timeString(_ t: Int) -> String {
        String(format: "%d:%02d", t / 60, t % 60)
    }
}