import XCTest
@testable import Insomnia

/// The live check during a session (`SessionManager.checkSleepHeld`):
/// SleepDisabled read back from pmset, set again when something turned it
/// back to 0, and a warning only when that fails.
@MainActor
final class SleepCheckTests: XCTestCase {
    var h: Harness!

    override func setUp() async throws {
        h = Harness()
    }

    override func tearDown() async throws {
        h.home.destroy()
    }

    private func started() async -> SessionManager {
        let m = h.makeManager()
        await m.start(duration: 3600)
        XCTAssertTrue(m.isActive)
        XCTAssertTrue(h.guardFake.sleepDisabled)
        return m
    }

    private func callsAfter(_ count: Int) -> [String] {
        Array(h.guardFake.calls.dropFirst(count))
    }

    private func sleepLines(_ m: SessionManager) -> [StatusMenu.Item] {
        StatusItemController.statusItems(manager: m, status: RecordingStatusSource())
            .filter { $0.title.hasPrefix("Sleep") }
    }

    func testNoSessionReadsNothing() async {
        let m = h.makeManager()
        await m.checkSleepHeld()
        XCTAssertEqual(h.guardFake.calls, [])
    }

    /// The bit still set: one read, no lock, nothing set, no line.
    func testHeldSleepIsOnlyRead() async {
        let m = await started()
        let before = h.guardFake.calls.count
        await m.checkSleepHeld()
        XCTAssertEqual(callsAfter(before), ["pmset -g"])
        XCTAssertFalse(m.sleepNotHeld)
        XCTAssertEqual(sleepLines(m), [])
    }

    /// Turned back to 0 mid-session: read again under the lock and set
    /// again, quietly.
    func testSleepTurnedBackOnIsSetAgain() async {
        let m = await started()
        h.guardFake.sleepDisabled = false
        let before = h.guardFake.calls.count
        await m.checkSleepHeld()
        XCTAssertEqual(callsAfter(before), ["pmset -g", "pmset -g", "disablesleep 1"])
        XCTAssertTrue(h.guardFake.sleepDisabled)
        XCTAssertEqual(h.guardFake.unlockedPrivilegedCalls, [])
        XCTAssertFalse(m.sleepNotHeld)
        XCTAssertNil(m.lastError)
        XCTAssertFalse(h.notifier.posts.map(\.title).contains(SessionManager.sleepNotHeldTitle))
        XCTAssertEqual(sleepLines(m), [])
    }

    /// A set that fails shows "Sleep is not held" and posts once; the next
    /// check tries again, and a set that holds takes the line down.
    func testAFailedSetWarnsOnceAndIsRetried() async {
        let m = await started()
        h.guardFake.sleepDisabled = false
        h.guardFake.throwOn = ["disablesleep 1"]
        await m.checkSleepHeld()
        XCTAssertTrue(m.sleepNotHeld)
        XCTAssertTrue(m.isActive, "the session goes on")
        XCTAssertEqual(sleepLines(m), [
            StatusMenu.Item(title: "Sleep is not held \u{2014} this session is not keeping the Mac awake", kind: .warning),
        ])

        await m.checkSleepHeld()
        XCTAssertEqual(h.notifier.posts.map(\.title).filter { $0 == SessionManager.sleepNotHeldTitle }.count, 1)

        h.guardFake.throwOn = []
        await m.checkSleepHeld()
        XCTAssertTrue(h.guardFake.sleepDisabled)
        XCTAssertFalse(m.sleepNotHeld)
        XCTAssertEqual(sleepLines(m), [])
    }

    /// The line belongs to the session: an end takes it down.
    func testAnEndClearsTheWarning() async {
        let m = await started()
        h.guardFake.sleepDisabled = false
        h.guardFake.throwOn = ["disablesleep 1"]
        await m.checkSleepHeld()
        XCTAssertTrue(m.sleepNotHeld)
        _ = await m.end(reason: .user)
        XCTAssertFalse(m.sleepNotHeld)
    }
}
