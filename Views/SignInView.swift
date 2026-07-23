import AuthenticationServices
import SwiftUI

// MARK: - Legal gate (required before first sign-in)

private let juicdLegalAgreedKey = "Juicd.legal.hasAgreedToTerms"
private let juicdTermsVersion = 2

enum JuicdLegalAgreement {
    static var hasAgreed: Bool {
        UserDefaults.standard.integer(forKey: juicdLegalAgreedKey) >= juicdTermsVersion
    }

    static func markAgreed() {
        UserDefaults.standard.set(juicdTermsVersion, forKey: juicdLegalAgreedKey)
    }
}

private let juicdDisclaimerText = """
By using Juicd you agree to the following:

• You are 18 years of age or older. Juicd is not intended for minors.

• Juicd is free and supported by advertising. We do not sell in-app purchases for points or wagering.

• Juicd uses virtual points only. Points have no cash value — now or in the future — and cannot be withdrawn, exchanged for money, or used for real-money wagering.

• Juicd is not a sportsbook, casino, or gambling service. Success in Juicd does not imply future success at real-money gaming or sports betting.

• Contests and tournaments use virtual scoring only unless official rules state otherwise. Apple is not a sponsor of any contest.

• Odds and picks are for entertainment. We do not guarantee accuracy of lines, stats, or outcomes.

• Sponsored content may appear and is labeled. Third-party advertisers are responsible for their offers.

• You agree to our Terms of Use and Privacy Policy (as updated from time to time). You are responsible for complying with laws in your location.
"""

private struct JuicdLegalAgreementView: View {
    @Binding var hasAgreed: Bool
    @State private var confirmed18 = false
    @State private var confirmedTerms = false

    private var canContinue: Bool { confirmed18 && confirmedTerms }

    var body: some View {
        ZStack {
            JuicdScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Terms & eligibility")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(juicdDisclaimerText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(JuicdTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Link("Terms of Use", destination: URL(string: "https://juicd.app/terms")!)
                        .font(.system(size: 14, weight: .semibold))
                    Link("Privacy Policy", destination: URL(string: "https://juicd.app/privacy")!)
                        .font(.system(size: 14, weight: .semibold))
                    Link("Contest Rules", destination: URL(string: "https://juicd.app/contest-rules")!)
                        .font(.system(size: 14, weight: .semibold))

                    Toggle(isOn: $confirmed18) {
                        Text("I am 18 years of age or older")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .tint(JuicdTheme.brand)

                    Toggle(isOn: $confirmedTerms) {
                        Text("I have read and agree to the terms above")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .tint(JuicdTheme.brand)

                    Button {
                        JuicdLegalAgreement.markAgreed()
                        hasAgreed = true
                    } label: {
                        Text("Continue")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(canContinue ? JuicdTheme.brand : .gray)
                    .disabled(!canContinue)
                }
                .padding(24)
            }
        }
    }
}

struct SignInView: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var hasAgreedToLegal = JuicdLegalAgreement.hasAgreed
        || ProcessInfo.processInfo.arguments.contains("-acceptLegalTerms")

    var body: some View {
        SwiftUI.Group {
            if !hasAgreedToLegal {
                JuicdLegalAgreementView(hasAgreed: $hasAgreedToLegal)
            } else {
                signInContent
            }
        }
    }

    private var signInContent: some View {
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

                        HStack(spacing: 14) {
                            brightFeatureIcon(systemName: "basketball.fill", color: JuicdTheme.brand)
                            brightFeatureIcon(systemName: "trophy.fill", color: JuicdTheme.brand2)
                            brightFeatureIcon(systemName: "chart.line.uptrend.xyaxis.circle.fill", color: .yellow)
                        }
                        .padding(.top, 2)

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
                            .disabled(viewModel.isBusy)

                            Button {
                                viewModel.signInDevBypass()
                            } label: {
                                Text("Continue as Player")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            }
                            .buttonStyle(.bordered)
                            .tint(JuicdTheme.textSecondary)
                            .disabled(viewModel.isBusy)
                            .accessibilityIdentifier("Skip — local dev account")

                            if viewModel.isBusy {
                                ProgressView()
                                    .tint(JuicdTheme.brand)
                            }

                            Text("Sign-in creates a cloud account so friends, groups, and leaderboards sync across TestFlight devices. Your session is saved on this phone — don’t sign out if you want to keep the same friend code.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(JuicdTheme.textTertiary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                        }
                        .padding(.top, 8)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(JuicdTheme.card.opacity(0.78))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(LinearGradient(
                                            colors: [
                                                JuicdTheme.brand.opacity(0.7),
                                                JuicdTheme.brand2.opacity(0.7),
                                                .white.opacity(0.4)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ), lineWidth: 1.2)
                                )
                        )

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

    private func brightFeatureIcon(systemName: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.22))
                .overlay(
                    Circle()
                        .stroke(color.opacity(0.9), lineWidth: 1)
                )
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 42, height: 42)
    }
}
