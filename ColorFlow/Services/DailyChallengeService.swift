import Foundation

/// Provides deterministic daily template selection and streak tracking.
struct DailyChallengeService {

    // MARK: - Daily Template

    /// Returns today's challenge template using a date-seeded shuffle.
    /// The same template is returned for the same calendar day.
    static func todayTemplate(from templates: [Template]) -> Template? {
        guard !templates.isEmpty else { return nil }
        let components = Calendar.current.dateComponents([.year, .dayOfYear], from: Date())
        let seed = UInt64((components.year ?? 2025) * 366 + (components.dayOfYear ?? 1))
        var rng = SeededGenerator(seed: seed)
        return templates.shuffled(using: &rng).first
    }

    // MARK: - Streak

    private static let streakKey   = "challengeStreakCount"
    private static let lastDateKey = "challengeLastDate"

    /// Current streak count (0 if streak is broken).
    static var currentStreak: Int {
        let count = UserDefaults.standard.integer(forKey: streakKey)
        guard let last = UserDefaults.standard.object(forKey: lastDateKey) as? Date else { return 0 }
        let cal = Calendar.current
        if cal.isDateInToday(last) || cal.isDateInYesterday(last) { return count }
        return 0   // streak broken
    }

    /// Call when the user starts today's daily challenge.
    /// Increments the streak if they did yesterday's challenge (or this is their first).
    /// Safe to call multiple times per day — only counts once.
    static func recordChallenge() {
        let defaults = UserDefaults.standard
        let cal = Calendar.current

        if let last = defaults.object(forKey: lastDateKey) as? Date,
           cal.isDateInToday(last) {
            return   // already recorded today
        }

        let prevStreak = currentStreak
        let newStreak: Int
        if let last = defaults.object(forKey: lastDateKey) as? Date,
           cal.isDateInYesterday(last) {
            newStreak = prevStreak + 1
        } else {
            newStreak = 1   // first time or streak broken — reset to 1
        }

        defaults.set(newStreak, forKey: streakKey)
        defaults.set(Date(), forKey: lastDateKey)
    }
}

// MARK: - Seeded RNG

private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 1 : seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
