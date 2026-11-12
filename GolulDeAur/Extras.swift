import SwiftUI

// Ajutoare (partea vizuala), distribuire si setarea de notificari.

extension Lifeline {
    var icon: String {
        switch self {
        case .double: return "2.circle.fill"
        case .safety: return "shield.lefthalf.filled"
        case .boost: return "bolt.fill"
        }
    }

    var name: String { L("lifeline.\(rawValue).name") }
    var detail: String { L("lifeline.\(rawValue).desc") }
}

/// "1X" -> "Gazde / Egal".
func pickLabel(_ pick: String, home: String, away: String) -> String {
    pick.map { character -> String in
        switch character {
        case "1": return home
        case "2": return away
        default: return L("option.draw")
        }
    }
    .joined(separator: " / ")
}

// MARK: Distribuire

/// Imaginea trimisa pe WhatsApp, Instagram etc.: pronosticul (daca exista) si treapta.
struct ShareCard: View {
    let player: LocalProgress
    var match: Match? = nil
    var pick: String? = nil

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "soccerball")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.8))
                    .frame(width: 40, height: 40)
                    .background(Theme.goldGradient, in: Circle())
                Text("Golden Goal")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.goldGradient)
            }

            if let match, let pick {
                Text(match.league.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.white.opacity(0.7))

                HStack(alignment: .top, spacing: 8) {
                    team(match.homeTeam)
                    Text("VS")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.gold)
                        .frame(height: 60)
                    team(match.awayTeam)
                }

                VStack(spacing: 4) {
                    Text(L("share.mypick").uppercased())
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(Color.white.opacity(0.7))
                    Text(pickLabel(pick, home: match.homeTeam, away: match.awayTeam))
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.goldGradient)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            VStack(spacing: 6) {
                Text(L("ladder.step", player.level).uppercased())
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(Color.white.opacity(0.7))
                Text(formatPoints(Ladder.points(forLevel: player.level)))
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.goldGradient)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                StepTrack(level: player.level)
            }

            Text(L("share.cta"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .padding(26)
        .frame(width: 360)
        .background(
            ZStack {
                Theme.background
                PitchLines().stroke(Color.white.opacity(0.08), lineWidth: 2)
                RadialGradient(colors: [Theme.gold.opacity(0.3), Color.clear],
                               center: .top, startRadius: 0, endRadius: 300)
            }
        )
    }

    private func team(_ name: String) -> some View {
        VStack(spacing: 6) {
            TeamBadge(name: name, size: 60)
            Text(name)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ShareButton: View {
    let title: String
    let player: LocalProgress
    var match: Match? = nil
    var pick: String? = nil

    @State private var image: Image?

    var body: some View {
        ZStack {
            if let image {
                ShareLink(item: image, preview: SharePreview("Golden Goal", image: image)) {
                    label
                }
                .buttonStyle(.plain)
            } else {
                label.opacity(0.5)
            }
        }
        .task(id: "\(player.level)-\(player.millions)-\(pick ?? "")") {
            let rendered = await render()
            image = rendered
        }
    }

    private var label: some View {
        Label(title, systemImage: "square.and.arrow.up")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Theme.goldLight)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.gold.opacity(0.6), lineWidth: 1)
            )
    }

    @MainActor
    private func render() -> Image? {
        let renderer = ImageRenderer(content: ShareCard(player: player, match: match, pick: pick))
        renderer.scale = 3
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }
}

// MARK: Notificari

struct NotificationsCard: View {
    @ObservedObject var model: AppModel
    @AppStorage(Reminders.enabledKey) private var enabled = false
    @State private var denied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: Binding(get: { enabled }, set: { setEnabled($0) })) {
                Label(L("settings.notifications"), systemImage: "bell.badge.fill")
                    .font(.headline)
                    .foregroundStyle(Color.white)
            }
            .tint(Theme.gold)

            Text(L("settings.notifications.desc"))
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)

            if denied {
                Label(L("settings.notifications.denied"), systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.goldLight)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func setEnabled(_ value: Bool) {
        guard value else {
            enabled = false
            denied = false
            model.syncReminders()
            return
        }
        Task {
            let granted = await Reminders.requestPermission()
            enabled = granted
            denied = !granted
            model.syncReminders()
        }
    }
}
