import Foundation
import Combine

@MainActor
final class TourneyViewModel: ObservableObject {
    private let repository: InMemoryJuicdRepository
    private var userId: UUID?

    @Published private(set) var definitions: [WeeklyBracketDefinition] = []
    @Published private(set) var progress: UserBracketProgress?
    @Published private(set) var lastResult: InMemoryJuicdRepository.BracketRoundResult?

    init(repository: InMemoryJuicdRepository) {
        self.repository = repository
    }

    func configure(userId: UUID?) {
        self.userId = userId
        guard userId != nil else { return }
        definitions = repository.bracketDefinitions()
        refresh()
    }

    func refresh() {
        guard let userId else { return }
        progress = repository.bracketProgress(for: userId)
    }

    func join(_ def: WeeklyBracketDefinition) {
        guard let userId else { return }
        repository.joinBracket(userId: userId, definitionId: def.id)
        lastResult = nil
        refresh()
    }

    func leave() {
        guard let userId else { return }
        repository.leaveBracket(userId: userId)
        lastResult = nil
        refresh()
    }

    func playNextRound() {
        guard let userId else { return }
        lastResult = repository.simulateNextBracketRound(userId: userId)
        refresh()
    }
}
