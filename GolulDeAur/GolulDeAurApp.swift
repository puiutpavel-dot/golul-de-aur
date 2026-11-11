import SwiftUI

@main
struct GolulDeAurApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.dark)
        }
    }
}

enum Theme {
    static let background = LinearGradient(
        colors: [Color(red: 0.02, green: 0.16, blue: 0.10), Color(red: 0.01, green: 0.06, blue: 0.05)],
        startPoint: .top, endPoint: .bottom)
    static let gold = Color(red: 0.96, green: 0.77, blue: 0.22)
    static let card = Color.white.opacity(0.08)
    static let correct = Color(red: 0.13, green: 0.65, blue: 0.33)
    static let wrong = Color(red: 0.80, green: 0.20, blue: 0.20)
}

func formatPoints(_ value: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = "."
    formatter.usesGroupingSeparator = true
    return (formatter.string(from: NSNumber(value: value)) ?? "\(value)") + " puncte"
}
