import SwiftUI

struct GroupsView: View {
    @ObservedObject var viewModel: GroupsViewModel

    var body: some View {
        ScrollView {
            SectionColumn(spacing: 22) {
                BrandHeader(
                    title: "Groups",
                    subtitle: "Squads, invite codes, and a simple weekly scoreboard.",
                    centered: true,
                    kicker: "Together"
                )

                Card(title: "Your groups", systemImage: "person.3.fill") {
                    VStack(spacing: 0) {
                        if viewModel.myGroups.isEmpty {
                            Text("No groups yet — create one or join with a code below.")
                                .foregroundStyle(JuicdTheme.textSecondary)
                                .font(.system(size: 15, weight: .medium))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(Array(viewModel.myGroups.enumerated()), id: \.element.id) { index, group in
                                if index > 0 {
                                    Divider().overlay(JuicdTheme.strokeSubtle)
                                }
                                HStack {
                                    Text(group.name)
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                        .foregroundStyle(JuicdTheme.textPrimary)
                                    Spacer()
                                    if viewModel.selectedGroupId == group.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(JuicdTheme.brand)
                                            .font(.system(size: 20))
                                    }
                                }
                                .padding(.vertical, 12)
                                .background(
                                    viewModel.selectedGroupId == group.id
                                        ? JuicdTheme.brand.opacity(0.06)
                                        : Color.clear
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.selectedGroupId = group.id
                                    viewModel.refreshWeeklyScoreboard()
                                }
                            }
                        }
                    }
                }

                Card(title: "Create", systemImage: "plus.circle.fill") {
                    VStack(spacing: 14) {
                        JuicdInputField {
                            TextField("Group name", text: $viewModel.newGroupName)
                                .textInputAutocapitalization(.words)
                                .disableAutocorrection(true)
                        }

                        Button {
                            viewModel.createGroup()
                        } label: {
                            Text("Create group")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(JuicdTheme.brand)
                        .controlSize(.large)
                        .disabled(viewModel.newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Card(title: "Join", systemImage: "qrcode") {
                    VStack(spacing: 14) {
                        JuicdInputField {
                            TextField("Invite code", text: $viewModel.joinInviteCode)
                                .textInputAutocapitalization(.characters)
                                .disableAutocorrection(true)
                        }

                        Button {
                            viewModel.joinGroup()
                        } label: {
                            Text("Join with code")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(JuicdTheme.brand)
                        .controlSize(.large)
                        .disabled(viewModel.joinInviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Card(title: "Weekly board", systemImage: "calendar") {
                    VStack(spacing: 16) {
                        if viewModel.selectedGroupId == nil {
                            Text("Select a group above to load scores.")
                                .foregroundStyle(JuicdTheme.textSecondary)
                                .font(.system(size: 15, weight: .medium))
                                .frame(maxWidth: .infinity)
                        } else {
                            HStack {
                                Text("Week \(viewModel.weekIndex)")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(JuicdTheme.textPrimary)
                                Spacer()
                            }

                            Button {
                                viewModel.submitWeeklyPicks()
                            } label: {
                                Text("Submit weekly picks")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 4)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(JuicdTheme.brand)

                            Slider(value: Binding(
                                get: { Double(viewModel.weekIndex) },
                                set: { viewModel.weekIndex = Int($0.rounded()) }
                            ), in: 1...18, step: 1)
                            .tint(JuicdTheme.brand)

                            if let my = viewModel.myWeeklyPoints {
                                Text("Your week: \(my) pts")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(JuicdTheme.brand)
                            }

                            Divider().overlay(JuicdTheme.strokeSubtle)

                            if viewModel.weeklyScoreboard.isEmpty {
                                Text("No scores yet.")
                                    .foregroundStyle(JuicdTheme.textSecondary)
                                    .font(.system(size: 14, weight: .medium))
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(Array(viewModel.weeklyScoreboard.enumerated()), id: \.offset) { index, row in
                                        if index > 0 {
                                            Divider().overlay(JuicdTheme.strokeSubtle)
                                        }
                                        HStack {
                                            Text("#\(index + 1)")
                                                .foregroundStyle(JuicdTheme.textTertiary)
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                                .frame(width: 36, alignment: .leading)
                                            Text(row.userName)
                                                .foregroundStyle(JuicdTheme.textPrimary)
                                                .font(.system(size: 15, weight: .semibold))
                                            Spacer()
                                            Text("\(row.points) pts")
                                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                                .foregroundStyle(JuicdTheme.brand)
                                        }
                                        .padding(.vertical, 10)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .background(JuicdScreenBackground())
    }
}
