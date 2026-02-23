import Foundation

// UserSettings provides app-wide defaults read from UserDefaults.
// Views use @AppStorage directly; this singleton is used in non-view business logic only.
struct UserSettings {
    static let shared = UserSettings()

    var handsPerHourOnline: Int {
        UserDefaults.standard.integer(forKey: "handsPerHourOnline").nonZeroOr(85)
    }
    var handsPerHourLive: Int {
        UserDefaults.standard.integer(forKey: "handsPerHourLive").nonZeroOr(25)
    }
    var baseCurrency: String {
        UserDefaults.standard.string(forKey: "baseCurrency") ?? "CAD"
    }
    var showAdjustmentsInStats: Bool {
        UserDefaults.standard.object(forKey: "showAdjustmentsInStats") as? Bool ?? true
    }
}

private extension Int {
    func nonZeroOr(_ fallback: Int) -> Int { self == 0 ? fallback : self }
}

// Predefined platform templates for onboarding
struct PlatformTemplate: Identifiable {
    let id = UUID()
    let name: String
    let currency: String
}

extension PlatformTemplate {
    static let predefined: [PlatformTemplate] = [
        PlatformTemplate(name: "PokerStars Ontario", currency: "CAD"),
        PlatformTemplate(name: "ClubWPT Gold", currency: "USD"),
        PlatformTemplate(name: "GGPoker", currency: "USD"),
        PlatformTemplate(name: "888poker Canada", currency: "CAD"),
        PlatformTemplate(name: "PartyPoker", currency: "USD"),
        PlatformTemplate(name: "PokerStars Global", currency: "USD"),
    ]
}

let supportedCurrencies = ["CAD", "USD", "EUR", "GBP", "AUD", "MXN", "BTC", "ETH"]

let gameTypes = [
    "No Limit Hold'em",
    "Pot Limit Omaha",
    "Pot Limit Omaha 5",
    "Pot Limit Omaha Hi-Lo",
    "7 Card Stud",
    "Mixed Games"
]

let depositMethods = ["E-Transfer", "Bank Transfer", "Credit Card", "Crypto", "PayPal", "Other"]
let withdrawalMethods = ["E-Transfer", "Bank Transfer", "Check", "Crypto", "PayPal", "Other"]
