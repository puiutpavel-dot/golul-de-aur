import SwiftUI

struct HomeView: View {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showLadder = false
    @State private var showRules = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    header

                    LadderCard(player: model.progress) { showLadder = true }

                    if let match = model.todayMatch {
                        MatchCard(match: match, myPick: model.myPick(for: match)) { choice in
                            model.pick(choice)
                        }
                    } else if model.hasLoaded {
                        InfoCard(icon: "clock", text: "Meciul zilei apare în fiecare zi după ora 9:00.")
                    } else if model.isLoading {
                        ProgressView().tint(Theme.gold).padding(.top, 30)
                    }

                    if !model.progress.history.isEmpty {
                        HistoryCard(items: model.progress.history)
                    }

                    if let error = model.errorMessage {
                        InfoCard(icon: "exclamationmark.triangle.fill", text: error)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .refreshable { await model.refresh() }
        }
        .task { await model.refresh() }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                Task { await model.refresh() }
            }
        }
        .sheet(isPresented: $showLadder) {
            LadderView(level: model.progress.level)
        }
        .sheet(isPresented: $showRules) {
            RulesView()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Golul de Aur")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("Un meci pe zi. 15 trepte până la milion.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            Button {
                showRules = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }
}

// MARK: Pozitia pe scara

struct LadderCard: View {
    let player: LocalProgress
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Treapta \(player.level) din 15")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    if player.millions > 0 {
                        Label("\(player.millions)", systemImage: "trophy.fill")
                            .font(.caption.bold())
                            .foregroundStyle(Theme.gold)
                    }
                }
                Text(formatPoints(Ladder.points(forLevel: player.level)))
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.gold)

                ProgressView(value: Double(player.level), total: 15)
                    .tint(Theme.gold)

                HStack {
                    Text("Următoarea treaptă: \(formatPoints(Ladder.points(forLevel: player.level + 1)))")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
            }
            .padding(18)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}

// MARK: Meciul zilei

struct MatchCard: View {
    let match: Match
    let myPick: String?
    let onPick: (String) -> Void

    private var isOpen: Bool { match.isOpen() }

    private var kickoffText: String {
        guard let kickoff = match.kickoff else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ro_RO")
        formatter.dateFormat = "d MMMM, HH:mm"
        return formatter.string(from: kickoff)
    }

    private var statusText: String {
        if match.isVoid {
            return "Meciul nu s-a mai jucat. Rămâi pe aceeași treaptă."
        }
        if match.isFinished {
            guard let pick = myPick else { return "Nu ai dat pronostic la acest meci." }
            return pick == match.result ? "Ai ghicit! Ai urcat o treaptă." : "N-ai ghicit de data asta."
        }
        if isOpen {
            return myPick == nil
                ? "Cine câștigă? Alege până la fluierul de start."
                : "Pronostic salvat. Îl poți schimba până la start."
        }
        return myPick == nil
            ? "Meciul a început. Pronosticurile s-au închis."
            : "Meciul a început. Rezultatul apare după final."
    }

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text(match.league.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Text(kickoffText)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }

            HStack(alignment: .center) {
                Text(match.homeTeam)
                    .frame(maxWidth: .infinity)
                if let home = match.homeScore, let away = match.awayScore {
                    Text("\(home) - \(away)")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.gold)
                } else {
                    Text("vs")
                        .foregroundStyle(.white.opacity(0.5))
                }
                Text(match.awayTeam)
                    .frame(maxWidth: .infinity)
            }
            .font(.title3.weight(.bold))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)

            Text(statusText)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))

            option(letter: "A", choice: "1", title: match.homeTeam, odds: match.oddsHome)
            option(letter: "B", choice: "X", title: "Egal", odds: match.oddsDraw)
            option(letter: "C", choice: "2", title: match.awayTeam, odds: match.oddsAway)
        }
        .padding(18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
    }

    private func option(letter: String, choice: String, title: String, odds: Double) -> some View {
        let isMine = myPick == choice
        return Button {
            onPick(choice)
        } label: {
            HStack(spacing: 12) {
                Text(letter)
                    .font(.headline)
                    .foregroundStyle(Theme.gold)
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Text(String(format: "%.2f", odds))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.55))
                if isMine {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background(optionColor(choice), in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.gold.opacity(isMine ? 0.9 : 0.25), lineWidth: 1)
            )
        }
        .disabled(!isOpen)
    }

    private func optionColor(_ choice: String) -> Color {
        if match.isFinished {
            if choice == match.result { return Theme.correct }
            if choice == myPick { return Theme.wrong }
            return Theme.card
        }
        return choice == myPick ? Theme.gold.opacity(0.35) : Theme.card
    }
}

