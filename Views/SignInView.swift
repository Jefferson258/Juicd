import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                JuicdScreenBackground()

                ScrollView {
                    SectionColumn(spacing: 28) {
                        VStack(spacing: 10) {
                            Text("Juicd")
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white, JuicdTheme.brand, JuicdTheme.brand2],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .multilineTextAlignment(.center)

                            Text("Sports picks")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(1.6)
                                .foregroundStyle(JuicdTheme.textTertiary)
                                .textCase(.uppercase)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)

                        Text("Ranked picks, daily points, and season ladders — built for quick sessions.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(JuicdTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 4)

                        VStack(spacing: 14) {
                            SignInWithAppleButton(.signIn) { request in
                                request.requestedScopes = [.fullName, .email]
                            } onCompletion: { result in
                                switch result {
                                case .success(let authorization):
                                    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                                        viewModel.authError = "Could not read Apple ID."
                                        return
                                    }
                                    let fromApple = Self.displayName(from: credential)
                                    viewModel.completeSignIn(displayName: fromApple)
                                case .failure(let error):
                                    viewModel.authError = error.localizedDescription
                                }
                            }
                            .signInWithAppleButtonStyle(.white)
                            .frame(height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                            Button {
                                viewModel.signInDevBypass()
                            } label: {
                                Text("Skip — local dev account")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            }
                            .buttonStyle(.bordered)
                            .tint(JuicdTheme.textSecondary)

                            Text("Dev skip signs in as “Player” (same saved profile each time). Use Sign in with Apple for a name from your Apple ID when available.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(JuicdTheme.textTertiary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                        }
                        .padding(.top, 8)

                        if let error = viewModel.authError {
                            Text(error)
                                .foregroundStyle(Color(red: 1, green: 0.45, blue: 0.45))
                                .font(.system(size: 13, weight: .semibold))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 32)
                }
            }
        }
    }

    private static func displayName(from credential: ASAuthorizationAppleIDCredential) -> String {
        let given = credential.fullName?.givenName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let family = credential.fullName?.familyName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let combined = [given, family].filter { !$0.isEmpty }.joined(separator: " ")
        if !combined.isEmpty { return combined }
        let suffix = String(credential.user.prefix(8))
        return "Apple \(suffix)"
    }
}
