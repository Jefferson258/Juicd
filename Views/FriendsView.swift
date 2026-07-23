import SwiftUI

struct FriendsView: View {
    @ObservedObject var viewModel: FriendsViewModel
    @FocusState private var friendsSearchFocused: Bool
    @State private var showFriendsTips = false

    var body: some View {
        NavigationStack {
            ScrollView {
                SectionColumn(spacing: 24) {
                    JuicdTabScreenAccent()
                    BrandHeader(
                        title: "Friends",
                        subtitle: "Requests, groups, leaderboards — live across devices.",
                        centered: true,
                        kicker: "Social"
                    )
                    HStack(spacing: 10) {
                        compactTopIcon(systemName: "person.2.fill")
                        compactTopIcon(systemName: "person.badge.plus")
                        compactTopIcon(systemName: "chart.bar.fill")
                        Button {
                            showFriendsTips = true
                        } label: {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(JuicdTheme.brand)
                    }

                    if let code = viewModel.friendCode, !code.isEmpty {
                        Card(title: "Your friend code", systemImage: "qrcode") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(code)
                                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                                    .foregroundStyle(JuicdTheme.brand)
                                    .textSelection(.enabled)
                                    .accessibilityLabel(code)
                                    .accessibilityIdentifier("friend-code")
                                Text("Share this code or your display name. Friends search either.")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(JuicdTheme.textTertiary)
                            }
                        }
                    }

                    Card(title: "Groups", systemImage: "person.3.fill") {
                        VStack(alignment: .leading, spacing: 12) {
                            if viewModel.groups.isEmpty {
                                Text("No groups yet — create one and share the invite code.")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(JuicdTheme.textSecondary)
                            } else {
                                ForEach(viewModel.groups) { g in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(g.name)
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                        Text("Invite code \(g.inviteCode)")
                                            .font(.caption.weight(.semibold).monospaced())
                                            .foregroundStyle(JuicdTheme.textTertiary)
                                            .textSelection(.enabled)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }

                            JuicdInputField {
                                TextField("New group name", text: $viewModel.newGroupName)
                                    .textInputAutocapitalization(.words)
                            }
                            Button("Create group") { viewModel.createGroup() }
                                .buttonStyle(.borderedProminent)
                                .tint(JuicdTheme.brand)
                                .disabled(viewModel.isBusy)

                            JuicdInputField {
                                TextField("Join with invite code", text: $viewModel.joinGroupCode)
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled()
                            }
                            Button("Join group") { viewModel.joinGroup() }
                                .buttonStyle(.bordered)
                                .tint(JuicdTheme.brand)
                                .disabled(viewModel.isBusy)
                        }
                    }

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
                            Label("Search by display name or friend code", systemImage: "magnifyingglass")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(JuicdTheme.textTertiary)

                            JuicdInputField {
                                TextField("Name or 6-letter code", text: $viewModel.searchQuery)
                                    .focused($friendsSearchFocused)
                                    .textInputAutocapitalization(.never)
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
                            Label("Friends + you by MMR", systemImage: "arrow.up.forward")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(JuicdTheme.textTertiary)

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

                    if !viewModel.seasonLeaderboard.isEmpty {
                        Card(title: "Season ladder", systemImage: "trophy.fill") {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(viewModel.seasonLeaderboard.prefix(15)) { row in
                                    HStack {
                                        Text("#\(row.rank)")
                                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                                            .foregroundStyle(JuicdTheme.textTertiary)
                                            .frame(width: 36, alignment: .leading)
                                        Text(row.display_name)
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        Spacer()
                                        Text("\(row.season_points_won ?? 0) pts")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(JuicdTheme.textTertiary)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }

                    if !viewModel.allTimeLeaderboard.isEmpty {
                        Card(title: "All-time ladder", systemImage: "crown.fill") {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(viewModel.allTimeLeaderboard.prefix(15)) { row in
                                    HStack {
                                        Text("#\(row.rank)")
                                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                                            .foregroundStyle(JuicdTheme.textTertiary)
                                            .frame(width: 36, alignment: .leading)
                                        Text(row.display_name)
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        Spacer()
                                        Text("\(row.all_time_points_won ?? 0) pts")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(JuicdTheme.textTertiary)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }

                    if let status = viewModel.statusMessage {
                        Text(status)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JuicdTheme.brand)
                    }

                    if let err = viewModel.errorMessage {
                        Text(err)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red.opacity(0.9))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
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
        .sheet(isPresented: $showFriendsTips) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Friends guide")
                            .font(.title2.bold())
                            .foregroundStyle(JuicdTheme.textPrimary)

                        friendsTipRow(icon: "qrcode", text: "Your friend code is unique. Share it (or your display name) so other TestFlight testers can find you.")
                        friendsTipRow(icon: "person.badge.plus", text: "Search by name or friend code, send a request, then accept on the other phone.")
                        friendsTipRow(icon: "person.3.fill", text: "Create a group to get an invite code — other testers join with that code.")
                        friendsTipRow(icon: "chart.bar.fill", text: "Friends leaderboard uses synced MMR. Season / all-time ladders are global across all signed-in players.")
                        friendsTipRow(icon: "icloud.fill", text: "Stay signed in on each device so the same cloud account (and friend code) persists.")
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.hidden)
                .background(JuicdScreenBackground())
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { showFriendsTips = false }
                            .fontWeight(.semibold)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $viewModel.selectedFriend) { profile in
            FriendDetailSheet(profile: profile, viewModel: viewModel)
        }
        .onAppear {
            viewModel.refresh()
        }
    }

    private func friendsTipRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 22, alignment: .center)
                .foregroundStyle(JuicdTheme.brand)
                .padding(.top, 2)
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(JuicdTheme.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func compactTopIcon(systemName: String) -> some View {
        ZStack {
            Circle()
                .fill(JuicdTheme.brand.opacity(0.2))
                .overlay(Circle().stroke(JuicdTheme.brand.opacity(0.55), lineWidth: 1))
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 32, height: 32)
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
