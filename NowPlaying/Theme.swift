import SwiftUI
import UIKit

// Design tokens ported from the web prototype (oklch → sRGB):
// bg 0.22 #1A1B1C · card 0.26 #232425 · shell 0.15 #0A0B0C
// border 0.34 #373839 · muted 0.30 #2D2E2F · primary(cream) 0.80 #C3BDB3
// foreground 0.93 #E5E8EB · overlay 0.10 #030304

enum Theme {
    static let bg = Color(red: 0x1A/255, green: 0x1B/255, blue: 0x1C/255)
    static let card = Color(red: 0x23/255, green: 0x24/255, blue: 0x25/255)
    static let shell = Color(red: 0x0A/255, green: 0x0B/255, blue: 0x0C/255)
    static let border = Color(red: 0x37/255, green: 0x38/255, blue: 0x39/255)
    static let muted = Color(red: 0x2D/255, green: 0x2E/255, blue: 0x2F/255)
    static let cream = Color(red: 0xC3/255, green: 0xBD/255, blue: 0xB3/255)
    static let fg = Color(red: 0xE5/255, green: 0xE8/255, blue: 0xEB/255)
    static let overlay = Color.black.opacity(0.55)

    static let displayFont = Font.system(size: 24, weight: .bold, design: .condensed)
    static let monoFont = Font.system(size: 12, weight: .regular, design: .monospaced)
}

extension Color {
    static let themeBorder = Theme.border
    static let themeMutedFg = Color(red: 0x9A/255, green: 0x9C/255, blue: 0x9E/255)
}

enum Haptics {
    private static let impact = UIImpactFeedbackGenerator(style: .medium)
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let notify = UINotificationFeedbackGenerator()

    static func tap() { if !reduceMotion() { impact.impactOccurred() } }
    static func soft() { if !reduceMotion() { light.impactOccurred() } }
    static func success() { if !reduceMotion() { notify.notificationOccurred(.success) } }

    private static func reduceMotion() -> Bool {
        UIAccessibility.isReduceMotionEnabled
    }
}

/// Embossed control-dial gradient (ported from the prototype's .control-dial CSS).
struct DialButtonStyle: ButtonStyle {
    var highlighted = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Theme.fg)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: configuration.isPressed
                                ? [Color(white: 0.12), Color(white: 0.20)]
                                : [Color(white: 0.16), Color(white: 0.26)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .overlay(Circle().strokeBorder(Theme.border, lineWidth: 1))
                    .shadow(color: .black.opacity(0.45), radius: 6, x: 0, y: 3)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }
}

/// Album-frame treatment (border + deep shadow like .album-frame).
struct AlbumFrame: ViewModifier {
    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 14, x: 0, y: 8)
    }
}

/// Subtle scanline overlay (10% opacity) over album art.
struct ScanlineOverlay: View {
    var body: some View {
        GeometryReader { geo in
            Path { p in
                let step: CGFloat = 4
                var y: CGFloat = 0
                while y < geo.size.height {
                    p.addRect(CGRect(x: 0, y: y, width: geo.size.width, height: 1))
                    y += step
                }
            }
            .fill(Color.white.opacity(0.03))
        }
        .allowsHitTesting(false)
    }
}