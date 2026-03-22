import SwiftUI

struct SignInView: View {
    @ObservedObject var viewModel: AuthViewModel
    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                SectionColumn {
                    BrandHeader(
                        title: "Juicd",
                        subtitle: "Ranked sports picks with daily points.",
                        centered: true
                    )

                    Card(title: "Get 10 points today", systemImage: "bolt.fill") {
                        VStack(spacing: 16) {
                            Text("You get 10 daily points to place picks. Parlays and tournaments earn season rank points.")
                                .foregroundStyle(JuicdTheme.textSecondary)
                                .font(.system(size: 14, weight: .semibold))
                                .multilineTextAlignment(.center)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Display name")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(JuicdTheme.textSecondary)

                                TextField("e.g. Ace", text: $viewModel.displayName)
                                    .textInputAutocapitalization(.words)
                                    .disableAutocorrection(true)
                                    .focused($isNameFocused)
                                    .submitLabel(.done)
                                    .padding(12)
                                    .foregroundStyle(JuicdTheme.textPrimary)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color.white.opacity(0.08))
                                    )
                            }

                            if let error = viewModel.authError {
                                Text(error)
                                    .foregroundStyle(.red)
                                    .font(.system(size: 13, weight: .semibold))
                            }

                            Button {
                                withAnimation(.spring) {
                                    viewModel.signIn()
                                }
                            } label: {
                                Text("Continue")
                                    .font(.system(size: 16, weight: .bold))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(JuicdTheme.brand)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
            .background(JuicdTheme.slateBackground.ignoresSafeArea())
        }
    }
}
