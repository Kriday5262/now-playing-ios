import SwiftUI

/// Embossed 3×3 control dial: heart top, prev/play/next middle, AirPlay bottom.
struct ControlDial: View {
    @EnvironmentObject private var engine: PlayerEngine
    @State private var airplaySheet = false

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color(white: 0.18), Color(white: 0.26)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .overlay(Circle().strokeBorder(Theme.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 10, x: 0, y: 6)
            .overlay {
                GeometryReader { geo in
                    let w = geo.size.width
                    let cell = w / 3
                    ZStack {
                        dialButton("heart", fill: engine.isFavourite, systemFill: engine.isFavourite ? "heart.fill" : "heart") {
                            engine.setFavourite(!engine.isFavourite)
                        }
                        .frame(width: cell, height: cell)
                        .position(x: cell * 1.5, y: cell * 0.5)
                        .accessibilityLabel(engine.isFavourite ? "Remove favourite" : "Favourite")

                        dialButton("backward.fill", size: 26) { engine.skipPrevious() }
                            .frame(width: cell, height: cell)
                            .position(x: cell * 0.5, y: cell * 1.5)
                            .accessibilityLabel("Previous track")

                        playButton
                            .frame(width: cell * 1.05, height: cell * 1.05)
                            .position(x: cell * 1.5, y: cell * 1.5)

                        dialButton("forward.fill", size: 26) { engine.skipNext() }
                            .frame(width: cell, height: cell)
                            .position(x: cell * 2.5, y: cell * 1.5)
                            .accessibilityLabel("Next track")

                        AirPlayDialCell()
                            .frame(width: 48, height: 48)
                            .position(x: cell * 1.5, y: cell * 2.5)
                            .accessibilityLabel("AirPlay options")
                    }
                }
            }
    }

    private var playButton: some View {
        Button {
            Haptics.tap()
            engine.togglePlayPause()
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.30), Color(white: 0.20)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .overlay(Circle().strokeBorder(Theme.border, lineWidth: 1))
                    .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
                Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Theme.cream)
                    .offset(x: engine.isPlaying ? 0 : 2)
            }
        }
        .buttonStyle(DialButtonStyle())
        .accessibilityLabel(engine.isPlaying ? "Pause" : "Play")
    }

    private func dialButton(_ system: String, fill: Bool = false, size: CGFloat = 24, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: fill ? system + ".fill" : system)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(fill ? Theme.cream : Theme.fg)
        }
        .buttonStyle(DialButtonStyle())
    }
}