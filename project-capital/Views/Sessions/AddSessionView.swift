import SwiftUI

struct AddSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sessionType: SessionType? = nil

    enum SessionType { case live, online }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                if let type = sessionType {
                    if type == .online {
                        OnlineSessionFormView { dismiss() }
                    } else {
                        LiveSessionFormView { dismiss() }
                    }
                } else {
                    typeSelection
                }
            }
            .navigationTitle(sessionType == nil ? "New Session" : (sessionType == .online ? "Online Session" : "Live Session"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.appSecondary)
                }
                if sessionType != nil {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            sessionType = nil
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .foregroundColor(.appGold)
                        }
                    }
                }
            }
        }
    }

    var typeSelection: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Choose Session Type")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.appPrimary)

            HStack(spacing: 16) {
                SessionTypeCard(
                    title: "Live",
                    subtitle: "Casino or home game",
                    icon: "building.columns.fill"
                ) {
                    sessionType = .live
                }
                SessionTypeCard(
                    title: "Online",
                    subtitle: "Poker platform",
                    icon: "desktopcomputer"
                ) {
                    sessionType = .online
                }
            }
            .padding(.horizontal)
            Spacer()
        }
    }
}

struct SessionTypeCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
}
