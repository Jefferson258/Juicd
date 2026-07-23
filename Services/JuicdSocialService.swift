import Foundation

/// PostgREST client for friends, groups, and leaderboards (authenticated).
enum JuicdSocialService {
    struct RemoteProfile: Decodable {
        let id: UUID
        let display_name: String
        let mmr: Double?
        let current_tier: String?
        let season_points_won: Int?
        let all_time_points_won: Int?
        let available_daily_points: Int?
        let friend_code: String?

        func asProfile() -> Profile {
            let tier = RankTier(rawValue: (current_tier ?? "bronze").lowercased()) ?? .bronze
            return Profile(
                id: id,
                displayName: display_name,
                mmr: mmr,
                currentTier: tier,
                seasonPointsWon: season_points_won ?? 0,
                allTimePointsWon: all_time_points_won ?? 0,
                availableDailyPoints: available_daily_points ?? 0,
                lastDailyPointsAwardDateISO: nil,
                lastDailyMatch: nil
            )
        }
    }

    struct RemoteFriendRequest: Decodable {
        let id: UUID
        let from_id: UUID
        let to_id: UUID
        let created_at: String?

        func asFriendRequest() -> FriendRequest {
            FriendRequest(
                id: id,
                fromUserId: from_id,
                toUserId: to_id,
                createdAt: JuicdSocialService.parseDate(created_at) ?? .now
            )
        }
    }

    struct RemoteFriendship: Decodable {
        let user_low: UUID
        let user_high: UUID
    }

    struct RemoteGroup: Decodable {
        let id: UUID
        let name: String
        let invite_code: String
        let created_at: String?

        func asGroup() -> Group {
            Group(
                id: id,
                name: name,
                inviteCode: invite_code,
                createdAt: JuicdSocialService.parseDate(created_at) ?? .now
            )
        }
    }

    struct LeaderboardRow: Decodable, Identifiable {
        let user_id: UUID
        let display_name: String
        let current_tier: String?
        let mmr: Double?
        let season_points_won: Int?
        let all_time_points_won: Int?
        let season_rank: Int?
        let alltime_rank: Int?

        var id: UUID { user_id }

        var rank: Int { season_rank ?? alltime_rank ?? 0 }

        func asProfile() -> Profile {
            let tier = RankTier(rawValue: (current_tier ?? "bronze").lowercased()) ?? .bronze
            return Profile(
                id: user_id,
                displayName: display_name,
                mmr: mmr,
                currentTier: tier,
                seasonPointsWon: season_points_won ?? 0,
                allTimePointsWon: all_time_points_won ?? 0,
                availableDailyPoints: 0,
                lastDailyPointsAwardDateISO: nil,
                lastDailyMatch: nil
            )
        }
    }

    // MARK: - Profiles

    static func fetchProfile(userId: UUID) async throws -> RemoteProfile? {
        let q = "id=eq.\(userId.uuidString)&select=*"
        let rows: [RemoteProfile] = try await get("juicd_profiles", query: q)
        return rows.first
    }

    static func fetchProfiles(ids: [UUID]) async throws -> [RemoteProfile] {
        guard !ids.isEmpty else { return [] }
        let idList = ids.map(\.uuidString).joined(separator: ",")
        return try await get("juicd_profiles", query: "id=in.(\(idList))&select=*")
    }

