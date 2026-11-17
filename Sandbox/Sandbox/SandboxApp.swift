import SwiftUI

@main
struct SandboxApp: App {
    @State private var store = GameStore()

    var body: some Scene {
        WindowGroup {
            GameView(store: store)
                .preferredColorScheme(.dark)
        }
    }
}

enum Theme {
    static let ink = Color(hex: 0x14151F)
    static let panel = Color(hex: 0x1C1E2B)
    static let panel2 = Color(hex: 0x252839)
    static let line = Color(hex: 0x33374E)
    static let text = Color(hex: 0xEBE9F2)
    static let muted = Color(hex: 0x9391AB)
    static let signal = Color(hex: 0xFFB547)   // PIP-7
    static let heat = Color(hex: 0xFF6159)     // danger
    static let calm = Color(hex: 0x5FD0B6)     // safe
    static let trust = Color(hex: 0x84A9FF)
    static let leverage = Color(hex: 0xD692FF)

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}
