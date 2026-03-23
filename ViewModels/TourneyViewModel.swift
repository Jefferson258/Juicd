import Foundation
import Combine

@MainActor
final class TourneyViewModel: ObservableObject {
    private let repository: InMemoryJuicdRepository
    private var userId: UUID?

    @Published private(set) var gameOptions: [DailyGameOption] = []
    @Published var selectedGameId: String?

    @Published private(set) var dailyClosest: DailyClosestTournamentState?
    @Published private(set) var lastDailyPickResult: DailyClosestPickResult?
    @Published var dailyPickText: String = "52.5"
    @Published var errorMessage: String?

    /// Active round’s locked prop (nil if not in a live run).
    var currentRoundSpec: DailyRoundPropSpec? {
        guard let st = dailyClosest, !st.completed, !st.eliminated else { return nil }
        return st.roundSpecs.first { $0.round == st.nextQuarter }
    }

    init(repository: InMemoryJuicdRepository) {
        self.repository = repository
    }

    func configure(userId: UUID?) {
        self.userId = userId
        guard let userId else { return }
        repository.resolveDailyRankOutcomes(userId: userId, now: .now)
        _ = repository.awardDailyPointsIfNeeded(userId: userId, date: .now)
        refreshGameOptions()
        refresh()
        dailyClosest = repository.dailyClosestState(userId: userId)
        lastDailyPickResult = nil
        errorMessage = nil
    }

    func refreshGameOptions() {
        gameOptions = repository.dailyGameOptions(now: .now)
        if selectedGameId == nil || !gameOptions.contains(where: { $0.id == selectedGameId }) {
            selectedGameId = gameOptions.first?.id
        }
    }

    func refresh() {
        guard let userId else { return }
        dailyClosest = repository.dailyClosestState(userId: userId)
        refreshGameOptions()
        refreshSuggestedPickText()
    }

    /// Sets `dailyPickText` to a reasonable midpoint for the next round (after enter or submit).
    func refreshSuggestedPickText() {
        guard let spec = currentRoundSpec else { return }
        let mid = (spec.simMin + spec.simMax) / 2
        dailyPickText = String(format: "%.1f", (mid * 10).rounded() / 10)
    }

    func enterDailyClosest() {
        guard let userId else { return }
        guard let gid = selectedGameId else {
            errorMessage = "Pick a game first."
            return
        }
        errorMessage = nil
        dailyClosest = repository.enterDailyClosestTournament(userId: userId, gameId: gid)
        if dailyClosest == nil {
            errorMessage = "Entry closed for that game or we couldn’t start the bracket."
        } else {
            refreshSuggestedPickText()
        }
    }

    /// Demo: auto-submit picks until the bracket ends (win, loss, or cap). Uses local random jitter around each round’s midpoint.
    func simulateFullBracketDemo() {
        guard let userId else { return }
        errorMessage = nil
        var iterations = 0
        while iterations < 16 {
            iterations += 1
            refresh()
            guard let st = dailyClosest, !st.completed, !st.eliminated else { break }
            guard let spec = st.roundSpecs.first(where: { $0.round == st.nextQuarter }) else {
                errorMessage = "Missing round data."
                break
            }
            let mid = (spec.simMin + spec.simMax) / 2
            let jitter = Double.random(in: -2.8 ... 2.8)
            let v = max(spec.simMin, min(spec.simMax, mid + jitter))
            dailyPickText = String(format: "%.1f", (v * 10).rounded() / 10)
            guard let pick = Double(dailyPickText.replacingOccurrences(of: ",", with: ".")) else { break }
            lastDailyPickResult = repository.submitDailyClosestPick(userId: userId, pick: pick, playthrough: true)
            if lastDailyPickResult == nil { break }
        }
        refresh()
    }

    func submitDailyPick() {
        guard let userId else { return }
        let trimmed = dailyPickText.replacingOccurrences(of: ",", with: ".")
        guard let v = Double(trimmed) else {
            errorMessage = "Enter a number (e.g. 54.5)"
            return
        }
        errorMessage = nil
        lastDailyPickResult = repository.submitDailyClosestPick(userId: userId, pick: v)
        refresh()
        if lastDailyPickResult == nil {
            errorMessage = "Enter the tournament first, or your run may already be over."
        }
    }
}
