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

    // MARK: Only while a session holds sleep

    /// A session that ended, or a start that failed, leaves nothing to
    /// check: not even a read.
    func testNothingIsReadAfterAnEndOrAFailedStart() async {
        let m = await started()
        _ = await m.end(reason: .user)
        XCTAssertFalse(m.isActive)
        let afterEnd = h.guardFake.calls.count
        await m.checkSleepHeld()
        XCTAssertEqual(callsAfter(afterEnd), [])

        h.guardFake.throwOn = ["disablesleep 1"]
        await m.start(duration: 3600)
        XCTAssertFalse(m.isActive)
        h.guardFake.throwOn = []
        let afterFailure = h.guardFake.calls.count
        await m.checkSleepHeld()
        XCTAssertEqual(callsAfter(afterFailure), [])
    }

    /// An end that could not take the lock is still on its way (it is
    /// retried): the session is still in memory and the journal still
    /// claims sleep, but the check must not set it again under that end,
    /// nor under a quit.
    func testAnEndWaitingForItsRetrySetsNothing() async throws {
        for reason in [EndReason.user, .quit] {
            let m = await started()
            let held = try XCTUnwrap(try RecoveryLock(url: h.home.paths.recoveryLock).tryAcquire())
            let outcome = await m.end(reason: reason)
            held.release()
            XCTAssertEqual(outcome, .locked, "\(reason)")
            XCTAssertTrue(m.isActive, "\(reason): the end is pending")
            h.guardFake.sleepDisabled = false
            let before = h.guardFake.calls.count
            await m.checkSleepHeld()
            XCTAssertEqual(callsAfter(before), [], "\(reason)")
            XCTAssertFalse(h.guardFake.sleepDisabled, "\(reason)")
            _ = await m.end(reason: .user)
        }
    }

    // MARK: Never against an end

    /// A check that read 0 just before an end was asked for runs its
    /// transaction after the end: it finds nothing to hold, and the end's
    /// disablesleep 0 is the last word.
    func testACheckInFlightWhenAnEndArrivesSetsNothing() async throws {
        let m = await started()
        h.guardFake.sleepDisabled = false
        let gate = AsyncGate()
        h.guardFake.readGate = gate
        let check = await runUntilSuspended { await m.checkSleepHeld() }
        await gate.waitUntilStarted()
        let end = Task { @MainActor in await m.end(reason: .user) }
        await settleQueuedRequests()
        await gate.open()
        _ = await end.value
        await check.value
        h.guardFake.readGate = nil
        XCTAssertFalse(m.isActive)
        let restore = try XCTUnwrap(h.guardFake.calls.lastIndex(of: "disablesleep 0"))
        XCTAssertFalse(h.guardFake.calls[restore...].contains("disablesleep 1"), "\(h.guardFake.calls)")
        XCTAssertFalse(h.guardFake.sleepDisabled)
    }

    /// An end whose restore was refused keeps the journal entry for its
    /// retry; the session is gone, so the check leaves the bit alone.
    func testARefusedRestoreIsNotUndoneByTheCheck() async {
        let m = await started()
        h.guardFake.throwOn = ["disablesleep 0"]
        _ = await m.end(reason: .user)
        XCTAssertFalse(m.isActive)
        h.guardFake.throwOn = []
        h.guardFake.sleepDisabled = false
        let before = h.guardFake.calls.count
        await m.checkSleepHeld()
        XCTAssertEqual(callsAfter(before), [])
    }

    /// The session's end time has passed but its deadline timer has not
    /// run yet (a late timer, a busy main thread): the backstop may already
    /// have restored sleep, and the check must not take it back.
    func testASessionPastItsEndIsNotHeldAgain() async {
        let m = await started()
        h.clock.advance(3601)
        h.guardFake.sleepDisabled = false
        let before = h.guardFake.calls.count
        await m.checkSleepHeld()
        XCTAssertEqual(callsAfter(before), [])
        XCTAssertFalse(h.guardFake.sleepDisabled)
    }

    /// The backstop restored sleep and removed session.json while this
    /// process still holds the session in memory: whether or not its
    /// journal write landed, the check leaves the bit at 0.
    func testABackstopRestoreIsNotUndoneByTheCheck() async throws {
        for journalCleared in [true, false] {
            let m = await started()
            h.guardFake.sleepDisabled = false
            try h.store.deleteSession()
            if journalCleared { try h.store.saveState(.clean) }
            let before = h.guardFake.calls.count
            await m.checkSleepHeld()
            XCTAssertFalse(callsAfter(before).contains("disablesleep 1"), "journal cleared: \(journalCleared)")
            XCTAssertFalse(h.guardFake.sleepDisabled, "journal cleared: \(journalCleared)")
            _ = await m.end(reason: .user)
        }
    }

    // MARK: The journal first

    /// When the set runs, the journal on disk already says Insomnia
    /// disabled sleep, so a crash right after it leaves the backstop an
    /// entry to undo.
    func testTheJournalClaimsSleepBeforeTheSetRuns() async throws {
        let m = await started()
        h.guardFake.sleepDisabled = false
        let gate = AsyncGate()
        h.guardFake.sleepGate = gate
        let check = await runUntilSuspended { await m.checkSleepHeld() }
        await gate.waitUntilStarted()
        XCTAssertEqual(try h.store.loadState()?.sleepDisabledByUs, true)
        await gate.open()
        await check.value
        h.guardFake.sleepGate = nil
        XCTAssertTrue(h.guardFake.sleepDisabled)
    }

    /// A journal that cannot be written stops the set: nothing would be
    /// left for the backstop to undo it by.
    func testAJournalThatCannotBeWrittenStopsTheSet() async throws {
        let m = await started()
        h.guardFake.sleepDisabled = false
        let dir = h.home.paths.appSupport.path
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: dir)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir) }
        let before = h.guardFake.calls.count
        await m.checkSleepHeld()
        XCTAssertFalse(callsAfter(before).contains("disablesleep 1"))
        XCTAssertTrue(m.sleepNotHeld)
    }
}
