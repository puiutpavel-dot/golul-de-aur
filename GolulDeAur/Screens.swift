import SwiftUI
import UIKit

/// Radacina aplicatiei: meniul de jos cu cele 4 ecrane.
struct RootView: View {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.01, green: 0.07, blue: 0.05, alpha: 1)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView {
            MatchScreen(model: model)
                .tabItem { Label(L("tab.match"), systemImage: "soccerball") }
            LadderScreen(model: model)
                .tabItem { Label(L("tab.ladder"), systemImage: "chart.bar.fill") }
            HistoryScreen(model: model)
                .tabItem { Label(L("tab.history"), systemImage: "clock.arrow.circlepath") }
            ProfileScreen(model: model)
                .tabItem { Label(L("tab.profile"), systemImage: "person.crop.circle.fill") }
        }
        .tint(Theme.gold)
        .task {
            GameCenter.shared.start()
            await model.refresh()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                Task { await model.refresh() }
            }
        }
    }
}

/// Cadrul comun al ecranelor: fundalul de teren si continut derulabil.
struct Screen<Content: View>: View {
    let model: AppModel
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            PitchBackground()

            ScrollView {
                VStack(spacing: 18) {
                    content()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            .refreshable { await model.refresh() }
        }
    }
}

struct ScreenHeader: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.goldGradient)
                    .frame(width: 44, height: 44)
                    .shadow(color: Theme.gold.opacity(0.6), radius: 10, x: 0, y: 0)
                Image(systemName: icon)
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.8))
            }
            Text(title)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.goldGradient)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
        }
    }
}

// MARK: Ecranul Meci

struct MatchScreen: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Screen(model: model) {
            header

            LadderCard(player: model.progress)

            if let match = model.todayMatch {
                MatchCard(match: match, myPick: model.myPick(for: match),
                          pickLifeline: model.lifeline(for: match),
                          usedLifelines: model.usedLifelines,
                          player: model.progress) { choice, lifeline in
                    model.pick(choice, lifeline: lifeline)
                }
                .id(match.day)
            } else if model.hasLoaded {
                InfoCard(icon: "clock", text: L("match.none"))
            } else if model.isLoading {
                ProgressView().tint(Theme.gold).padding(.top, 30)
            }

            if let error = model.errorMessage {
                InfoCard(icon: "exclamationmark.triangle.fill", text: error)
            }
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
        }
    }
}

// MARK: Ecranul Scara

struct LadderScreen: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Screen(model: model) {
            ScreenHeader(icon: "chart.bar.fill", title: L("tab.ladder"))
            LadderCard(player: model.progress)
            ShareButton(title: L("share.button.step"), player: model.progress)
            LadderBoard(level: model.progress.level)
        }
    }
}

// MARK: Ecranul Istoric

struct HistoryScreen: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Screen(model: model) {
            ScreenHeader(icon: "clock.arrow.circlepath", title: L("tab.history"))
            if model.progress.history.isEmpty {
                InfoCard(icon: "tray", text: L("history.empty"))
            } else {
                HistoryCard(items: model.progress.history)
            }
        }
    }
}

// MARK: Ecranul Profil

struct ProfileScreen: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Screen(model: model) {
            ScreenHeader(icon: "person.fill", title: L("tab.profile"))
            StatsStrip(player: model.progress)
            LeaderboardCard()
            BadgesCard(earned: Set(model.progress.badges ?? []))
            NotificationsCard(model: model)
            RulesCard()
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
        let wrong = player.history.filter { $0.outcome == "wrong" || $0.outcome == "saved" }.count
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
                        HStack(spacing: 5) {
                            if let lifeline = item.lifeline.flatMap(Lifeline.init(rawValue:)) {
                                Image(systemName: lifeline.icon)
                                    .foregroundStyle(Theme.gold)
                            }
                            Text(L("history.pick", pickLabel(item.pick, home: item.homeTeam, away: item.awayTeam)))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.6))
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

    private func icon(for outcome: String) -> String {
        switch outcome {
        case "correct": return "checkmark.circle.fill"
        case "wrong": return "xmark.circle.fill"
        case "saved": return "shield.lefthalf.filled"
        default: return "minus.circle.fill"
        }
    }

    private func color(for outcome: String) -> Color {
        switch outcome {
        case "correct": return Theme.correct
        case "wrong": return Theme.wrong
        case "saved": return Theme.gold
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

struct RulesCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(icon: "questionmark.circle.fill", text: L("rules.title"))
            rule("soccerball", L("rules.game1"))
            rule("hand.tap.fill", L("rules.game2"))
            rule("lock.fill", L("rules.lock"))
            rule("arrow.up.right.circle.fill", L("rules.game3"))

            SectionTitle(icon: "lifepreserver.fill", text: L("lifeline.title"))
            rule("lifepreserver.fill", L("rules.lifelines"))
            ForEach(Lifeline.allCases, id: \.self) { lifeline in
                rule(lifeline.icon, "\(lifeline.name): \(lifeline.detail)")
            }

            SectionTitle(icon: "lock.shield.fill", text: L("rules.section.safe"))
            rule("arrow.down.circle.fill",
                 L("rules.safe1", formatPoints(Ladder.points(forLevel: 5)), formatPoints(Ladder.points(forLevel: 10))))
            rule("moon.zzz.fill", L("rules.safe2"))

            Text(L("rules.disclaimer"))
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func rule(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Theme.gold)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
