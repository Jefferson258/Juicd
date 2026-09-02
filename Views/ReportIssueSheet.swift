import SwiftUI

struct ReportIssueSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var bodyText = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var didSend = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Describe what happened. Include the screen and what you expected. Don’t include passwords.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(JuicdTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    TextEditor(text: $bodyText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(JuicdTheme.textPrimary)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .frame(minHeight: 160)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(JuicdTheme.canvasDeep.opacity(0.7))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(JuicdTheme.brand.opacity(0.35), lineWidth: 1)
                                }
                        }
                        .disabled(isSending || didSend)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.red)
                    }

                    if didSend {
                        Text("Thanks — we got it.")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(JuicdTheme.brand)
                    }

                    Button {
                        Task { await send() }
                    } label: {
                        HStack {
                            if isSending { ProgressView().tint(.white) }
                            Text(isSending ? "Sending…" : "Send report")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(JuicdTheme.brand)
                    .disabled(isSending || didSend || bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(16)
            }
            .background(JuicdScreenBackground())
            .navigationTitle("Report an issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func send() async {
        errorMessage = nil
        isSending = true
        defer { isSending = false }
        do {
            try await IssueReportService.submit(body: bodyText, screen: "profile")
            didSend = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
