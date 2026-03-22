import SwiftUI

// MARK: - Onboarding Profile View
// First launch screen to collect user's name and preferred currency

struct OnboardingProfileView: View {
    @ObservedObject var profileManager = UserProfileManager.shared
    let onComplete: () -> Void

    @State private var firstName: String = ""
    @State private var selectedCurrency: String = "CHF"
    @FocusState private var isNameFocused: Bool

    private let currencies = ["CHF", "EUR", "USD", "GBP", "JPY", "CAD", "AUD"]

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.15, green: 0.1, blue: 0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Welcome icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: .blue.opacity(0.5), radius: 20)

                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 30)

                // Title
                Text("Bienvenue!")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.bottom, 8)

                Text("Configurons votre profil")
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 40)

                // Form card
                VStack(spacing: 24) {
                    // Name field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Votre prénom")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)

                        TextField("", text: $firstName)
                            .font(.system(size: 20, weight: .medium))
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isNameFocused ? Color.blue : Color.clear, lineWidth: 2)
                            )
                            .focused($isNameFocused)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.words)
                    }

                    // Currency picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Devise par défaut")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(currencies, id: \.self) { currency in
                                    currencyButton(currency)
                                }
                            }
                        }
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.1), radius: 20)
                )
                .padding(.horizontal, 20)

                Spacer()

                // Continue button
                Button(action: saveProfile) {
                    HStack {
                        Text("Continuer")
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: firstName.trimmingCharacters(in: .whitespaces).isEmpty
                                        ? [.gray, .gray]
                                        : [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(color: firstName.isEmpty ? .clear : .blue.opacity(0.4), radius: 10, y: 5)
                }
                .disabled(firstName.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isNameFocused = true
            }
        }
    }

    // MARK: - Currency Button
    private func currencyButton(_ currency: String) -> some View {
        Button(action: {
            selectedCurrency = currency
            LiquidGlassTheme.Haptics.light()
        }) {
            Text(currency)
                .font(.system(size: 16, weight: selectedCurrency == currency ? .bold : .medium))
                .foregroundColor(selectedCurrency == currency ? .white : .primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(selectedCurrency == currency
                              ? LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                              : LinearGradient(colors: [Color.gray.opacity(0.1)], startPoint: .leading, endPoint: .trailing))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save Profile
    private func saveProfile() {
        let trimmedName = firstName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        profileManager.createProfile(firstName: trimmedName, preferredCurrency: selectedCurrency)
        LiquidGlassTheme.Haptics.success()
        onComplete()
    }
}

// MARK: - Preview
#Preview {
    OnboardingProfileView {
        print("Onboarding complete")
    }
}
