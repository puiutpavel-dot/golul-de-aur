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

/// Text tradus dupa limba telefonului (Resources/<limba>.lproj/Localizable.strings).
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), locale: Locale.current, arguments: args)
}

func formatPoints(_ value: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    let number = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    return L("points.format", number)
}
