import SwiftUI

/// Meciul zilei: alegi varianta (eventual cu un ajutor), confirmi o singura data.
struct MatchCard: View {
    let match: Match
    /// Pronosticul blocat: "1", "X", "2" sau doua variante ("1X") cu Sansa dubla.
    let myPick: String?
    /// Ajutorul folosit la pronosticul blocat.
    let pickLifeline: Lifeline?
    /// Ajutoarele deja consumate pe scara curenta.
    let usedLifelines: Set<String>
    let player: LocalProgress
    let onConfirm: (String, Lifeline?) -> Void

    /// Variantele atinse, inca neconfirmate.
    @State private var selected: [String] = []
    /// Ajutorul ales pentru acest meci, inca neconfirmat.
    @State private var lifeline: Lifeline?

    private var needed: Int { lifeline == .double ? 2 : 1 }

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

            if canChoose {
                lifelineRow
            } else if myPick != nil, let used = pickLifeline {
                Pill(icon: used.icon, text: used.name,
                     color: Theme.gold.opacity(0.22), foreground: Theme.goldLight)
            }

            VStack(spacing: 10) {
                option(letter: "A", choice: "1", title: match.homeTeam, odds: match.oddsHome, canChoose: canChoose)
                option(letter: "B", choice: "X", title: L("option.draw"), odds: match.oddsDraw, canChoose: canChoose)
                option(letter: "C", choice: "2", title: match.awayTeam, odds: match.oddsAway, canChoose: canChoose)
            }

            if canChoose, selected.count == needed {
                confirmBlock
            }

            if let pick = myPick, !match.isVoid {
                ShareButton(title: L("share.button.pick"), player: player, match: match, pick: pick)
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

    private var pickIsCorrect: Bool {
        guard let pick = myPick, let result = match.result else { return false }
        return pick.contains(result)
    }

    private func isMine(_ choice: String) -> Bool {
        myPick?.contains(choice) ?? false
    }

    private func statusBanner(isOpen: Bool) -> some View {
        var icon = "hand.tap.fill"
        var color = Color.white.opacity(0.1)
        var text = lifeline == .double ? L("pick.choose.two") : L("status.open.nopick")

        if match.isVoid {
            icon = "minus.circle.fill"
            text = L("status.void")
        } else if match.isFinished {
            if myPick == nil {
                icon = "moon.zzz.fill"
                text = L("status.nopick")
            } else if pickIsCorrect {
                icon = "checkmark.seal.fill"
                color = Theme.correct.opacity(0.55)
                text = pickLifeline == .boost ? L("status.correct.boost") : L("status.correct")
            } else if pickLifeline == .safety {
                icon = "shield.lefthalf.filled"
                color = Theme.gold.opacity(0.3)
                text = L("status.saved")
            } else {
                icon = "xmark.seal.fill"
                color = Theme.wrong.opacity(0.55)
                text = L("status.wrong")
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

    // MARK: Ajutoare

    private var lifelineRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(icon: "lifepreserver.fill", text: L("lifeline.title"))

            HStack(alignment: .top, spacing: 8) {
                ForEach(Lifeline.allCases, id: \.self) { item in
                    lifelineChip(item)
                }
            }

            if let active = lifeline {
                Text(active.detail)
                    .font(.caption)
                    .foregroundStyle(Theme.goldLight)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func lifelineChip(_ item: Lifeline) -> some View {
        let isUsed = usedLifelines.contains(item.rawValue)
        let isActive = lifeline == item
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        let foreground = isActive ? Color.black.opacity(0.85) : Color.white.opacity(0.9)

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                lifeline = isActive ? nil : item
                // Numarul de variante se schimba la Sansa dubla: o luam de la capat.
                selected = []
            }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: item.icon)
                    .font(.title3)
                    .foregroundStyle(isActive ? Color.black.opacity(0.85) : Theme.gold)
                Text(isUsed ? L("lifeline.used") : item.name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(foreground)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .background(isActive ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Color.white.opacity(0.08)),
                        in: shape)
            .overlay(shape.stroke(Theme.gold.opacity(isActive ? 1 : 0.35), lineWidth: 1))
            .opacity(isUsed ? 0.35 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isUsed)
    }

    // MARK: Variante si confirmare

    private func tap(_ choice: String) {
        guard lifeline == .double else {
            selected = [choice]
            return
        }
        if let index = selected.firstIndex(of: choice) {
            selected.remove(at: index)
        } else {
            if selected.count == 2 { selected.removeFirst() }
            selected.append(choice)
        }
    }

    private var confirmBlock: some View {
        VStack(spacing: 8) {
            Button {
                // Mereu in ordinea 1, X, 2, ca "1X" si "X1" sa fie acelasi pronostic.
                let choice = ["1", "X", "2"].filter { selected.contains($0) }.joined()
                onConfirm(choice, lifeline)
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

    private func option(letter: String, choice: String, title: String, odds: Double, canChoose: Bool) -> some View {
        let mine = isMine(choice)
        let isSelected = myPick == nil && selected.contains(choice)
        let strong = mine || isSelected
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                tap(choice)
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
                if mine {
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
            .overlay(shape.stroke(Theme.gold.opacity(strong ? 1 : 0.3), lineWidth: strong ? 2 : 1))
            .shadow(color: strong ? Theme.gold.opacity(0.45) : Color.clear, radius: 8, x: 0, y: 0)
            .opacity(dimmed(choice) ? 0.5 : 1)
            .scaleEffect(isSelected ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!canChoose)
    }

    /// Dupa blocare, variantele nealese raman estompate.
    private func dimmed(_ choice: String) -> Bool {
        if match.isFinished {
            return choice != match.result && !isMine(choice)
        }
        return myPick != nil && !isMine(choice)
    }

    private func optionColor(_ choice: String, isSelected: Bool) -> Color {
        if match.isFinished {
            if choice == match.result { return Theme.correct }
            // La Sansa dubla castigatoare, a doua varianta aleasa nu e o greseala.
            if isMine(choice) && !pickIsCorrect { return Theme.wrong }
            return Color.white.opacity(0.08)
        }
        if isMine(choice) || isSelected { return Theme.gold.opacity(0.35) }
        return Color.white.opacity(0.08)
    }
}
