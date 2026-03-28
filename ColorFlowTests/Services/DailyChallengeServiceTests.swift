import XCTest
@testable import ColorFlow

final class DailyChallengeServiceTests: XCTestCase {

    // Keys used by DailyChallengeService in UserDefaults.standard
    private let streakKey   = "challengeStreakCount"
    private let lastDateKey = "challengeLastDate"

    // Saved originals for restore in tearDown
    private var savedStreakCount: Int = 0
    private var savedLastDate: Date?

    override func setUp() {
        super.setUp()
        savedStreakCount = UserDefaults.standard.integer(forKey: streakKey)
        savedLastDate    = UserDefaults.standard.object(forKey: lastDateKey) as? Date
        // Clean state for each test
        UserDefaults.standard.removeObject(forKey: streakKey)
        UserDefaults.standard.removeObject(forKey: lastDateKey)
    }

    override func tearDown() {
        // Restore original values
        UserDefaults.standard.set(savedStreakCount, forKey: streakKey)
        if let d = savedLastDate {
            UserDefaults.standard.set(d, forKey: lastDateKey)
        } else {
            UserDefaults.standard.removeObject(forKey: lastDateKey)
        }
        super.tearDown()
    }

    // MARK: - todayTemplate

    func test_todayTemplate_emptyArray_returnsNil() {
        XCTAssertNil(DailyChallengeService.todayTemplate(from: []))
    }

    func test_todayTemplate_singleTemplate_returnsThatTemplate() {
        let t = TestHelpers.makeTemplate(name: "Only One")
        let result = DailyChallengeService.todayTemplate(from: [t])
        XCTAssertEqual(result?.id, t.id)
    }

    func test_todayTemplate_deterministic_sameDaySameResult() {
        let templates = (0..<5).map { TestHelpers.makeTemplate(name: "T\($0)") }
        let r1 = DailyChallengeService.todayTemplate(from: templates)
        let r2 = DailyChallengeService.todayTemplate(from: templates)
        XCTAssertEqual(r1?.id, r2?.id)
    }

    func test_todayTemplate_withMultipleTemplates_returnsNonNil() {
        let templates = (0..<11).map { TestHelpers.makeTemplate(name: "T\($0)") }
        XCTAssertNotNil(DailyChallengeService.todayTemplate(from: templates))
    }

    // MARK: - currentStreak

    func test_currentStreak_noData_returnsZero() {
        XCTAssertEqual(DailyChallengeService.currentStreak, 0)
    }

    func test_currentStreak_afterYesterday_returnsCount() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        UserDefaults.standard.set(5, forKey: streakKey)
        UserDefaults.standard.set(yesterday, forKey: lastDateKey)
        XCTAssertEqual(DailyChallengeService.currentStreak, 5)
    }

    func test_currentStreak_afterTwoOrMoreDaysAgo_returnsZero() {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        UserDefaults.standard.set(10, forKey: streakKey)
        UserDefaults.standard.set(threeDaysAgo, forKey: lastDateKey)
        XCTAssertEqual(DailyChallengeService.currentStreak, 0)
    }

    func test_currentStreak_todayStillCounts() {
        UserDefaults.standard.set(3, forKey: streakKey)
        UserDefaults.standard.set(Date(), forKey: lastDateKey)
        XCTAssertEqual(DailyChallengeService.currentStreak, 3)
    }

    // MARK: - recordChallenge

    func test_recordChallenge_firstTime_setsStreakToOne() {
        DailyChallengeService.recordChallenge()
        XCTAssertEqual(DailyChallengeService.currentStreak, 1)
    }

    func test_recordChallenge_calledTwiceSameDay_noDoubleCount() {
        DailyChallengeService.recordChallenge()
        DailyChallengeService.recordChallenge()
        XCTAssertEqual(DailyChallengeService.currentStreak, 1)
    }

    func test_recordChallenge_afterYesterday_incrementsStreak() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        UserDefaults.standard.set(3, forKey: streakKey)
        UserDefaults.standard.set(yesterday, forKey: lastDateKey)
        DailyChallengeService.recordChallenge()
        XCTAssertEqual(DailyChallengeService.currentStreak, 4)
    }

    func test_recordChallenge_afterGap_resetsToOne() {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        UserDefaults.standard.set(10, forKey: streakKey)
        UserDefaults.standard.set(threeDaysAgo, forKey: lastDateKey)
        DailyChallengeService.recordChallenge()
        XCTAssertEqual(DailyChallengeService.currentStreak, 1)
    }
}
