import SwiftUI

extension Color {
    // Backgrounds
    static let appBackground = Color(hex: "#000000")
    static let appSurface = Color(hex: "#0D0D0D")
    static let appSurface2 = Color(hex: "#1A1A1A")
    static let appBorder = Color(hex: "#2A2A2A")

    // Text
    static let appPrimary = Color.white
    static let appSecondary = Color(hex: "#8A8A8A")

    // Accent
    static let appGold = Color(hex: "#C9B47A")

    // Semantic
    static let appProfit = Color(hex: "#4CAF50")
    static let appLoss = Color(hex: "#F44336")
    static let appNeutral = Color(hex: "#8A8A8A")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension Double {
    var profitColor: Color {
        if self > 0 { return .appProfit }
        if self < 0 { return .appLoss }
        return .appNeutral
    }
}

import UIKit

extension View {
    /// Selects all text when a UITextField within this view gains focus.
    func selectAllOnFocus() -> some View {
        onReceive(
            NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)
        ) { notification in
            DispatchQueue.main.async {
                (notification.object as? UITextField)?.selectAll(nil)
            }
        }
    }
}
