import SwiftUI
import AVKit

/// AVRoutePickerView embedded directly over the dial's AirPlay cell — the
/// system-presented route picker opens on tap (no private API needed).
struct AirPlayDialCell: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let v = AVRoutePickerView(frame: CGRect(x: 0, y: 0, width: 48, height: 48))
        v.tintColor = UIColor(Theme.cream)
        v.backgroundColor = .clear
        return v
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}