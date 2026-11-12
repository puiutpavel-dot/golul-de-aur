import Foundation
import UserNotifications

/// Notificari locale (fara server): meciul zilei, reamintire inainte de start, rezultat.
enum Reminders {
    static let enabledKey = "remindersEnabled"
    private static let askedKey = "remindersAsked"
    private static let identifiers = ["daily", "kickoff", "result"]

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// Am cerut deja permisiunea o data?
    static var wasAsked: Bool { UserDefaults.standard.bool(forKey: askedKey) }

    static func requestPermission() async -> Bool {
        UserDefaults.standard.set(true, forKey: askedKey)
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Reprogrameaza notificarile dupa starea curenta a meciului zilei.
    static func sync(match: Match?, hasPick: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        guard isEnabled else { return }

        // In fiecare zi la 09:30 ora Romaniei (meciul se alege dupa 09:00), convertit in ora telefonului.
        var bucharest = Calendar(identifier: .gregorian)
        bucharest.timeZone = TimeZone(identifier: "Europe/Bucharest") ?? .current
        if let morning = bucharest.date(bySettingHour: 9, minute: 30, second: 0, of: Date()) {
            let local = Calendar.current.dateComponents([.hour, .minute], from: morning)
            add("daily", body: L("notif.daily"),
                trigger: UNCalendarNotificationTrigger(dateMatching: local, repeats: true))
        }

        guard let match, match.status == "scheduled", let kickoff = match.kickoff else { return }
        if hasPick {
            // Scorul final apare de obicei la 2-3 ore dupa start.
            schedule("result", at: kickoff.addingTimeInterval(3 * 3600),
                     body: L("notif.result", match.homeTeam, match.awayTeam))
        } else {
            schedule("kickoff", at: kickoff.addingTimeInterval(-3600),
                     body: L("notif.kickoff", match.homeTeam, match.awayTeam))
        }
    }

    private static func schedule(_ identifier: String, at date: Date, body: String) {
        let delay = date.timeIntervalSinceNow
        guard delay > 60 else { return }
        add(identifier, body: body,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false))
    }

    private static func add(_ identifier: String, body: String, trigger: UNNotificationTrigger) {
        let content = UNMutableNotificationContent()
        content.title = "Golden Goal"
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }
}
