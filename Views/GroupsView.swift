import SwiftUI

struct GroupsView: View {
    @ObservedObject var viewModel: GroupsViewModel

    var body: some View {
        ScrollView {
            SectionColumn {
                BrandHeader(
                    title: "Groups",
                    subtitle: "Create squads, invite friends, and track weekly standings.",
                    centered: true
                )

                Card(title: "Your groups", systemImage: "person.3.fill") {
                    VStack(spacing: 12) {
                        if viewModel.myGroups.isEmpty {
                            Text("You’re not in a group yet.")
                                .foregroundStyle(JuicdTheme.textSecondary)
                                .font(.system(size: 14, weight: .semibold))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        } else {
                            ForEach(viewModel.myGroups) { group in
                                HStack {
                                    Text(group.name)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(JuicdTheme.textPrimary)
                                    Spacer()
                                    if viewModel.selectedGroupId == group.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(JuicdTheme.brand)
                                    }
                                }
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.selectedGroupId = group.id
                                    viewModel.refreshWeeklyScoreboard()
                                }
                            }
                        }
                    }
                }

                Card(title: "Create a group", systemImage: "plus.circle.fill") {
                    VStack(spacing: 12) {
                        TextField("Group name", text: $viewModel.newGroupName)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .padding(12)
                            .foregroundStyle(JuicdTheme.textPrimary)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )

                        Button {
                            viewModel.createGroup()
                        } label: {
                            Text("Create")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(JuicdTheme.brand)
                        .disabled(viewModel.newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Card(title: "Join by invite", systemImage: "qrcode") {
                    VStack(spacing: 12) {
                        TextField("Invite code", text: $viewModel.joinInviteCode)
                            .textInputAutocapitalization(.characters)
                            .disableAutocorrection(true)
                            .padding(12)
                            .foregroundStyle(JuicdTheme.textPrimary)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )

                        Button {
                            viewModel.joinGroup()
                        } label: {
                            Text("Join")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(JuicdTheme.brand)
                        .disabled(viewModel.joinInviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Card(title: "Group standings (prototype)", systemImage: "calendar") {
                    VStack(spacing: 12) {
                        if viewModel.selectedGroupId == nil {
                            Text("Select a group above.")
                                .foregroundStyle(JuicdTheme.textSecondary)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                        } else {
                            HStack {
                                Text("Week \(viewModel.weekIndex)")
                                    .font(.headline)
                                    .foregroundStyle(JuicdTheme.textPrimary)
                                Spacer()
                            }

                            Button {
                                viewModel.submitWeeklyPicks()
                            } label: {
                                Text("Submit weekly picks")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(JuicdTheme.brand)

                            Slider(value: Binding(
                                get: { Double(viewModel.weekIndex) },
                                set: { viewModel.weekIndex = Int($0.rounded()) }
                            ), in: 1...18, step: 1)
                            .tint(JuicdTheme.brand)
                            .onChange(of: viewModel.weekIndex) { _, _ in
                                viewModel.refreshWeeklyScoreboard()
                            }

                            if let my = viewModel.myWeeklyPoints {
                                Text("Your week: \(my) pts")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(JuicdTheme.brand)
                            }

                            Divider().overlay(Color.white.opacity(0.1))

                            if viewModel.weeklyScoreboard.isEmpty {
                                Text("No scores yet.")
                                    .foregroundStyle(JuicdTheme.textSecondary)
                            } else {
                                ForEach(Array(viewModel.weeklyScoreboard.enumerated()), id: \.offset) { index, row in
                                    HStack {
                                        Text("#\(index + 1)")
                                            .foregroundStyle(JuicdTheme.textSecondary)
                                            .font(.caption.weight(.bold))
                                        Text(row.userName)
                                            .foregroundStyle(JuicdTheme.textPrimary)
                                        Spacer()
                                        Text("\(row.points) pts")
                                            .fontWeight(.bold)
                                            .foregroundStyle(JuicdTheme.brand)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(JuicdTheme.slateBackground.ignoresSafeArea())
    }
}
