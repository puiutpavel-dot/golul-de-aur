import SwiftUI

struct HomeView: View {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showRules = false

    var body: some View {
        ZStack {
            PitchBackground()

            ScrollView {
                VStack(spacing: 18) {
                    header

                    LadderCard(player: model.progress)

                    StatsStrip(player: model.progress)

                    if let match = model.todayMatch {
                        MatchCard(match: match, myPick: model.myPick(for: match)) { choice in
                            model.pick(choice)
                        }
                        .id(match.day)
                    } else if model.hasLoaded {
                        InfoCard(icon: "clock", text: L("match.none"))
                    } else if model.isLoading {
                        ProgressView().tint(Theme.gold).padding(.top, 30)
                    }

                    LadderBoard(level: model.progress.level)

                    if !model.progress.history.isEmpty {
                        HistoryCard(items: model.progress.history)
                    }

                    if let error = model.errorMessage {
                        InfoCard(icon: "exclamationmark.triangle.fill", text: error)
                    }
                }
                .padding(.horizontal, 18)
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
        .sheet(isPresented: $showRules) {
            RulesView()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.goldGradient)
                    .frame(width: 50, height: 50)
                    .shadow(color: Theme.gold.opacity(0.6), radius: 10, x: 0, y: 0)
                Image(systemName: "soccerball")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.8))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Golden Goal")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.goldGradient)
                Text(L("app.tagline"))
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.75))
            }
            Spacer()
            Button {
                showRules = true
            } label: {
                Image(systemName: "questionmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(Color.white.opacity(0.85))
            }
        }
    }
}

// MARK: Pozitia pe scara

struct LadderCard: View {
    let player: LocalProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Pill(icon: "figure.stairs", text: L("ladder.step", player.level),
                     color: Theme.gold.opacity(0.2), foreground: Theme.goldLight)
                Spacer()
                if player.millions > 0 {
                    Pill(icon: "trophy.fill", text: "\(player.millions)",
                         color: Theme.gold, foreground: Color.black.opacity(0.85))
                }
            }

            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.goldGradient)
                Text(formatPoints(Ladder.points(forLevel: player.level)))
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.goldGradient)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .shadow(color: Theme.gold.opacity(0.45), radius: 8, x: 0, y: 0)
            }

            StepTrack(level: player.level)

            HStack(spacing: 6) {
                Image(systemName: "arrow.up.right.circle.fill")
                    .foregroundStyle(Theme.gold)
                Text(L("ladder.next", formatPoints(Ladder.points(forLevel: player.level + 1))))
                    .foregroundStyle(Color.white.opacity(0.8))
            }
            .font(.caption.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(highlighted: true)
    }
}

/// Cele 15 trepte pe orizontala: aurii cele urcate, cu scut pragurile garantate.
struct StepTrack: View {
    let level: Int

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(1...Ladder.steps.count, id: \.self) { step in
                VStack(spacing: 3) {
                    marker(for: step)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(step <= level ? Theme.gold : Color.white.opacity(0.45))
                        .frame(height: 11)
                    Capsule()
                        .fill(step <= level
                              ? AnyShapeStyle(Theme.goldGradient)
                              : AnyShapeStyle(Color.white.opacity(0.14)))
                        .frame(height: step == level ? 12 : 8)
                        .shadow(color: step == level ? Theme.gold.opacity(0.9) : Color.clear,
                                radius: 5, x: 0, y: 0)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func marker(for step: Int) -> some View {
        if step == Ladder.steps.count {
            Image(systemName: "trophy.fill")
        } else if Ladder.safeLevels.contains(step) {
            Image(systemName: "lock.shield.fill")
        } else {
            Color.clear
        }
    }
}

// MARK: Statistici

struct StatsStrip: View {
    let player: LocalProgress

    private var streak: Int {
        var count = 0
        for item in player.history where item.outcome != "void" {
            if item.outcome == "correct" { count += 1 } else { break }
        }
        return count
    }

    private var accuracy: String {
        let correct = player.history.filter { $0.outcome == "correct" }.count
        let wrong = player.history.filter { $0.outcome == "wrong" }.count
        guard correct + wrong > 0 else { return "–" }
        return "\(Int((Double(correct) / Double(correct + wrong) * 100).rounded()))%"
    }

    var body: some View {
        HStack(spacing: 10) {
            tile(icon: "flame.fill", color: Color.orange, value: "\(streak)", label: L("stats.streak"))
            tile(icon: "scope", color: Theme.correct, value: accuracy, label: L("stats.accuracy"))
            tile(icon: "trophy.fill", color: Theme.gold, value: "\(player.millions)", label: L("stats.millions"))
        }
    }

    private func tile(icon: String, color: Color, value: String, label: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Color.white.opacity(0.65))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            ZStack {
                shape.fill(Theme.cardBase)
                shape.fill(LinearGradient(colors: [color.opacity(0.28), Color.clear],
                                          startPoint: .top, endPoint: .bottom))
            }
        )
        .overlay(shape.stroke(color.opacity(0.45), lineWidth: 1))
    }
}

// MARK: Meciul zilei