// MARK: Istoric

struct HistoryCard: View {
    let items: [HistoryItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ultimele pronosticuri")
                .font(.headline)
                .foregroundStyle(.white)

            ForEach(items) { item in
                HStack(spacing: 10) {
                    Image(systemName: icon(for: item.outcome))
                        .foregroundStyle(color(for: item.outcome))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(item.homeTeam) \(scoreText(item)) \(item.awayTeam)")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("Ai ales: \(pickText(item))")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    if let before = item.levelBefore, let after = item.levelAfter {
                        Text("\(before) → \(after)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
    }

    private func scoreText(_ item: HistoryItem) -> String {
        if let home = item.homeScore, let away = item.awayScore {
            return "\(home)-\(away)"
        }
        return "-"
    }

    private func pickText(_ item: HistoryItem) -> String {
        switch item.pick {
        case "1": return item.homeTeam
        case "2": return item.awayTeam
        default: return "Egal"
        }
    }

    private func icon(for outcome: String) -> String {
        switch outcome {
        case "correct": return "checkmark.circle.fill"
        case "wrong": return "xmark.circle.fill"
        default: return "minus.circle.fill"
        }
    }

    private func color(for outcome: String) -> Color {
        switch outcome {
        case "correct": return Theme.correct
        case "wrong": return Theme.wrong
        default: return .gray
        }
    }
}

struct InfoCard: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.85))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: Scara de puncte

struct LadderView: View {
    let level: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array((1...15).reversed()), id: \.self) { step in
                    HStack {
                        Text("\(step)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .leading)
                        Text(formatPoints(Ladder.points(forLevel: step)))
                            .fontWeight(Ladder.safeLevels.contains(step) ? .bold : .regular)
                        Spacer()
                        if Ladder.safeLevels.contains(step) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundStyle(Theme.gold)
                        }
                        if step <= level {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.correct)
                        }
                    }
                    .listRowBackground(step == level ? Theme.gold.opacity(0.25) : Color.clear)
                }
            }
            .navigationTitle("Scara de puncte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gata") { dismiss() }
                }
            }
        }
    }
}

struct RulesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Jocul") {
                    Text("În fiecare zi primești un singur meci real: cel mai echilibrat al zilei, adică meciul cu cele mai apropiate cote.")
                    Text("Alegi până la fluierul de start: A câștigă gazdele, B egal, C câștigă oaspeții.")
                    Text("Dacă ai ghicit, urci o treaptă. După 15 trepte ajungi la un milion de puncte și începi o scară nouă.")
                }
                Section("Praguri garantate") {
                    Text("Dacă nu ghicești, cobori la ultimul prag garantat: treapta 5 (1.000 de puncte) sau treapta 10 (32.000 de puncte). Sub treapta 5 o iei de la zero.")
                    Text("Dacă nu dai pronostic într-o zi, rămâi pe aceeași treaptă.")
                }
                Section {
                    Text("Punctele sunt virtuale și nu au valoare în bani. Cotele sunt afișate doar ca informație.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Cum se joacă")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gata") { dismiss() }
                }
            }
        }
    }
}
