import XCTest
@testable import Insomnia

/// The deadline timer is one-shot and runs on the real run loop, while the
/// manager reads its own clock. macOS steps the wall clock back by a few
/// milliseconds now and then, so the timer can run just before the clock
/// reads the deadline. The session must still end.
@MainActor
final class DeadlineTimerTests: XCTestCase {
    private func waitUntil(_ timeout: TimeInterval, _ condition: @MainActor () -> Bool) async -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    /// A live session loaded the way a launch loads it, by a clock that runs
    /// `lag` seconds behind the real one. macOS steps the clock back by 10 to
    /// 30 ms, and a timer runs up to 25 ms late, so a lag of 0.2 makes the
    /// timer run before the clock reads the deadline every time.
    ///
    /// session.json keeps whole seconds, so the deadline is the next whole
    /// second at least half a second away.
    private func assertTheSessionEnds(withTheClockBehindBy lag: TimeInterval) async throws {
        let h = Harness()
        defer { h.home.destroy() }
        let clock: @Sendable () -> Date = { Date().addingTimeInterval(-lag) }
        let endsAt = Date(timeIntervalSince1970: (Date().timeIntervalSince1970 + 1.5).rounded(.down))
        try h.store.saveSession(Session(startedAt: endsAt.addingTimeInterval(-60), endsAt: endsAt))
        var journal = RuntimeState()
        journal.sleepDisabledByUs = true
        try h.store.saveState(journal)
        h.guardFake.sleepDisabled = true

        let m = h.makeManager(clock: clock)
        await m.reconcile()
        XCTAssertTrue(m.isActive, "the session is live before its deadline (clock \(lag) s behind)")

        let ended = await waitUntil(5) { m.session == nil }
        XCTAssertTrue(ended, "the timer ended the session (clock \(lag) s behind)")
        XCTAssertFalse(h.guardFake.sleepDisabled, "sleep is back (clock \(lag) s behind)")
        XCTAssertEqual(h.guardFake.calls.last, "disablesleep 0")
        XCTAssertNil(try h.store.loadSession(), "session.json is gone (clock \(lag) s behind)")
    }

    func testTheTimerEndsTheSessionWhenTheClockAgreesWithIt() async throws {
        try await assertTheSessionEnds(withTheClockBehindBy: 0)
    }

    func testTheTimerEndsTheSessionWhenItRunsBeforeTheClockReachesTheDeadline() async throws {
        try await assertTheSessionEnds(withTheClockBehindBy: 0.2)
    }
}