struct MatchCard: View {
    let match: Match
    let myPick: String?
    let onConfirm: (String) -> Void

    /// Varianta atinsa, inca neconfirmata.
    @State private var selected: String?

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 30)) { context in
            content(now: context.date)
        }
    }

    private func content(now: Date) -> some View {
        let isOpen = match.isOpen(at: now)
        let canChoose = isOpen && myPick == nil

        return VStack(spacing: 16) {
            HStack {
                Pill(icon: "sportscourt.fill", text: match.league.uppercased())
                Spacer()
                stagePill(isOpen: isOpen, now: now)
            }

            Text(kickoffText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.75))

            HStack(alignment: .top, spacing: 8) {
                team(match.homeTeam)
                scoreBox
                team(match.awayTeam)
            }

            statusBanner(isOpen: isOpen)

            VStack(spacing: 10) {
                option(letter: "A", choice: "1", title: match.homeTeam, odds: match.oddsHome, canChoose: canChoose)
                option(letter: "B", choice: "X", title: L("option.draw"), odds: match.oddsDraw, canChoose: canChoose)
                option(letter: "C", choice: "2", title: match.awayTeam, odds: match.oddsAway, canChoose: canChoose)
            }

            if canChoose, let choice = selected {
                VStack(spacing: 8) {
                    Button {
                        onConfirm(choice)
                    } label: {
                        Label(L("pick.confirm"), systemImage: "lock.fill")
                            .font(.headline)
                            .foregroundStyle(Color.black.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Theme.goldGradient,
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Theme.gold.opacity(0.55), radius: 10, x: 0, y: 0)
                    }
                    .buttonStyle(.plain)

                    Label(L("pick.warning"), systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.goldLight)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .card(highlighted: canChoose)
    }

    // MARK: Parti

    private var kickoffText: String {
        guard let kickoff = match.kickoff else { return "" }
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEdMMMMHHmm")
        return formatter.string(from: kickoff)
    }

    private func countdown(to kickoff: Date, from now: Date) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter.string(from: max(60, kickoff.timeIntervalSince(now))) ?? ""
    }

    @ViewBuilder
    private func stagePill(isOpen: Bool, now: Date) -> some View {
        if match.isFinished {
            Pill(icon: "flag.checkered", text: L("match.final"))
        } else if match.isVoid {
            Pill(icon: "minus.circle.fill", text: "–")
        } else if isOpen, let kickoff = match.kickoff {
            Pill(icon: "timer", text: L("match.countdown", countdown(to: kickoff, from: now)),
                 color: Theme.gold.opacity(0.22), foreground: Theme.goldLight)
        } else {
            Pill(icon: "dot.radiowaves.left.and.right", text: L("match.live"),
                 color: Theme.wrong.opacity(0.85), foreground: Color.white)
        }
    }

    private func team(_ name: String) -> some View {
        VStack(spacing: 8) {
            TeamBadge(name: name)
            Text(name)
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var scoreBox: some View {
        Group {
            if let home = match.homeScore, let away = match.awayScore {
                Text("\(home) - \(away)")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.goldGradient)
                    .lineLimit(1)
                    .fixedSize()
            } else {
                Text("VS")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.85))
                    .frame(width: 46, height: 46)
                    .background(Theme.goldGradient, in: Circle())
                    .shadow(color: Theme.gold.opacity(0.6), radius: 8, x: 0, y: 0)
            }
        }
        .frame(height: 66)
    }

    private func statusBanner(isOpen: Bool) -> some View {
        var icon = "hand.tap.fill"
        var color = Color.white.opacity(0.1)
        var text = L("status.open.nopick")

        if match.isVoid {
            icon = "minus.circle.fill"
            text = L("status.void")
        } else if match.isFinished {
            if let pick = myPick {
                let correct = pick == match.result
                icon = correct ? "checkmark.seal.fill" : "xmark.seal.fill"
                color = (correct ? Theme.correct : Theme.wrong).opacity(0.55)
                text = correct ? L("status.correct") : L("status.wrong")
            } else {
                icon = "moon.zzz.fill"
                text = L("status.nopick")
            }
        } else if isOpen {
            if myPick != nil {
                icon = "lock.fill"
                color = Theme.gold.opacity(0.22)
                text = L("status.open.picked")
            }
        } else {
            icon = myPick == nil ? "lock.slash.fill" : "hourglass"
            text = myPick == nil ? L("status.started.nopick") : L("status.started.picked")
        }

        return HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Theme.goldLight)
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(color, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func option(letter: String, choice: String, title: String, odds: Double, canChoose: Bool) -> some View {
        let isMine = myPick == choice
        let isSelected = myPick == nil && selected == choice
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                selected = choice
            }
        } label: {
            HStack(spacing: 12) {
                Text(letter)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.85))
                    .frame(width: 34, height: 34)
                    .background(Theme.goldGradient, in: Circle())
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                Text(String(format: "%.2f", odds))
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.3), in: Capsule())
                if isMine {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(Theme.goldLight)
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.white)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(optionColor(choice, isSelected: isSelected), in: shape)
            .overlay(
                shape.stroke(Theme.gold.opacity(isMine || isSelected ? 1 : 0.3),
                             lineWidth: isMine || isSelected ? 2 : 1)
            )
            .shadow(color: isMine || isSelected ? Theme.gold.opacity(0.45) : Color.clear,
                    radius: 8, x: 0, y: 0)
            .opacity(dimmed(choice) ? 0.5 : 1)
            .scaleEffect(isSelected ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!canChoose)
    }

    /// Dupa blocare, variantele nealese raman estompate.
    private func dimmed(_ choice: String) -> Bool {
        if match.isFinished {
            return choice != match.result && choice != myPick
        }
        return myPick != nil && myPick != choice
    }

    private func optionColor(_ choice: String, isSelected: Bool) -> Color {
        if match.isFinished {
            if choice == match.result { return Theme.correct }
            if choice == myPick { return Theme.wrong }
            return Color.white.opacity(0.08)
        }
        if choice == myPick || isSelected { return Theme.gold.opacity(0.35) }
        return Color.white.opacity(0.08)
    }
}

