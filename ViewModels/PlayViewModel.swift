import Foundation
import Combine

@MainActor
final class PlayViewModel: ObservableObject {
    private let repository: InMemoryJuicdRepository
    private var userId: UUID?

    @Published private(set) var profile: Profile?
    @Published var liveLine: LiveOddsLine?
    @Published var oddsStatus: String = "Tap to load odds"
    @Published var isLoadingOdds = false

    /// Stub board rows for games “today” (API only fills the first live line to save quota).
    @Published private(set) var boardRows: [PlayBoardRow] = []

    init(repository: InMemoryJuicdRepository) {
        self.repository = repository
    }

    func configure(userId: UUID?) {
        self.userId = userId
        guard let userId else { return }
        _ = repository.awardDailyPointsIfNeeded(userId: userId, date: .now)
        profile = repository.profile(userId: userId)
        boardRows = Self.stubBoard()
    }

    func refreshLiveOddsLine() async {
        guard OddsAPIConfig.isConfigured else {
            oddsStatus = "Add ODDS_API_KEY in Xcode target Info to load a live line."
            return
        }
        isLoadingOdds = true
        oddsStatus = "Loading one line…"
        let line = await TheOddsAPIService.fetchOneCachedLine()
        liveLine = line
        isLoadingOdds = false
        if let line {
            oddsStatus = "Live (cached up to 1h) · \(line.sportKey)"
            if let first = boardRows.indices.first {
                boardRows[first] = PlayBoardRow(
                    id: boardRows[first].id,
                    title: line.eventTitle,
                    subtitle: "Moneyline · \(line.pickLabel)",
                    oddsText: String(format: "%.2f", line.oddsDecimal),
                    isLiveFromAPI: true
                )
            }
        } else {
            oddsStatus = "Couldn’t load odds (off-season or network)."
        }
    }

    private static func stubBoard() -> [PlayBoardRow] {
        [
            PlayBoardRow(
                id: UUID(),
                title: "Away @ Home",
                subtitle: "Moneyline — tap Refresh for API",
                oddsText: "—",
                isLiveFromAPI: false
            ),
            PlayBoardRow(
                id: UUID(),
                title: "Evening game · TBD",
                subtitle: "Spread / total (prototype)",
                oddsText: "—",
                isLiveFromAPI: false
            ),
            PlayBoardRow(
                id: UUID(),
                title: "Primetime",
                subtitle: "Check back closer to kickoff",
                oddsText: "—",
                isLiveFromAPI: false
            )
        ]
    }
}

struct PlayBoardRow: Identifiable, Equatable {
    let id: UUID
    var title: String
    var subtitle: String
    var oddsText: String
    var isLiveFromAPI: Bool
}
