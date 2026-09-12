import Foundation
import Combine

@MainActor
final class TourneyViewModel: ObservableObject {
    private let repository: InMemoryJuicdRepository
    private var userId: UUID?

    enum Kind: String, CaseIterable, Identifiable, Hashable {
        case daily
        case weekly
        var id: String { rawValue }
        var title: String { self == .daily ? "Daily" : "Weekly" }
    }

    enum BoardWindow: String, CaseIterable, Identifiable {
        case current
        case upcoming
        var id: String { rawValue }
        func title(for kind: Kind) -> String {
            switch (self, kind) {
            case (.current, .daily): return "Today"
            case (.upcoming, .daily): return "Tomorrow"
            case (.current, .weekly): return "This week"
            case (.upcoming, .weekly): return "Next week"
            }
        }
    }

    @Published var kind: Kind = .daily
    @Published var boardWindow: BoardWindow = .current
    @Published var pickTexts: [String] = ["", "", "", ""]
    @Published var errorMessage: String?
    @Published private(set) var submittedPicks: [Double]?
    @Published var showBracket = false
    @Published private(set) var remoteEntrants: [BracketEntrant]?
    @Published private(set) var remoteActuals: [Double?]?
    private var boardCancellable: AnyCancellable?

    init(repository: InMemoryJuicdRepository) {
        self.repository = repository
        boardCancellable = repository.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var payload: RemoteTourneyPayload? {
        switch (kind, boardWindow) {
        case (.daily, .current): return repository.lastDailyTourney
        case (.daily, .upcoming): return repository.lastNextDailyTourney
        case (.weekly, .current): return repository.lastWeeklyTourney
        case (.weekly, .upcoming): return repository.lastNextWeeklyTourney
        }
    }

    var hasUpcomingBoard: Bool {
        switch kind {
        case .daily: return repository.lastNextDailyTourney != nil
        case .weekly: return repository.lastNextWeeklyTourney != nil
        }
    }

    var freezeDate: Date? { payload?.freezeDate }
    var commenceDate: Date? { payload?.commenceDate }
    var isFrozen: Bool {
        guard let freezeDate else { return false }
        return Date() >= freezeDate
    }
    var gameStarted: Bool {
        guard let commenceDate else { return false }
        return Date() >= commenceDate
    }

    var displayName: String {
        guard let userId, let p = repository.profile(userId: userId) else { return "You" }
        return p.displayName
    }

    func configure(userId: UUID?) {
        self.userId = userId
        errorMessage = nil
        refreshFromBoard()
        loadSubmitted()
        seedPickPlaceholders()
        logMissingPayloadIfNeeded()
        Task { await refreshRemoteBracket() }
    }

    func refreshFromBoard() {
        loadSubmitted()
        seedPickPlaceholders()
    }

    func select(_ kind: Kind) {
        self.kind = kind
        if !hasUpcomingBoard { boardWindow = .current }
        remoteEntrants = nil
        remoteActuals = nil
        loadSubmitted()
        seedPickPlaceholders()
        errorMessage = nil
        logMissingPayloadIfNeeded()
        Task { await refreshRemoteBracket() }
    }

    func selectWindow(_ window: BoardWindow) {
        boardWindow = window
        remoteEntrants = nil
        remoteActuals = nil
        loadSubmitted()
        seedPickPlaceholders()
        errorMessage = nil
        logMissingPayloadIfNeeded()
        Task { await refreshRemoteBracket() }
    }

    func submitPicks() {
        guard let userId, let payload else {
            errorMessage = "No tournament slate yet."
            return
        }
        if isFrozen {
            errorMessage = "Entry froze an hour before start."
            return
        }
        let needed = payload.roundSpecs.count
        let picks = pickTexts.prefix(needed).compactMap { Double($0.replacingOccurrences(of: ",", with: ".")) }
        guard picks.count == needed else {
            errorMessage = "Enter a number for every round."
            return
        }
        repository.saveTourneyPicks(userId: userId, kind: payload.kind, periodKey: payload.periodKey, picks: picks)
        submittedPicks = picks
        errorMessage = nil
        showBracket = true
        Task {
            let ok = await TourneyBracketService.submit(userId: userId, payload: payload, picks: picks)
            if !ok && SupabaseConfig.isConfigured {
                await MainActor.run { errorMessage = "Saved on this phone. Cloud sync needs sign-in." }
            }
            await refreshRemoteBracket()
        }
    }

    func entrants(now: Date = .now) -> [BracketEntrant] {
        let rows: [BracketEntrant]
        if let remoteEntrants, !remoteEntrants.isEmpty {
            rows = remoteEntrants
        } else {
            guard let payload else { return [] }
            let userPicks = submittedPicks ?? []
            var local: [BracketEntrant] = []
            local.append(
                BracketEntrant(
                    id: userId?.uuidString ?? "you",
                    displayName: displayName,
                    isBot: false,
                    slot: 0,
                    picks: userPicks,
                    eliminatedRound: nil
                )
            )
            let freeze = payload.freezeDate ?? .distantFuture
            if now >= freeze {
                let bots = TourneyBots.entrants(periodKey: payload.periodKey, rounds: payload.roundSpecs, startSlot: 1)
                local.append(contentsOf: bots)
            } else {
                for slot in 1..<16 {
                    local.append(
                        BracketEntrant(
                            id: "open-\(slot)",
                            displayName: "Open",
                            isBot: false,
                            slot: slot,
                            picks: [],
                            eliminatedRound: nil
                        )
                    )
                }
            }
            rows = local
        }
        guard let actuals = remoteActuals, actuals.contains(where: { $0 != nil }) else {
            return rows
        }
        return TourneyClosestGrading.apply(entrants: rows, actuals: actuals)
    }

    func revealedRound(now: Date = .now) -> Int {
        if let actuals = remoteActuals {
            let scored = actuals.prefix { $0 != nil }.count
            if scored > 0 { return min(4, scored) }
        }
        guard gameStarted, let commence = commenceDate else { return 0 }
        let elapsed = now.timeIntervalSince(commence)
        if elapsed > 3 * 3600 { return 4 }
        return min(4, max(0, Int(elapsed / 600)))
    }

    private func loadSubmitted() {
        guard let userId, let payload else {
            submittedPicks = nil
            return
        }
        submittedPicks = repository.tourneyPicks(userId: userId, kind: payload.kind, periodKey: payload.periodKey)
    }

    func refreshRemoteBracket() async {
        guard let userId, let payload, SupabaseConfig.isConfigured else { return }
        guard let remote = await TourneyBracketService.fetch(
            userId: userId,
            kind: payload.kind,
            periodKey: payload.periodKey
        ) else { return }
        remoteEntrants = remote.entries.map {
            BracketEntrant(
                id: $0.id,
                displayName: $0.displayName,
                isBot: $0.isBot,
                slot: $0.slot,
                picks: $0.picks,
                eliminatedRound: $0.eliminatedRound
            )
        }
        remoteActuals = remote.actuals
        if let mine = remote.entries.first(where: { $0.id.lowercased() == userId.uuidString.lowercased() }),
           !mine.picks.isEmpty {
            submittedPicks = mine.picks
        }
    }

    private func seedPickPlaceholders() {
        guard submittedPicks == nil, let payload else { return }
        pickTexts = payload.roundSpecs.map { spec in
            guard let line = spec.line else { return "" }
            return String(format: "%.1f", line)
        }
        while pickTexts.count < 4 { pickTexts.append("") }
    }

    private func logMissingPayloadIfNeeded() {
        guard payload == nil else { return }
        AppErrorLogger.log(
            severity: .error,
            message: "Tourney \(kind.rawValue) slate missing after Play board fetch (no local demo fallback).",
            screen: "tourney",
            extra: [
                "kind": .string(kind.rawValue),
                "period": .string(kind == .daily ? SlateDay.slateKey() : SlateDay.calendarWeekKey()),
            ]
        )
    }
}

enum TourneyBots {
    private static let adjectives = [
        "Amazing", "Sneaky", "Clutch", "Icy", "Bold", "Lucky", "Wild", "Sunny",
        "Rapid", "Quiet", "Dusty", "Frosty", "Prime", "Nifty", "Gritty"
    ]
    private static let nouns = [
        "Tackler", "Shooter", "Slugger", "Blitzer", "Closer", "Dunker", "Goalie",
        "Jammer", "Slider", "Hammer", "Rocket", "Comet", "Ranger", "Ace", "Captain"
    ]