// MARK: Scara de puncte (progresia)

struct LadderBoard: View {
    let level: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(icon: "chart.bar.fill", text: L("ladder.title"))

            VStack(spacing: 5) {
                ForEach(Array((1...Ladder.steps.count).reversed()), id: \.self) { step in
                    row(step)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func row(_ step: Int) -> some View {
        let isCurrent = step == level
        let isDone = step < level
        let isSafe = Ladder.safeLevels.contains(step)
        let isTop = step == Ladder.steps.count
        let textColor = isCurrent ? Color.black.opacity(0.85) : Color.white.opacity(isDone ? 0.95 : 0.6)

        return HStack(spacing: 10) {
            Text("\(step)")
                .font(.caption.monospacedDigit().weight(.heavy))
                .foregroundStyle(isCurrent ? Color.black.opacity(0.7) : Theme.gold.opacity(isDone ? 1 : 0.6))
                .frame(width: 22, alignment: .trailing)

            if isTop {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(isCurrent ? Color.black.opacity(0.8) : Theme.gold)
            } else if isSafe {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(isCurrent ? Color.black.opacity(0.8) : Theme.gold)
            }

            Text(formatPoints(Ladder.points(forLevel: step)))
                .font(.system(size: isTop || isCurrent ? 17 : 15,
                              weight: isSafe || isTop || isCurrent ? .heavy : .semibold,
                              design: .rounded))
                .foregroundStyle(textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 4)

            if isCurrent {
                HStack(spacing: 4) {
                    Text(L("ladder.here").uppercased())
                        .font(.system(size: 10, weight: .heavy))
                        .lineLimit(1)
                    Image(systemName: "soccerball")
                }
                .foregroundStyle(Color.black.opacity(0.8))
            } else if isDone {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.correct)
            } else if isSafe {
                Text(L("ladder.safe").uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(Theme.gold.opacity(0.8))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, isCurrent ? 9 : 6)
        .background(rowBackground(isCurrent: isCurrent, isDone: isDone), in: Capsule())
        .overlay(
            Capsule().stroke(Theme.gold.opacity(isSafe || isTop ? 0.7 : 0.12), lineWidth: 1)
        )
        .shadow(color: isCurrent ? Theme.gold.opacity(0.6) : Color.clear, radius: 8, x: 0, y: 0)
    }

    private func rowBackground(isCurrent: Bool, isDone: Bool) -> AnyShapeStyle {
        if isCurrent { return AnyShapeStyle(Theme.goldGradient) }
        if isDone { return AnyShapeStyle(Theme.correct.opacity(0.22)) }
        return AnyShapeStyle(Color.white.opacity(0.05))
    }
}

// MARK: Istoric

struct HistoryCard: View {
    let items: [HistoryItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(icon: "clock.arrow.circlepath", text: L("history.title"))

            ForEach(items) { item in
                HStack(spacing: 10) {
                    Image(systemName: icon(for: item.outcome))
                        .font(.title3)
                        .foregroundStyle(color(for: item.outcome))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(item.homeTeam) \(scoreText(item)) \(item.awayTeam)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(L("history.pick", pickText(item)))
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    if let before = item.levelBefore, let after = item.levelAfter {
                        Text("\(before) → \(after)")
                            .font(.caption.monospacedDigit().weight(.bold))
                            .foregroundStyle(Color.white.opacity(0.9))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(color(for: item.outcome).opacity(0.35), in: Capsule())
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.05),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
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
        default: return L("option.draw")
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
            .foregroundStyle(Color.white.opacity(0.85))
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
    }
}

// MARK: Reguli

struct RulesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section(L("rules.section.game")) {
                    Text(L("rules.game1"))
                    Text(L("rules.game2"))
                    Label(L("rules.lock"), systemImage: "lock.fill")
                    Text(L("rules.game3"))
                }
                Section(L("rules.section.safe")) {
                    Text(L("rules.safe1", formatPoints(Ladder.points(forLevel: 5)), formatPoints(Ladder.points(forLevel: 10))))
                    Text(L("rules.safe2"))
                }
                Section {
                    Text(L("rules.disclaimer"))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(L("rules.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.done")) { dismiss() }
                }
            }
        }
    }
}
