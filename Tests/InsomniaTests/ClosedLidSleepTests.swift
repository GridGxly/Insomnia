import XCTest
@testable import Insomnia

/// A floor-rule end with the lid closed asks macOS to sleep, after sleep is
/// restored and the recovery lock is free (spec section 6).
@MainActor
final class ClosedLidSleepTests: XCTestCase {
    var h: Harness!

    override func setUp() async throws { h = Harness() }
    override func tearDown() async throws { h.home.destroy() }

    /// A request made with sleep restored and the lock free.
    private static let asked = FakeClosedLidSleep.Request(sleepDisabled: false, lockHeld: false)
    /// A request macOS refused because sleep was still disabled.
    private static let refused = FakeClosedLidSleep.Request(sleepDisabled: true, lockHeld: false)

    /// A session started with the lid open, then the lid closed.
    private func sessionWithTheLidClosed(_ h: Harness, retryDelay: TimeInterval = 60) async -> SessionManager {
        let m = h.makeManager(retryDelay: retryDelay)
        await m.start(duration: 3600)
        XCTAssertNotNil(m.session)
        h.clamshell.closed = true
        return m
    }

    /// The end that a command's exit runs again runs on the main actor
    /// after the fake child exits; poll for its effect.
    private func waitUntil(_ what: String, _ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(5)
        while !condition(), Date() < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertTrue(condition(), what)
    }

    /// The case from the bag: a critical thermal state with the lid closed
    /// ends the session through the floor rules, and the Mac is asked to
    /// sleep after `disablesleep 0`, with the lock free.
    func testCriticalThermalStateWithTheLidClosedEndsTheSessionAndAsksForSleep() async throws {
        let m = await sessionWithTheLidClosed(h)
        let driver = FloorRuleDriver(manager: m, notifier: h.notifier)

        await driver.run(battery: .percent(80), isCharging: false, thermal: .critical, lidClosed: true)

        XCTAssertNil(m.session)
        XCTAssertEqual(h.guardFake.calls, ["disablesleep 1", "disablesleep 0"])
        XCTAssertEqual(h.lidSleep.requests, [Self.asked], "no sleep asked for, or asked before sleep was restored or the lock released")
        XCTAssertEqual(try h.store.loadState(), RuntimeState.clean)
    }

    func testBatteryEndsWithTheLidClosedAskForSleep() async {
        for reason in [EndReason.batteryFloor, .batteryUnreadable] {
            let h = Harness()
            defer { h.home.destroy() }
            let m = await sessionWithTheLidClosed(h)

            let outcome = await m.end(reason: reason)

            XCTAssertEqual(outcome, .restored, "\(reason)")
            XCTAssertEqual(h.lidSleep.requests, [Self.asked], "\(reason)")
        }
    }

    /// Ends the floor rules do not make leave a closed Mac to macOS, as
    /// before.
    func testOtherEndsWithTheLidClosedAskNothing() async {
        for reason in [EndReason.timer, .user, .quit] {
            let h = Harness()
            defer { h.home.destroy() }
            let m = await sessionWithTheLidClosed(h)

            let outcome = await m.end(reason: reason)

            XCTAssertEqual(outcome, .restored, "\(reason)")
            XCTAssertEqual(h.lidSleep.requests, [], "\(reason)")
        }
    }

    /// The user is at an open lid, or the lid cannot be read: no request.
    func testFloorEndWithTheLidOpenOrUnknownAsksNothing() async {
        for lid in [false, nil] as [Bool?] {
            let h = Harness()
            defer { h.home.destroy() }
            let m = h.makeManager()
            await m.start(duration: 3600)
            h.clamshell.closed = lid

            let outcome = await m.end(reason: .thermalCritical)

            XCTAssertEqual(outcome, .restored)
            XCTAssertEqual(h.lidSleep.requests, [], "lid \(String(describing: lid))")
        }
    }

    /// macOS keeps this closed Mac awake (an external display in clamshell
    /// mode), or its answer cannot be read: no request, so a Mac in use on
    /// an external display is never put to sleep.
    func testFloorEndWhenMacOSKeepsAClosedMacAwakeAsksNothing() async {
        for causesSleep in [false, nil] as [Bool?] {
            let h = Harness()
            defer { h.home.destroy() }
            let m = await sessionWithTheLidClosed(h)
            h.lidSleep.causesSleep = causesSleep

            let outcome = await m.end(reason: .thermalCritical)

            XCTAssertEqual(outcome, .restored)
            XCTAssertEqual(h.lidSleep.requests, [], "causes sleep \(String(describing: causesSleep))")
        }
    }

    /// An end refused for a busy lock changed nothing and asks nothing;
    /// the end that runs once the lock is free asks.
    func testEndRefusedForTheLockAsksWhenItRunsAgain() async throws {
        let m = await sessionWithTheLidClosed(h)
        let other = try XCTUnwrap(try RecoveryLock(url: h.home.paths.recoveryLock).tryAcquire())

        let refused = await m.end(reason: .thermalCritical)

        XCTAssertEqual(refused, .locked)
        XCTAssertEqual(h.lidSleep.requests, [], "asked for sleep with sleep still disabled")
        other.release()

        let again = await m.end(reason: .thermalCritical)

        XCTAssertEqual(again, .restored)
        XCTAssertEqual(h.lidSleep.requests, [Self.asked])
    }

