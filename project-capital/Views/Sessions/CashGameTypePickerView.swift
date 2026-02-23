import SwiftUI

struct CashGameTypePickerView: View {
    @EnvironmentObject var coordinator: ActiveSessionCoordinator

    enum CashGameDestination: Hashable {
        case live, online
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer()
                Text("Choose Session Type")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.appPrimary)

                HStack(spacing: 16) {
                    NavigationLink(value: CashGameDestination.live) {
                        CashGameTypeCard(title: "Live", subtitle: "Casino or home game", icon: "building.columns.fill")
                    }
                    NavigationLink(value: CashGameDestination.online) {
                        CashGameTypeCard(title: "Online", subtitle: "Poker platform", icon: "desktopcomputer")
                    }
                }
                .padding(.horizontal)
                Spacer()
            }
        }
        .navigationTitle("New Cash Game Session")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    coordinator.dismissForm()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.appSecondary)
                }
            }
        }
        .navigationDestination(for: CashGameDestination.self) { destination in
            switch destination {
            case .live:   LiveSessionEntryView()
            case .online: OnlineSessionEntryView()
            }
        }
    }
}

/// Card view used in the cash game type picker (pure display, no inner Button).
private struct CashGameTypeCard: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(.appGold)
            VStack(spacing: 4) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.appPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.appSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color.appSurface)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.appBorder, lineWidth: 1)
        )
    }
}
