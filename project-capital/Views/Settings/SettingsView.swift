import SwiftUI

struct SettingsView: View {
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"
    @AppStorage("handsPerHourOnline") private var handsPerHourOnline = 85
    @AppStorage("handsPerHourLive") private var handsPerHourLive = 25
    @AppStorage("showAdjustmentsInStats") private var showAdjustmentsInStats = true

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                Form {
                    baseCurrencySection
                    handsSection
                    statsSection
                    aboutSection
                }
                .scrollContentBackground(.hidden)
                .background(Color.appBackground)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    var baseCurrencySection: some View {
        Section {
            HStack {
                Text("Base Currency")
                    .foregroundColor(.appPrimary)
                Spacer()
                Text(baseCurrency)
                    .foregroundColor(.appGold)
                    .fontWeight(.semibold)
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.appSecondary)
            }
            .listRowBackground(Color.appSurface)

            Text("Your base currency was set during onboarding and cannot be changed. All profits are reported in \(baseCurrency).")
                .font(.caption)
                .foregroundColor(.appSecondary)
                .listRowBackground(Color.appSurface)
        } header: {
            Text("Currency").foregroundColor(.appGold).textCase(nil)
        }
    }

    var handsSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hands/Hour — Online")
                        .foregroundColor(.appPrimary)
                    Text("Used when hands count is not entered")
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                }
                Spacer()
                Stepper("\(handsPerHourOnline)", value: $handsPerHourOnline, in: 10...200, step: 5)
                    .fixedSize()
                    .foregroundColor(.appGold)
            }
            .listRowBackground(Color.appSurface)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hands/Hour — Live")
                        .foregroundColor(.appPrimary)
                    Text("Used when hands count is not entered")
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                }
                Spacer()
                Stepper("\(handsPerHourLive)", value: $handsPerHourLive, in: 10...100, step: 5)
                    .fixedSize()
                    .foregroundColor(.appGold)
            }
            .listRowBackground(Color.appSurface)
        } header: {
            Text("Hands Per Hour").foregroundColor(.appGold).textCase(nil)
        } footer: {
            Text("Online default: 85/hr · Live default: 25/hr")
                .font(.caption)
                .foregroundColor(.appSecondary)
        }
    }

    var statsSection: some View {
        Section {
            Toggle(isOn: $showAdjustmentsInStats) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show Adjustments in Stats")
                        .foregroundColor(.appPrimary)
                    Text("Include rakeback, bonuses, etc. in net result")
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                }
            }
            .tint(.appGold)
            .listRowBackground(Color.appSurface)
        } header: {
            Text("Statistics").foregroundColor(.appGold).textCase(nil)
        }
    }

    var aboutSection: some View {
        Section {
            HStack {
                Text("App Name")
                    .foregroundColor(.appPrimary)
                Spacer()
                Text("Project Capital")
                    .foregroundColor(.appSecondary)
            }
            .listRowBackground(Color.appSurface)

            HStack {
                Text("Version")
                    .foregroundColor(.appPrimary)
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundColor(.appSecondary)
            }
            .listRowBackground(Color.appSurface)

            HStack {
                Text("Build")
                    .foregroundColor(.appPrimary)
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                    .foregroundColor(.appSecondary)
            }
            .listRowBackground(Color.appSurface)
        } header: {
            Text("About").foregroundColor(.appGold).textCase(nil)
        }
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
