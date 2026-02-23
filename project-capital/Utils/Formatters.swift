import Foundation

enum AppFormatter {
    static func currency(_ value: Double, code: String = "") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        formatter.decimalSeparator = "."
        let formatted = formatter.string(from: NSNumber(value: abs(value))) ?? "0.00"
        let prefix = value < 0 ? "-$" : "$"
        if code.isEmpty {
            return "\(prefix)\(formatted)"
        }
        return "\(prefix)\(formatted) \(code)"
    }

    static func currencySigned(_ value: Double, code: String = "") -> String {
        let formatted = currency(abs(value), code: code)
        if value > 0 { return "+\(formatted)" }
        if value < 0 { return "-\(formatted.dropFirst())" }
        return formatted
    }

    static func duration(_ hours: Double) -> String {
        let totalMinutes = Int(hours * 60)
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    static func hourlyRate(_ value: Double) -> String {
        let formatted = NumberFormatter()
        formatted.numberStyle = .decimal
        formatted.minimumFractionDigits = 2
        formatted.maximumFractionDigits = 2
        let sign = value >= 0 ? "$" : "-$"
        let abs = formatted.string(from: NSNumber(value: Swift.abs(value))) ?? "0.00"
        return "\(sign)\(abs)/hr"
    }

    static func percentage(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }

    static func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    static func sessionDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    static func monthYear(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }

    static func timeOnly(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    static func exchangeRate(_ rate: Double) -> String {
        String(format: "%.4f", rate)
    }

    static func handsCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000)
        }
        return "\(count)"
    }
}
