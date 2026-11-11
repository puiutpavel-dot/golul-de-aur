import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var matches: [Match] = []
    @Published private(set) var progress = LocalProgress.load()
    @Published private(set) var hasLoaded = false
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    /// Meciul zilei (cel mai recent din lista).
    var todayMatch: Match? { matches.first }

    func myPick(for match: Match) -> String? {
        progress.picks[match.day] ?? progress.history.first(where: { $0.day == match.day })?.pick
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            matches = try await Backend.loadMatches()
            hasLoaded = true
            errorMessage = nil
            settleFinishedMatches()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func pick(_ choice: String) {
        guard let match = todayMatch, match.isOpen() else { return }
        progress.picks[match.day] = choice
        progress.save()
    }

    /// Aplica regulile scarii pentru meciurile terminate la care exista pronostic.
    private func settleFinishedMatches() {
        var changed = false
        for match in matches.sorted(by: { $0.day < $1.day }) {
            guard let pick = progress.picks[match.day], match.isFinished || match.isVoid else { continue }

            let before = progress.level
            var outcome = "void"
            if match.isFinished, let result = match.result {
                let correct = pick == result
                outcome = correct ? "correct" : "wrong"
                if correct && before == Ladder.steps.count - 1 {
                    progress.millions += 1
                }
                progress.level = Ladder.nextLevel(from: before, correct: correct)
            }

            progress.history.insert(
                HistoryItem(day: match.day, homeTeam: match.homeTeam, awayTeam: match.awayTeam,
                            homeScore: match.homeScore, awayScore: match.awayScore,
                            pick: pick, outcome: outcome,
                            levelBefore: before, levelAfter: progress.level),
                at: 0)
            progress.picks[match.day] = nil
            changed = true
        }
        if changed {
            progress.history = Array(progress.history.prefix(30))
            progress.save()
        }
    }
}
