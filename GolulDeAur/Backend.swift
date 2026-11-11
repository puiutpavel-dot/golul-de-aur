import Foundation

/// Datele despre meciul zilei vin dintr-un fisier JSON din repo-ul GitHub,
/// actualizat automat de GitHub Actions. Progresul jucatorului se tine pe telefon.
enum Backend {
    /// Schimba adresa daca repo-ul are alt nume sau alt proprietar.
    static let dataURL = URL(string: "https://raw.githubusercontent.com/puiutpavel-dot/golul-de-aur/main/data/matches.json")!

    struct BackendError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private struct Payload: Decodable {
        let matches: [Match]
    }

    /// Meciurile, de la cel mai nou la cel mai vechi.
    static func loadMatches() async throws -> [Match] {
        var request = URLRequest(url: dataURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw BackendError(message: "Nu am putut încărca meciul zilei. Încearcă din nou.")
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Payload.self, from: data).matches.sorted { $0.day > $1.day }
    }
}

// MARK: Modele

struct Match: Decodable {
    let day: String
    let league: String
    let homeTeam: String
    let awayTeam: String
    let commenceTime: String
    let oddsHome: Double
    let oddsDraw: Double
    let oddsAway: Double
    let status: String
    let homeScore: Int?
    let awayScore: Int?
    let result: String?

    var kickoff: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: commenceTime) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: commenceTime)
    }

    var isFinished: Bool { status == "finished" }
    var isVoid: Bool { status == "void" }

    /// Se mai poate alege sau schimba pronosticul?
    func isOpen(at now: Date = Date()) -> Bool {
        guard status == "scheduled", let kickoff else { return false }
        return kickoff > now
    }
}

struct HistoryItem: Codable, Identifiable {
    let day: String
    let homeTeam: String
    let awayTeam: String
    let homeScore: Int?
    let awayScore: Int?
    let pick: String
    let outcome: String
    let levelBefore: Int?
    let levelAfter: Int?

    var id: String { day }
}

/// Progresul jucatorului, salvat pe telefon.
struct LocalProgress: Codable {
    /// Cate trepte ai urcat pe scara curenta (0...14).
    var level = 0
    /// De cate ori ai ajuns la milion.
    var millions = 0
    /// Pronosticuri in asteptare: zi -> "1", "X" sau "2".
    var picks: [String: String] = [:]
    /// Pronosticuri incheiate, de la cel mai nou la cel mai vechi.
    var history: [HistoryItem] = []

    private static let storageKey = "progress"

    static func load() -> LocalProgress {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode(LocalProgress.self, from: data) else {
            return LocalProgress()
        }
        return saved
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

// MARK: Scara de puncte

enum Ladder {
    /// Punctele virtuale pentru cele 15 trepte.
    static let steps: [Int] = [
        100, 200, 300, 500, 1_000,
        2_000, 4_000, 8_000, 16_000, 32_000,
        64_000, 125_000, 250_000, 500_000, 1_000_000
    ]
    /// Praguri garantate: dupa ce le atingi, nu mai cobori sub ele.
    static let safeLevels: Set<Int> = [5, 10]

    static func points(forLevel level: Int) -> Int {
        level <= 0 ? 0 : steps[min(level, steps.count) - 1]
    }

    /// Regula jocului: corect = urci o treapta (la a 15-a castigi milionul si
    /// incepi o scara noua); gresit = cobori la ultimul prag garantat.
    static func nextLevel(from level: Int, correct: Bool) -> Int {
        if correct {
            return level >= steps.count - 1 ? 0 : level + 1
        }
        if level >= 10 { return 10 }
        if level >= 5 { return 5 }
        return 0
    }
}