    static func entrants(periodKey: String, rounds: [RemoteTourneyRound], startSlot: Int) -> [BracketEntrant] {
        (startSlot..<16).map { slot in
            let name = displayName(periodKey: periodKey, slot: slot)
            let picks = rounds.map { round in
                let jitter = Double((fnv(periodKey + "|\(slot)|\(round.round)") % 17) - 8) * 0.5
                let base: Double
                if let line = round.line {
                    base = line
                } else {
                    // Combined-score rounds have no book line; bots guess from a hash, never a canned 44.5/48.
                    base = Double(40 + (fnv(periodKey + round.eventId + round.matchup) % 41))
                }
                return max(0, (base + jitter) * 10).rounded() / 10
            }
            return BracketEntrant(
                id: "bot-\(periodKey)-\(slot)",
                displayName: name,
                isBot: true,
                slot: slot,
                picks: picks,
                eliminatedRound: nil
            )
        }
    }

    static func displayName(periodKey: String, slot: Int) -> String {
        let a = adjectives[fnv(periodKey + "|a|\(slot)") % adjectives.count]
        let n = nouns[fnv(periodKey + "|n|\(slot)") % nouns.count]
        let num = 10 + (fnv(periodKey + "|#|\(slot)") % 90)
        return "\(a)\(n)\(num)"
    }

    private static func fnv(_ s: String) -> Int {
        var h = 2166136261
        for u in s.utf8 {
            h ^= Int(u)
            h = h &* 16777619
        }
        return abs(h)
    }
}
