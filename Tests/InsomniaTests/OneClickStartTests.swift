import AppKit
import XCTest
@testable import Insomnia

/// "Start a session with one click" in Settings: with it on, a click with
/// no session starts the default length in Pills, Compact and Popover.
/// Fakes stand in for the recovery agent and pmset; no test changes real
/// power settings.
final class OneClickStartTests: XCTestCase {
    /// A refused start reopens the pills, and with them the key-catcher
    /// panel; others open the popover or the Compact panel. Tests that end
    /// there must not leave them up for the next test.
    override func tearDown() {
        MainActor.assumeIsolated {
            // NSApplication.shared, not NSApp: in a trap probe's parent no
            // test body made the application.
            for window in NSApplication.shared.windows where window.isVisible
                && (window is KeyCatcherPanel || window.className.contains("Popover")) {
                window.orderOut(nil)
            }
        }
        super.tearDown()
    }

    @MainActor
    private struct Rig {
        let h: Harness
        let manager: SessionManager
        let controller: StatusItemController

        init(_ mode: Config.MenuBarMode = .pills, oneClick: Bool = true) {
            _ = NSApplication.shared
            h = Harness()
            manager = h.makeManager()
            manager.config.menuBarMode = mode
            manager.config.oneClickStart = oneClick
            let clock = h.clock
            controller = StatusItemController(
                manager: manager, status: PlaceholderStatus(), showSettings: {},
                clock: { clock.now }, appFocus: UIStatusTests.quietFocus
            )
        }

        var model: MenuBarModel { controller.model }
        var compact: CompactMenuModel { controller.compactModel }

        /// A click the way the style takes it: Popover's button reads the
        /// event, the other styles' eye reads the keys held.
        func click(_ type: NSEvent.EventType = .leftMouseDown, modifiers: NSEvent.ModifierFlags = []) {
            if manager.config.menuBarMode == .popover {
                let event = NSEvent.mouseEvent(
                    with: type, location: .zero, modifierFlags: modifiers,
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: 0,
                    context: nil, eventNumber: 1, clickCount: 1, pressure: 1
                )
                controller.popoverClicked(event)
            } else {
                controller.iconTapped(modifiers: modifiers)
            }
        }

        /// Whether the click opened what the style opens with the switch
        /// off: the start pills, the Compact panel or the popover.
        var controlsAreOpen: Bool {
            switch manager.config.menuBarMode {
            case .pills: model.phase.isEntering
            case .compact: compact.isPresented
            case .popover: model.popoverShown
            case .minimal: false
            }
        }

        func closeControls() {
            controller.collapse(returnFocus: false)
            controller.closeCompactDropdown(returnFocus: false)
            controller.closePopover()
        }

        func tearDown() {
            closeControls()
            h.home.destroy()
        }
    }

    private static let styles: [Config.MenuBarMode] = [.pills, .compact, .popover]

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
        defer { rig.tearDown() }
        rig.manager.config.defaultPreset = defaultPreset
        rig.click()
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
        defer { rig.tearDown() }
        let length: TimeInterval = 30 * 86_400 + 60
        rig.manager.config.maxDuration = 60 * 86_400
        rig.manager.config.defaultPreset = length
        rig.h.backstop.failArm = true
        rig.click()
        var ok = await waitUntil { rig.model.phase == .entering(.start) }
        XCTAssertTrue(ok)
        XCTAssertEqual(rig.model.input, DurationInput(days: 30))

