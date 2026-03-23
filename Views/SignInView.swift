import SwiftUI

struct SignInView: View {
    @ObservedObject var viewModel: AuthViewModel
    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                JuicdScreenBackground()

                ScrollView {
                    SectionColumn(spacing: 28) {
                        ZStack {
                            Circle()
                                .fill(JuicdTheme.brand.opacity(0.2))
                                .frame(width: 200, height: 200)
                                .blur(radius: 50)
                                .offset(x: -80, y: -40)
                            Circle()
                                .fill(Color.purple.opacity(0.15))
                                .frame(width: 160, height: 160)
                                .blur(radius: 40)
                                .offset(x: 100, y: 20)

                            BrandHeader(
                                title: "Juicd",
                                subtitle: "Ranked picks, daily points, and season ladders — built for quick sessions.",
                                centered: true,
                                kicker: "Sports picks"
                            )
                        }
                        .padding(.top, 8)

                        Card(title: "Start with \(InMemoryJuicdRepository.dailyPlayAllowancePoints) points / day", systemImage: "bolt.fill", style: .hero) {
                            VStack(spacing: 20) {
                                Text("Each day you receive \(InMemoryJuicdRepository.dailyPlayAllowancePoints) points to stake on picks and parlays. Use them on the Play board and in ranked modes to try to climb your tier — skipping a day does not drop your rank.")
                                    .foregroundStyle(JuicdTheme.textSecondary)
                                    .font(.system(size: 15, weight: .medium))
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(4)

                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Display name")
                                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                                        .foregroundStyle(JuicdTheme.textTertiary)
                                        .textCase(.uppercase)
                                        .tracking(0.6)

                                    TextField("Pick a name", text: $viewModel.displayName)
                                        .textInputAutocapitalization(.words)
                                        .disableAutocorrection(true)
                                        .focused($isNameFocused)
                                        .submitLabel(.done)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                                        .foregroundStyle(JuicdTheme.textPrimary)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(JuicdTheme.card)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                        .stroke(JuicdTheme.strokeSubtle, lineWidth: 1)
                                                )
                                        )
                                }

                                if let error = viewModel.authError {
                                    Text(error)
                                        .foregroundStyle(Color(red: 1, green: 0.45, blue: 0.45))
                                        .font(.system(size: 13, weight: .semibold))
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                }

                                Button {
                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                                        viewModel.signIn()
                                    }
                                } label: {
                                    Text("Continue")
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 4)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(JuicdTheme.brand)
                                .controlSize(.large)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 28)
                }
            }
        }
    }
}
