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

    /// Ajutorul folosit la pronosticul pentru acest meci.
    func lifeline(for match: Match) -> Lifeline? {
        let raw = progress.activeLifelines?[match.day]
            ?? progress.history.first(where: { $0.day == match.day })?.lifeline
        return raw.flatMap(Lifeline.init(rawValue:))
    }

    var usedLifelines: Set<String> { Set(progress.usedLifelines ?? []) }

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
        syncReminders()
    }

    /// Pronosticul se da o singura data: dupa confirmare nu mai poate fi schimbat.
    /// `choice` are o varianta ("1", "X", "2") sau doua ("1X") cu Sansa dubla.
    func pick(_ choice: String, lifeline: Lifeline?) {
        guard let match = todayMatch, match.isOpen(), myPick(for: match) == nil else { return }
        guard choice.count == (lifeline == .double ? 2 : 1) else { return }
        if let lifeline {
            guard !usedLifelines.contains(lifeline.rawValue) else { return }
            progress.usedLifelines = (progress.usedLifelines ?? []) + [lifeline.rawValue]
            var active = progress.activeLifelines ?? [:]
            active[match.day] = lifeline.rawValue
            progress.activeLifelines = active
        }
        progress.picks[match.day] = choice
        progress.save()

        Task {
            // Prima data dupa un pronostic intrebam daca vrea notificari.
            if !Reminders.wasAsked, await Reminders.requestPermission() {
                Reminders.isEnabled = true
            }
            syncReminders()
        }
    }

    func syncReminders() {
        let hasPick = todayMatch.map { myPick(for: $0) != nil } ?? false
        Reminders.sync(match: todayMatch, hasPick: hasPick)
    }

    /// Aplica regulile scarii pentru meciurile terminate la care exista pronostic.
    private func settleFinishedMatches() {
        var changed = false
        for match in matches.sorted(by: { $0.day < $1.day }) {
            guard let pick = progress.picks[match.day], match.isFinished || match.isVoid else { continue }

            let before = progress.level
            let rawLifeline = progress.activeLifelines?[match.day]
            var outcome = "void"
            if match.isFinished, let result = match.result {
                let settlement = Ladder.settle(level: before, pick: pick, result: result,
                                               lifeline: rawLifeline.flatMap(Lifeline.init(rawValue:)))
                outcome = settlement.outcome
                progress.level = settlement.level
                if settlement.wonMillion { progress.millions += 1 }
                if settlement.resetsLifelines { progress.usedLifelines = [] }
            } else if let rawLifeline {
                // Meciul nu s-a jucat: ajutorul se intoarce.
                progress.usedLifelines = (progress.usedLifelines ?? []).filter { $0 != rawLifeline }
            }

            progress.history.insert(
                HistoryItem(day: match.day, homeTeam: match.homeTeam, awayTeam: match.awayTeam,
                            homeScore: match.homeScore, awayScore: match.awayScore,
                            pick: pick, outcome: outcome,
                            levelBefore: before, levelAfter: progress.level,
                            lifeline: rawLifeline),
                at: 0)
            progress.picks[match.day] = nil
            progress.activeLifelines?[match.day] = nil
            changed = true
        }
        if changed {
            progress.history = Array(progress.history.prefix(30))
            progress.save()
        }
    }
}
