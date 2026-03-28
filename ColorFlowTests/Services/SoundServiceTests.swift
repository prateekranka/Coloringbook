import XCTest
@testable import ColorFlow

final class SoundServiceTests: XCTestCase {

    private let enabledKey = "ambientSoundEnabled"
    private var savedValue: Bool = false
    private var hadSavedValue: Bool = false

    override func setUp() {
        super.setUp()
        hadSavedValue = UserDefaults.standard.object(forKey: enabledKey) != nil
        savedValue = UserDefaults.standard.bool(forKey: enabledKey)
        UserDefaults.standard.removeObject(forKey: enabledKey)
    }

    override func tearDown() {
        if hadSavedValue {
            UserDefaults.standard.set(savedValue, forKey: enabledKey)
        } else {
            UserDefaults.standard.removeObject(forKey: enabledKey)
        }
        super.tearDown()
    }

    func test_isEnabled_defaultIsFalse() {
        // With no stored value, isEnabled should be false
        XCTAssertFalse(SoundService.shared.isEnabled)
    }

    func test_isEnabled_setTrue_persists() {
        SoundService.shared.isEnabled = true
        XCTAssertTrue(SoundService.shared.isEnabled)
        // Clean up
        SoundService.shared.isEnabled = false
    }

    func test_playFillPop_whenDisabled_doesNotCrash() {
        SoundService.shared.isEnabled = false
        XCTAssertNoThrow(SoundService.shared.playFillPop())
    }

    func test_playSaveChime_whenDisabled_doesNotCrash() {
        SoundService.shared.isEnabled = false
        XCTAssertNoThrow(SoundService.shared.playSaveChime())
    }
}
