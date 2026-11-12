import GameKit
import SwiftUI
import UIKit

/// Clasamentul mondial prin Game Center (fara server propriu).
@MainActor
final class GameCenter: NSObject, ObservableObject, GKGameCenterControllerDelegate {
    static let shared = GameCenter()
    /// ID-ul clasamentului creat in App Store Connect.
    static let leaderboardID = "goldengoal.best"

    @Published private(set) var isAuthenticated = false
    /// Jucatorul nu e conectat la Game Center si nu avem ce fereastra sa-i aratam.
    @Published var needsSignIn = false

    private var signInController: UIViewController?
    private var pendingScore: Int?

    /// Porneste autentificarea in fundal. Fereastra de conectare apare doar cand jucatorul cere clasamentul.
    func start() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, _ in
            Task { @MainActor in
                guard let self else { return }
                self.signInController = viewController
                self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                if self.isAuthenticated {
                    self.needsSignIn = false
                    if let score = self.pendingScore { self.submit(score: score) }
                }
            }
        }
    }

    /// Trimite cel mai bun punctaj; Game Center pastreaza maximul.
    func submit(score: Int) {
        guard score > 0 else { return }
        guard isAuthenticated else {
            pendingScore = score
            return
        }
        pendingScore = nil
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local,
                                  leaderboardIDs: [Self.leaderboardID]) { _ in }
    }

    func showLeaderboard() {
        guard let top = Self.topController() else { return }
        if isAuthenticated {
            let controller = GKGameCenterViewController(leaderboardID: Self.leaderboardID,
                                                        playerScope: .global, timeScope: .allTime)
            controller.gameCenterDelegate = self
            top.present(controller, animated: true)
        } else if let signInController {
            top.present(signInController, animated: true)
        } else {
            needsSignIn = true
        }
    }

    nonisolated func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        Task { @MainActor in
            gameCenterViewController.dismiss(animated: true)
        }
    }

    private static func topController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
            ?? scene?.windows.first?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

// MARK: Insigne (tinute in aplicatie)

enum Badge: String, CaseIterable {
    case first, streak3, streak5, step5, step10, million

    var icon: String {
        switch self {
        case .first: return "soccerball"
        case .streak3: return "flame.fill"
        case .streak5: return "bolt.fill"
        case .step5: return "lock.shield.fill"
        case .step10: return "star.fill"
        case .million: return "trophy.fill"
        }
    }

    var name: String { L("badge.\(rawValue)") }

    /// Insignele meritate dupa starea curenta a jucatorului.
    static func earned(by player: LocalProgress) -> Set<String> {
        var earned = Set<String>()
        let decided = player.history.filter { $0.outcome != "void" }
        var streak = 0
        for item in decided {
            if item.outcome == "correct" { streak += 1 } else { break }
        }
        if decided.contains(where: { $0.outcome == "correct" }) { earned.insert(Badge.first.rawValue) }
        if streak >= 3 { earned.insert(Badge.streak3.rawValue) }
        if streak >= 5 { earned.insert(Badge.streak5.rawValue) }
        if player.level >= 5 || player.millions > 0 { earned.insert(Badge.step5.rawValue) }
        if player.level >= 10 || player.millions > 0 { earned.insert(Badge.step10.rawValue) }
        if player.millions > 0 { earned.insert(Badge.million.rawValue) }
        return earned
    }
}

struct BadgesCard: View {
    let earned: Set<String>

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(icon: "rosette", text: L("badge.title"))

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(Badge.allCases, id: \.self) { badge in
                    let has = earned.contains(badge.rawValue)
                    VStack(spacing: 6) {
                        Image(systemName: has ? badge.icon : "lock.fill")
                            .font(.title2)
                            .foregroundStyle(has ? Color.black.opacity(0.85) : Color.white.opacity(0.4))
                            .frame(width: 54, height: 54)
                            .background(has ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Color.white.opacity(0.08)),
                                        in: Circle())
                            .overlay(Circle().stroke(Theme.gold.opacity(has ? 1 : 0.25), lineWidth: 1))
                            .shadow(color: has ? Theme.gold.opacity(0.55) : Color.clear, radius: 8, x: 0, y: 0)
                        Text(badge.name)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.white.opacity(has ? 0.95 : 0.5))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

struct LeaderboardCard: View {
    @ObservedObject private var gameCenter = GameCenter.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                gameCenter.showLeaderboard()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "list.number")
                    Text(L("gc.leaderboard"))
                    Spacer()
                    Image(systemName: "chevron.forward")
                }
                .font(.headline)
                .foregroundStyle(Color.black.opacity(0.85))
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Theme.goldGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)

            Text(L("gc.desc"))
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)

            if gameCenter.needsSignIn {
                Label(L("gc.signin"), systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.goldLight)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
