import SwiftUI

struct FriendsView: View {
    @ObservedObject var viewModel: FriendsViewModel
    @FocusState private var friendsSearchFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                SectionColumn(spacing: 24) {
                    JuicdTabScreenAccent()
                    BrandHeader(
                        title: "Friends",
                        subtitle: "Requests, your crew, and the Friends Leaderboard — tap someone to see recent Play picks.",
                        centered: true,
                        kicker: "Social"
                    )

                    if !viewModel.incomingRequests.isEmpty {
                        Card(title: "Friend requests", systemImage: "envelope.badge.fill") {
                            VStack(spacing: 0) {
                                ForEach(Array(viewModel.incomingRequests.enumerated()), id: \.element.id) { index, req in
                                    if index > 0 {
                                        Divider().overlay(JuicdTheme.strokeSubtle)
                                    }
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(viewModel.displayName(for: req.fromUserId))
                                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                                .foregroundStyle(JuicdTheme.textPrimary)
                                            Text("Wants to be friends")
                                                .font(.caption.weight(.medium))
                                                .foregroundStyle(JuicdTheme.textTertiary)
                                        }
                                        Spacer()
                                        Button("Decline") {
                                            viewModel.reject(req)
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(JuicdTheme.textTertiary)
                                        Button("Accept") {
                                            viewModel.accept(req)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(JuicdTheme.brand)
                                    }
                                    .padding(.vertical, 10)
                                }
                            }
                        }
                    }

                    if !viewModel.outgoingRequests.isEmpty {
                        Card(title: "Outgoing", systemImage: "paperplane.fill") {
                            VStack(spacing: 0) {
                                ForEach(Array(viewModel.outgoingRequests.enumerated()), id: \.element.id) { index, req in
                                    if index > 0 {
                                        Divider().overlay(JuicdTheme.strokeSubtle)
                                    }
                                    HStack {
                                        Text(viewModel.displayName(for: req.toUserId))
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        Spacer()
                                        Button("Cancel") {
                                            viewModel.cancelOutgoing(req)
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(JuicdTheme.textTertiary)
                                    }
                                    .padding(.vertical, 10)
                                }
                            }
                        }
                    }

                    Card(title: "Add friends", systemImage: "person.badge.plus") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Search by display name (another account on this device signs in with a different name).")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(JuicdTheme.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)

                            JuicdInputField {
                                TextField("Search players", text: $viewModel.searchQuery)
                                    .focused($friendsSearchFocused)
                                    .textInputAutocapitalization(.words)
                                    .disableAutocorrection(true)
                                    .onChange(of: viewModel.searchQuery) { _, _ in
                                        viewModel.runSearch()
                                    }
                            }

                            if viewModel.searchResults.isEmpty, !viewModel.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                                Text("No matches.")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(JuicdTheme.textTertiary)
                            }

                            ForEach(viewModel.searchResults, id: \.id) { p in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(p.displayName)
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                        Text(p.currentTier.displayName)
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(JuicdTheme.textTertiary)
                                    }
                                    Spacer()
                                    Button("Add") {
                                        viewModel.sendRequest(to: p)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(JuicdTheme.brand)
                                }
                                .padding(.vertical, 6)
                            }
                        }
                    }

                    Card(title: "Friends Leaderboard", systemImage: "chart.bar.fill") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("You and your friends, highest skill placement first.")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(JuicdTheme.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)

                            if viewModel.leaderboard.count <= 1 {
                                Text("Add friends to compare ranks. Solo players still see their own row.")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(JuicdTheme.textSecondary)
                            }

                            ForEach(viewModel.leaderboard, id: \.profile.id) { row in
                                Button {
                                    viewModel.selectFriend(row.profile)
                                } label: {
                                    HStack {
                                        Text("#\(row.rank)")
                                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                                            .foregroundStyle(JuicdTheme.textTertiary)
                                            .frame(width: 36, alignment: .leading)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(row.profile.displayName)
                                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                                .foregroundStyle(JuicdTheme.textPrimary)
                                            Text(row.profile.currentTier.displayName)
                                                .font(.caption.weight(.medium))
                                                .foregroundStyle(JuicdTheme.textTertiary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(JuicdTheme.textTertiary)
                                    }
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if let err = viewModel.errorMessage {
                        Text(err)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red.opacity(0.9))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(JuicdScreenBackground())
            .navigationBarTitleDisplayMode(.inline)
            .juicdKeyboardDoneButton { friendsSearchFocused = false }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(JuicdTheme.canvasDeep.ignoresSafeArea(edges: .bottom))
        .sheet(item: $viewModel.selectedFriend) { profile in
            FriendDetailSheet(profile: profile, viewModel: viewModel)
        }
        .onAppear {
            viewModel.refresh()
        }
    }
}

private struct FriendDetailSheet: View {
    let profile: Profile
    @ObservedObject var viewModel: FriendsViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                SectionColumn(spacing: 18) {
                    Card(title: profile.displayName, systemImage: "person.fill", style: .hero) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(profile.currentTier.displayName)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(JuicdTheme.brand)
                            Text("Current tier")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(JuicdTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Card(title: "Recent form (Play)", systemImage: "flame.fill") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Last 7 Play slips: \(viewModel.friendFormWins)–\(viewModel.friendFormLosses) (W–L)")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(JuicdTheme.textSecondary)
                            Text("Prototype: only Play-board parlays are listed below. Ranked daily and daily bracket picks stay on their tabs.")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(JuicdTheme.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Card(title: "Recent Play slips", systemImage: "sportscourt.fill") {
                        if viewModel.friendPlayEntries.isEmpty {
                            Text("No Play history yet.")
                                .foregroundStyle(JuicdTheme.textSecondary)
                                .font(.system(size: 15, weight: .medium))
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(viewModel.friendPlayEntries.enumerated()), id: \.element.id) { index, e in
                                    if index > 0 {
                                        Divider().overlay(JuicdTheme.strokeSubtle)
                                    }
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(e.legSummaries.joined(separator: " + "))
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(JuicdTheme.textPrimary)
                                            .lineLimit(3)
                                        HStack {
                                            Text(e.didWin ? "Win" : "Miss")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(e.didWin ? Color(red: 0.35, green: 0.95, blue: 0.55) : JuicdTheme.textTertiary)
                                            Spacer()
                                            Text(e.createdAt.formatted(date: .abbreviated, time: .shortened))
                                                .font(.caption2)
                                                .foregroundStyle(JuicdTheme.textTertiary)
                                        }
                                    }
                                    .padding(.vertical, 10)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(JuicdScreenBackground())
            .navigationTitle("Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        viewModel.selectedFriend = nil
                    }
                }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            viewModel.loadFriendDetail(profile)
        }
    }
}