    /// An end stopped at a live `disablesleep 0` asks nothing while the
    /// command runs; the end its exit runs again asks, after the lock the
    /// command held is free.
    func testEndStoppedAtALiveCommandAsksOnceTheCommandExits() async throws {
        let m = await sessionWithTheLidClosed(h)
        h.guardFake.stillRunning = ["disablesleep 0"]

        let outcome = await m.end(reason: .thermalCritical)

        XCTAssertEqual(outcome, .privilegedCommandRunning(pid: 4242))
        XCTAssertEqual(h.lidSleep.requests, [], "asked for sleep beside a live sudo pmset")

        h.guardFake.stillRunning = []
        h.guardFake.exitStuckCommands()
        await waitUntil("pending end never retried") { m.pendingEnd == nil }

        XCTAssertEqual(h.lidSleep.requests, [Self.asked])
        XCTAssertEqual(try h.store.loadState(), RuntimeState.clean)
    }

    /// A failed `disablesleep 0` leaves sleep disabled, and macOS refuses
    /// the request. It is asked again until the recovery agent restores
    /// sleep, then once more, and no further.
    func testRefusedRequestAsksAgainOnceSleepIsRestored() async throws {
        let m = await sessionWithTheLidClosed(h, retryDelay: 0.05)
        h.guardFake.throwOn = ["disablesleep 0"]

        let outcome = await m.end(reason: .thermalCritical)

        XCTAssertEqual(outcome, .incomplete(agentArmed: true))
        XCTAssertEqual(h.lidSleep.requests, [Self.refused])
        XCTAssertEqual(try h.store.loadState()?.sleepDisabledByUs, true)

        h.guardFake.sleepDisabled = false
        await waitUntil("not asked again once sleep was restored") { h.lidSleep.requests.last == Self.asked }
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(h.lidSleep.requests.filter { $0 != Self.refused }, [Self.asked])
    }

    /// Once the lid opens, a refused request is not asked again.
    func testOpeningTheLidStopsAskingAgain() async throws {
        let m = await sessionWithTheLidClosed(h, retryDelay: 0.05)
        h.guardFake.throwOn = ["disablesleep 0"]
        _ = await m.end(reason: .thermalCritical)

        h.clamshell.closed = false
        h.guardFake.sleepDisabled = false
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertEqual(h.lidSleep.requests, [Self.refused], "asked an open Mac to sleep")
    }

    /// A start drops a refused request before it writes anything, so no
    /// sleep lands between its writes and its `disablesleep 1`.
    func testStartStopsAskingAgain() async throws {
        let m = await sessionWithTheLidClosed(h, retryDelay: 0.05)
        h.guardFake.throwOn = ["disablesleep 0"]
        _ = await m.end(reason: .thermalCritical)
        h.guardFake.throwOn = []
        h.guardFake.sleepDisabled = false
        let gate = AsyncGate()
        h.guardFake.sleepGate = gate

        let start = Task { await m.start(duration: 3600) }
        await gate.waitUntilStarted()
        try await Task.sleep(for: .milliseconds(300))
        await gate.open()
        await start.value

        XCTAssertNotNil(m.session)
        XCTAssertEqual(h.lidSleep.requests, [Self.refused], "asked for sleep inside a start")
    }

    /// A session.json that cannot be removed keeps the end pending, but
    /// sleep is restored, so the closed Mac is asked to sleep.
    func testEndThatCannotRemoveTheSessionFileStillAsks() async throws {
        let m = await sessionWithTheLidClosed(h)
        let file = h.home.paths.sessionFile.path
        try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: file)
        defer { try? FileManager.default.setAttributes([.immutable: false], ofItemAtPath: file) }

        let outcome = await m.end(reason: .batteryFloor)

        XCTAssertEqual(outcome, .sessionRetained)
        XCTAssertEqual(m.pendingEnd, .batteryFloor)
        XCTAssertFalse(h.guardFake.sleepDisabled)
        XCTAssertEqual(h.lidSleep.requests, [Self.asked])
    }

    /// A quit that arrives while a heat end restores sleep queues behind
    /// it. The heat end asks once, with sleep restored; the quit asks
    /// nothing.
    func testQuitDuringAFloorEndAsksOnce() async throws {
        let m = await sessionWithTheLidClosed(h)
        let gate = AsyncGate()
        h.guardFake.restoreGate = gate

        let end = Task { await m.end(reason: .thermalCritical) }
        await gate.waitUntilStarted()
        let quit = await runUntilSuspended { await m.end(reason: .quit) }
        XCTAssertEqual(h.lidSleep.requests, [], "asked for sleep while sleep was still disabled")
        await gate.open()
        let ended = await end.value
        let quitted = await quit.value

        XCTAssertEqual(ended, .restored)
        XCTAssertEqual(quitted, .restored)
        XCTAssertEqual(h.guardFake.calls, ["disablesleep 1", "disablesleep 0"])
        XCTAssertEqual(h.lidSleep.requests, [Self.asked])
    }
}