        rig.h.backstop.failArm = false
        // A click on the open pills submits them, as with the switch off.
        rig.click()
        ok = await waitUntil { rig.manager.isActive }
        XCTAssertTrue(ok)
        let session = try XCTUnwrap(rig.manager.session)
        XCTAssertEqual(session.endsAt.timeIntervalSince(session.startedAt), length)
        await rig.manager.end(reason: .user)
    }

    // MARK: The switch

    /// Off, a click opens what it always has. On, a plain click with no
    /// session starts the default length and opens nothing.
    @MainActor
    func testTheSwitchDecidesWhetherAClickStartsTheDefaultLength() async throws {
        for style in Self.styles {
            let off = Rig(style, oneClick: false)
            off.click()
            XCTAssertTrue(off.controlsAreOpen, "\(style), switch off")
            await settleQueuedRequests()
            XCTAssertEqual(off.h.backstop.arms, 0, "\(style), switch off")
            XCTAssertFalse(off.manager.isActive, "\(style), switch off")
            off.tearDown()

            let on = Rig(style)
            on.click()
            XCTAssertFalse(on.controlsAreOpen, "\(style), switch on")
            XCTAssertEqual(on.model.phase, .starting, "\(style), switch on")
            let started = await waitUntil { on.manager.isActive }
            XCTAssertTrue(started, "\(style), switch on")
            let session = try XCTUnwrap(on.manager.session, "\(style)")
            XCTAssertEqual(session.endsAt.timeIntervalSince(session.startedAt), on.manager.config.defaultPreset, "\(style)")
            XCTAssertFalse(on.controlsAreOpen, "\(style), switch on")
            await on.manager.end(reason: .user)
            on.tearDown()
        }
    }

    /// With the switch on, Option-click opens the controls, so any other
    /// length can still be typed or picked.
    @MainActor
    func testOptionClickOpensTheControlsWithTheSwitchOn() async {
        for style in Self.styles {
            let rig = Rig(style)
            rig.click(modifiers: .option)
            XCTAssertTrue(rig.controlsAreOpen, "\(style)")
            await settleQueuedRequests()
            XCTAssertEqual(rig.h.backstop.arms, 0, "\(style)")
            rig.tearDown()
        }
    }

    /// Popover's button takes right clicks and Control-clicks as well, and
    /// they open the popover with the switch on, as they do with it off.
    @MainActor
    func testRightClickAndControlClickOpenThePopoverWithTheSwitchOn() async {
        for (type, modifiers) in [(NSEvent.EventType.rightMouseDown, NSEvent.ModifierFlags()), (.leftMouseDown, .control)] {
            let rig = Rig(.popover)
            rig.click(type, modifiers: modifiers)
            XCTAssertTrue(rig.model.popoverShown, "\(type) \(modifiers)")
            await settleQueuedRequests()
            XCTAssertEqual(rig.h.backstop.arms, 0, "\(type) \(modifiers)")
            rig.tearDown()
        }
    }

    /// A click while a session runs does what it does with the switch off
    /// (the pills open to add time, the panel or the popover opens). No
    /// click ends a session or starts another.
    @MainActor
    func testAClickDuringASessionNeverEndsItWithTheSwitchOn() async {
        for style in Self.styles {
            let rig = Rig(style)
            await rig.manager.start(duration: 3600)
            let session = rig.manager.session
            let running = await waitUntil { rig.model.phase == .running }
            XCTAssertTrue(running, "\(style)")
            rig.click()
            XCTAssertTrue(rig.controlsAreOpen, "\(style)")
            if style == .pills {
                XCTAssertEqual(rig.model.phase, .entering(.extend))
            }
            await settleQueuedRequests()
            XCTAssertEqual(rig.manager.session, session, "\(style)")
            XCTAssertEqual(rig.h.backstop.arms, 1, "\(style)")
            await rig.manager.end(reason: .user)
            rig.tearDown()
        }
    }

    /// Clicks while the first start waits on the recovery agent start
    /// nothing more: the manager is asked once.
    @MainActor
    func testClicksDuringAPendingStartAskForNothingMore() async {
        for style in Self.styles {
            let rig = Rig(style)
            let gate = AsyncGate()
            rig.h.backstop.armGate = gate
            rig.click()
            await gate.waitUntilStarted()
            rig.click()
            rig.click()
            await gate.open()
            let started = await waitUntil { rig.manager.isActive && !rig.compact.isBusy }
            XCTAssertTrue(started, "\(style)")
            await settleQueuedRequests()
            XCTAssertEqual(rig.h.backstop.arms, 1, "\(style)")
            await rig.manager.end(reason: .user)
            rig.tearDown()
        }
    }

    /// The session is gone from the manager as soon as an end begins, but
    /// sleep is not restored yet. A click then must not start a session
    /// over the end; it does what it does with the switch off.
    @MainActor
    func testAClickWhileAnEndRestoresStartsNothing() async {
        for style in Self.styles {
            let rig = Rig(style)
            await rig.manager.start(duration: 3600)
            let gate = AsyncGate()
            rig.h.guardFake.restoreGate = gate
            let end = Task { await rig.manager.end(reason: .user) }
            await gate.waitUntilStarted()
            XCTAssertFalse(rig.manager.isActive, "\(style)")
            _ = await waitUntil { rig.model.phase == .idle }
            rig.click()
            await settleQueuedRequests()
            XCTAssertNotEqual(rig.model.phase, .starting, "\(style)")
            await gate.open()
            _ = await end.value
            await settleQueuedRequests()
            XCTAssertFalse(rig.manager.isActive, "\(style)")
            XCTAssertEqual(rig.h.backstop.arms, 1, "\(style)")
            rig.tearDown()
        }
    }

    // MARK: A refused start

    /// A refused one-click start says why without another click, the way
    /// each style shows a refusal with the switch off: Pills reopens the
    /// pills with its label, Compact opens the panel and Popover the
    /// popover, each with the reason.
    @MainActor
    func testARefusedClickShowsWhyWithoutAnotherClick() async {
        for style in Self.styles {
            let rig = Rig(style)
            rig.h.backstop.failArm = true
            rig.click()
            let refused = await waitUntil { rig.model.phase != .starting && !rig.compact.isBusy }
            XCTAssertTrue(refused, "\(style)")
            XCTAssertFalse(rig.manager.isActive, "\(style)")
            XCTAssertTrue(rig.controlsAreOpen, "\(style)")
            switch style {
            case .pills:
                XCTAssertEqual(rig.model.startError, MenuBarModel.startFailedText)
                XCTAssertEqual(rig.model.input.total, rig.manager.config.defaultPreset)
            case .compact:
                XCTAssertNotNil(rig.manager.lastError ?? rig.compact.error)
            case .popover:
                XCTAssertEqual(rig.model.startError, StatusItemController.startErrorText(rig.manager.lastError))
            case .minimal:
                break
            }
            rig.tearDown()
        }
    }

    /// The popover a refused one-click start opens shows the time buttons
    /// and the reason, with nothing in the fields. A Custom draft left from
    /// an earlier opening, or a time refused then, came back instead, and
    /// Return started that rather than the default length.
    @MainActor
    func testARefusedClickOpensThePopoverWithNoOlderTime() async {
        for refusedBefore in [false, true] {
            let rig = Rig(.popover)
            rig.h.backstop.failArm = true
            rig.controller.openPopover()
            rig.model.customShown = true
            rig.model.texts[.hours] = "2"
            if refusedBefore {
                rig.controller.popoverCommit()
                await rig.controller.sessionRequest?.value
                XCTAssertNotNil(rig.model.startError)
                XCTAssertEqual(rig.model.texts[.hours], "2", "a refused time stays for its retry")
            }
            rig.controller.closePopover()
            XCTAssertFalse(rig.model.popoverShown)

            rig.click()
            XCTAssertEqual(rig.model.phase, .starting, "refused before: \(refusedBefore)")
            await rig.controller.sessionRequest?.value
            XCTAssertFalse(rig.manager.isActive)
            XCTAssertTrue(rig.model.popoverShown, "refused before: \(refusedBefore)")
            XCTAssertEqual(rig.model.startError, StatusItemController.startErrorText(rig.manager.lastError))
            XCTAssertEqual(rig.model.texts, [:], "refused before: \(refusedBefore)")
            XCTAssertFalse(rig.model.customShown, "refused before: \(refusedBefore)")
            rig.tearDown()
        }
    }

    /// The popover opened during a one-click start keeps what is typed in
    /// it when the start is refused: only a closed popover's fields are
    /// cleared.
    @MainActor
    func testARefusedClickKeepsWhatIsTypedInThePopoverOpenedMeanwhile() async {
        let rig = Rig(.popover)
        let gate = AsyncGate()
        rig.h.backstop.armGate = gate
        rig.h.backstop.failArm = true
        rig.click()
        await gate.waitUntilStarted()
        rig.click()
        XCTAssertTrue(rig.model.popoverShown, "a click during the start opens the popover")
        rig.model.customShown = true
        rig.model.texts[.hours] = "3"

        await gate.open()
        await rig.controller.sessionRequest?.value
        XCTAssertFalse(rig.manager.isActive)
        XCTAssertTrue(rig.model.popoverShown)
        XCTAssertNotNil(rig.model.startError)
        XCTAssertEqual(rig.model.texts, [.hours: "3"])
        XCTAssertTrue(rig.model.customShown)
        rig.tearDown()
    }

    /// The retry after a refused one-click start asks for what the click
    /// asked for, to the second, not a time typed in an earlier opening.
    /// Pills and Compact reopen on the refusal and Return retries; the
    /// Compact panel keeps a draft across closes, so the 2 hours typed
    /// there came back and Return started them. The popover opens on the
    /// time buttons, and its Return does nothing until a time is typed.
    /// The default changes before Return, so a retry that fell back to the
    /// default (as it does with an empty entry) asks for the wrong length.
    @MainActor
    func testARefusedClicksRetryIsNotAnOlderDraft() async throws {
        let length: TimeInterval = 90 * 60 + 30
        for style in Self.styles {
            let rig = Rig(style)
            rig.manager.config.defaultPreset = length
            rig.click(modifiers: .option)
            XCTAssertTrue(rig.controlsAreOpen, "\(style)")
            switch style {
            case .pills: rig.model.input = DurationInput(hours: 2)
            case .compact: rig.compact.entry.input = DurationInput(hours: 2)
            default:
                rig.model.customShown = true
                rig.model.texts[.hours] = "2"
            }
            rig.closeControls()
            // The pills fold before they are idle; a click during the fold
            // brings them back instead of starting.
            let closed = await waitUntil { !rig.controlsAreOpen && rig.model.phase == .idle }
            XCTAssertTrue(closed, "\(style)")

            rig.h.backstop.failArm = true
            rig.click()
            XCTAssertEqual(rig.model.phase, .starting, "\(style): the click asks for the default length")
            await rig.controller.sessionRequest?.value
            XCTAssertFalse(rig.manager.isActive, "\(style)")
            XCTAssertTrue(rig.controlsAreOpen, "\(style)")
            // What the reopened controls show and keep: the click's length,
            // with its exact seconds beside the whole minutes shown.
            let shown = DurationInput(hours: 1, minutes: 30)
            let kept = MenuBarModel.KeptRequest(input: shown, seconds: length)
            switch style {
            case .pills:
                XCTAssertEqual(rig.model.input, shown)
                XCTAssertEqual(rig.model.keptRequest, kept)
            case .compact:
                XCTAssertEqual(rig.compact.entry.input, shown)
                XCTAssertEqual(rig.compact.entry.keptRequest, kept)
            default:
                XCTAssertEqual(rig.model.texts, [:])
                XCTAssertFalse(rig.model.customShown)
            }

            rig.manager.config.defaultPreset = 3600
            rig.h.backstop.failArm = false
            switch style {
            case .pills: rig.controller.commit()
            case .compact: rig.controller.compactSubmit()
            default:
                // Return as the popover's fields take it.
                if rig.model.popoverInput.isValid { rig.controller.popoverCommit() }
            }
            await rig.controller.sessionRequest?.value
            if style == .popover {
                XCTAssertFalse(rig.manager.isActive, "Return asks for nothing with the fields empty")
            } else {
                let session = try XCTUnwrap(rig.manager.session, "\(style)")
                XCTAssertEqual(session.endsAt.timeIntervalSince(session.startedAt), length, "\(style)")
                await rig.manager.end(reason: .user)
            }
            rig.tearDown()
        }
    }

    /// A one-click start that goes through with a warning has spent the
    /// click's length. Here App Nap's preference write for an agent app
    /// fails: the session starts and the manager's error says so. The
    /// Compact entry the click filled for a retry is emptied, and the
    /// panel shows the running session with the warning. Before, the panel
    /// opened on its fields holding the click's 4 hours, and Return added
    /// another 4 hours.
    @MainActor
    func testACompactClickThatStartsWithAWarningLeavesNoLengthToAdd() async throws {
        let rig = Rig(.compact)
        defer { rig.tearDown() }
        let agent = "com.google.Chrome"
        rig.manager.config.disableAppNapForAgents = true
        rig.manager.config.agentList = [agent]
        rig.h.appNap.failWrites = [agent]
        rig.click()
        await rig.controller.sessionRequest?.value
        XCTAssertTrue(rig.manager.isActive)
        let warning = try XCTUnwrap(rig.manager.lastError)
        XCTAssertTrue(warning.contains(agent), warning)
        let endsAt = try XCTUnwrap(rig.manager.session?.endsAt)
        XCTAssertEqual(rig.compact.entry.input, DurationInput())
        XCTAssertNil(rig.compact.entry.keptRequest)
        XCTAssertFalse(rig.compact.isEditing)

        // The next click opens the panel on the running session and the
        // warning, with no fields.
        rig.click()
        XCTAssertTrue(rig.compact.isPresented)
        XCTAssertFalse(rig.compact.showsInputs(sessionActive: rig.manager.isActive, phase: rig.model.phase))
        let panel = CompactMenuView(
            model: rig.compact, menuBar: rig.model, manager: rig.manager,
            onSubmit: {}, onEnd: {}, onDismiss: {}
        )
        XCTAssertEqual(panel.displayedError, warning)

        // A click on the countdown to add time opens empty fields, and
        // Return there adds nothing.
        rig.compact.beginEditing(defaultField: rig.manager.config.defaultFocusField)
        XCTAssertTrue(rig.compact.showsInputs(sessionActive: rig.manager.isActive, phase: rig.model.phase))
        XCTAssertEqual(rig.compact.entry.input, DurationInput())
        rig.controller.compactSubmit()
        await rig.controller.sessionRequest?.value
        XCTAssertEqual(rig.manager.session?.endsAt, endsAt)

        rig.h.appNap.failWrites = []
        await rig.manager.end(reason: .user)
    }

    // MARK: Minimal

    /// Minimal adds the default length on every click, so the switch
    /// changes nothing there: the first click starts a session, the next
    /// adds to it.
    @MainActor
    func testMinimalIgnoresTheSwitch() async throws {
        for oneClick in [false, true] {
            let rig = Rig(.minimal, oneClick: oneClick)
            rig.click()
            var settled = await waitUntil { rig.manager.isActive && !rig.model.minimalBusy }
            XCTAssertTrue(settled, "switch \(oneClick)")
            let first = try XCTUnwrap(rig.manager.session)
            rig.click()
            settled = await waitUntil { rig.manager.session != first && !rig.model.minimalBusy }
            XCTAssertTrue(settled, "switch \(oneClick)")
            let second = try XCTUnwrap(rig.manager.session)
            XCTAssertEqual(second.endsAt.timeIntervalSince(first.endsAt), rig.manager.config.defaultPreset, "switch \(oneClick)")
            await rig.manager.end(reason: .user)
            rig.tearDown()
        }
    }
}