    static func searchProfiles(query: String, excluding: UUID) async throws -> [RemoteProfile] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 1 else { return [] }
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        let upper = trimmed.uppercased().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        // Match display name (ilike) or exact friend code.
        let q = "or=(display_name.ilike.*\(encoded)*,friend_code.eq.\(upper))&id=neq.\(excluding.uuidString)&select=*&limit=20"
        return try await get("juicd_profiles", query: q)
    }

    static func syncLocalStats(_ profile: Profile) async {
        guard let token = await validAccessToken() else { return }
        guard let base = SupabaseConfig.projectURL else { return }
        var comps = URLComponents(url: base.appendingPathComponent("rest/v1/juicd_profiles"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "id", value: "eq.\(profile.id.uuidString)")]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "PATCH"
        applyAuth(&req, token: token)
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        var body: [String: Any] = [
            "display_name": String(profile.displayName.prefix(40)),
            "current_tier": profile.currentTier.rawValue,
            "season_points_won": profile.seasonPointsWon,
            "all_time_points_won": profile.allTimePointsWon,
            "available_daily_points": profile.availableDailyPoints,
            "updated_at": ISO8601DateFormatter().string(from: Date()),
        ]
        if let mmr = profile.mmr { body["mmr"] = mmr }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await URLSession.shared.data(for: req)
    }

    // MARK: - Friends

    static func listIncomingRequests(userId: UUID) async throws -> [RemoteFriendRequest] {
        try await get("juicd_friend_requests", query: "to_id=eq.\(userId.uuidString)&select=*&order=created_at.desc")
    }

    static func listOutgoingRequests(userId: UUID) async throws -> [RemoteFriendRequest] {
        try await get("juicd_friend_requests", query: "from_id=eq.\(userId.uuidString)&select=*&order=created_at.desc")
    }

    static func listFriendships(userId: UUID) async throws -> [RemoteFriendship] {
        let q = "or=(user_low.eq.\(userId.uuidString),user_high.eq.\(userId.uuidString))&select=*"
        return try await get("juicd_friendships", query: q)
    }

    static func sendFriendRequest(from: UUID, to: UUID) async throws {
        try await post("juicd_friend_requests", body: [
            "from_id": from.uuidString,
            "to_id": to.uuidString,
        ])
    }

    static func acceptFriendRequest(requestId: UUID) async throws {
        _ = try await rpc("juicd_accept_friend_request", body: ["p_request_id": requestId.uuidString])
    }

    static func deleteFriendRequest(requestId: UUID) async throws {
        try await delete("juicd_friend_requests", query: "id=eq.\(requestId.uuidString)")
    }

    static func friendLeaderboard(userId: UUID) async throws -> [(rank: Int, profile: Profile)] {
        let edges = try await listFriendships(userId: userId)
        var ids: Set<UUID> = [userId]
        for e in edges {
            ids.insert(e.user_low)
            ids.insert(e.user_high)
        }
        let idList = ids.map(\.uuidString).joined(separator: ",")
        let rows: [RemoteProfile] = try await get(
            "juicd_profiles",
            query: "id=in.(\(idList))&select=*"
        )
        let sorted = rows.map { $0.asProfile() }.sorted {
            let l = $0.mmr ?? 0
            let r = $1.mmr ?? 0
            if l != r { return l > r }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        return sorted.enumerated().map { (rank: $0.offset + 1, profile: $0.element) }
    }

    // MARK: - Groups

    static func myGroups() async throws -> [RemoteGroup] {
        // Fetch memberships then groups (RLS filters).
        struct Mem: Decodable { let group_id: UUID }
        let mems: [Mem] = try await get("juicd_group_members", query: "select=group_id")
        guard !mems.isEmpty else { return [] }
        let ids = mems.map { $0.group_id.uuidString }.joined(separator: ",")
        return try await get("juicd_groups", query: "id=in.(\(ids))&select=*&order=created_at.desc")
    }

    static func createGroup(name: String) async throws -> RemoteGroup {
        let data = try await rpc("juicd_create_group", body: ["p_name": name])
        return try JSONDecoder().decode(RemoteGroup.self, from: data)
    }

    static func joinGroup(code: String) async throws -> UUID {
        let data = try await rpc("juicd_join_group_by_code", body: ["p_code": code.uppercased()])
        // RPC returns uuid as JSON string
        if let id = try? JSONDecoder().decode(UUID.self, from: data) { return id }
        if let s = String(data: data, encoding: .utf8)?.trimmingCharacters(in: CharacterSet(charactersIn: "\"")),
           let id = UUID(uuidString: s) {
            return id
        }
        throw URLError(.cannotParseResponse)
    }

    static func groupMembers(groupId: UUID) async throws -> [RemoteProfile] {
        struct Mem: Decodable { let user_id: UUID }
        let mems: [Mem] = try await get(
            "juicd_group_members",
            query: "group_id=eq.\(groupId.uuidString)&select=user_id"
        )
        guard !mems.isEmpty else { return [] }
        let ids = mems.map { $0.user_id.uuidString }.joined(separator: ",")
        return try await get("juicd_profiles", query: "id=in.(\(ids))&select=*")
    }

    // MARK: - Global leaderboards

    static func seasonLeaderboard(limit: Int = 50) async throws -> [LeaderboardRow] {
        try await get(
            "juicd_season_leaderboard",
            query: "select=*&order=season_points_won.desc&limit=\(limit)"
        )
    }

    static func allTimeLeaderboard(limit: Int = 50) async throws -> [LeaderboardRow] {
        try await get(
            "juicd_alltime_leaderboard",
            query: "select=*&order=all_time_points_won.desc&limit=\(limit)"
        )
    }

    // MARK: - HTTP

    private static func validAccessToken() async -> String? {
        if let s = await SupabaseAuthService.restoreSession() {
            return s.accessToken
        }
        return SupabaseAuthService.accessToken
    }

    private static func applyAuth(_ req: inout URLRequest, token: String) {
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    private static func get<T: Decodable>(_ table: String, query: String) async throws -> T {
        guard let token = await validAccessToken() else { throw URLError(.userAuthenticationRequired) }
        guard let base = SupabaseConfig.projectURL else { throw URLError(.badURL) }
        let url = URL(string: "\(base.absoluteString)/rest/v1/\(table)?\(query)")!
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        applyAuth(&req, token: token)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "GET \(table) failed"
            throw NSError(domain: "JuicdSocial", code: (resp as? HTTPURLResponse)?.statusCode ?? -1,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func post(_ table: String, body: [String: Any]) async throws {
        guard let token = await validAccessToken() else { throw URLError(.userAuthenticationRequired) }
        guard let base = SupabaseConfig.projectURL else { throw URLError(.badURL) }
        var req = URLRequest(url: base.appendingPathComponent("rest/v1/\(table)"))
        req.httpMethod = "POST"
        applyAuth(&req, token: token)
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "POST \(table) failed"
            throw NSError(domain: "JuicdSocial", code: (resp as? HTTPURLResponse)?.statusCode ?? -1,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }

    private static func delete(_ table: String, query: String) async throws {
        guard let token = await validAccessToken() else { throw URLError(.userAuthenticationRequired) }
        guard let base = SupabaseConfig.projectURL else { throw URLError(.badURL) }
        let url = URL(string: "\(base.absoluteString)/rest/v1/\(table)?\(query)")!
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        applyAuth(&req, token: token)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "DELETE \(table) failed"
            throw NSError(domain: "JuicdSocial", code: (resp as? HTTPURLResponse)?.statusCode ?? -1,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }

    private static func rpc(_ name: String, body: [String: Any]) async throws -> Data {
        guard let token = await validAccessToken() else { throw URLError(.userAuthenticationRequired) }
        guard let base = SupabaseConfig.projectURL else { throw URLError(.badURL) }
        var req = URLRequest(url: base.appendingPathComponent("rest/v1/rpc/\(name)"))
        req.httpMethod = "POST"
        applyAuth(&req, token: token)
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "RPC \(name) failed"
            throw NSError(domain: "JuicdSocial", code: (resp as? HTTPURLResponse)?.statusCode ?? -1,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }
        return data
    }

    fileprivate static func parseDate(_ s: String?) -> Date? {
        guard let s else { return nil }
        let f1 = ISO8601DateFormatter()
        f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f1.date(from: s) { return d }
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        return f2.date(from: s)
    }
}
