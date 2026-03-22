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
        }
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
