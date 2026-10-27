import AppKit
import XCTest
@testable import Insomnia

/// A one-click start asks for the default length without the pills. Fakes
/// stand in for the recovery agent and pmset; no test changes real power
/// settings.
final class OneClickStartTests: XCTestCase {
    /// A refused start reopens the pills, and with them the key-catcher
    /// panel. Tests that end there must not leave it up for the next test.
    override func tearDown() {
        MainActor.assumeIsolated {
            for panel in NSApp.windows.compactMap({ $0 as? KeyCatcherPanel }) where panel.isVisible {
                panel.orderOut(nil)
            }
        }
        super.tearDown()
    }

    @MainActor
    private struct Rig {
        let h: Harness
        let manager: SessionManager
        let controller: StatusItemController

        init(mode: Config.MenuBarMode = .pills) {
            _ = NSApplication.shared
            h = Harness()
            manager = h.makeManager()
            manager.config.menuBarMode = mode
            let clock = h.clock
            controller = StatusItemController(
                manager: manager, status: PlaceholderStatus(), showSettings: {},
                clock: { clock.now }, appFocus: UIStatusTests.quietFocus
            )
        }

        var model: MenuBarModel { controller.model }
    }

    @MainActor
    private func waitUntil(_ timeout: TimeInterval = 2, _ condition: @MainActor () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    // MARK: Lengths no session can hold

    /// A hand-edited config can hold a default length no Int can. The
    /// click asks the manager for nothing and opens the pills, where
    /// another length can be typed. Asked for, the length traps in the
    /// manager after sleep is already off; the child process reports that.
    @MainActor
    func testAClickDoesNotAskForADefaultLengthTooLargeForAnInt() async throws {
        try await TrapProbe.run(name) {
            await assertTheClickOpensThePills(defaultPreset: 1e300)
        }
    }

    @MainActor
    func testAClickDoesNotAskForANegativeDefaultLengthTooLargeForAnInt() async throws {
        try await TrapProbe.run(name) {
            await assertTheClickOpensThePills(defaultPreset: -1e300)
        }
    }

    @MainActor
    private func assertTheClickOpensThePills(
        defaultPreset: TimeInterval,
        file: StaticString = #filePath, line: UInt = #line
    ) async {
        let rig = Rig()
        defer { rig.h.home.destroy() }
        rig.manager.config.defaultPreset = defaultPreset
        rig.controller.iconTapped()
        XCTAssertEqual(rig.model.phase, .entering(.start), file: file, line: line)
        XCTAssertNil(rig.model.pendingCountdown, file: file, line: line)
        // Time for a request that was made after all to reach the manager.
        _ = await waitUntil(0.5) { rig.h.backstop.arms > 0 }
        XCTAssertFalse(rig.manager.isActive, file: file, line: line)
        XCTAssertEqual(rig.h.backstop.arms, 0, file: file, line: line)
        XCTAssertTrue(rig.h.guardFake.calls.isEmpty, file: file, line: line)
    }

    /// A refused one-click start is retried at the length it asked for.
    /// The pills show 30 days at most, so 30 days and 1 minute (with the
    /// longest session raised to allow it) must not come back as 30 days.
    @MainActor
    func testARefusedClickIsRetriedAtTheLengthItAskedFor() async throws {
        let rig = Rig()
        defer { rig.h.home.destroy() }
        let length: TimeInterval = 30 * 86_400 + 60
        rig.manager.config.maxDuration = 60 * 86_400
        rig.manager.config.defaultPreset = length
        rig.h.backstop.failArm = true
        rig.controller.iconTapped()
        var ok = await waitUntil { rig.model.phase == .entering(.start) }
        XCTAssertTrue(ok)
        XCTAssertEqual(rig.model.input, DurationInput(days: 30))

        rig.h.backstop.failArm = false
        // A click on the open pills submits them, as on the base.
        rig.controller.iconTapped()
        ok = await waitUntil { rig.manager.isActive }
        XCTAssertTrue(ok)
        let session = try XCTUnwrap(rig.manager.session)
        XCTAssertEqual(session.endsAt.timeIntervalSince(session.startedAt), length)
        await rig.manager.end(reason: .user)
    }
}
