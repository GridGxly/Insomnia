import AppKit
import Observation
import SwiftUI
import XCTest
@testable import Insomnia

/// Popover style next to the other three: a hold that outlives the popover
/// ends nothing, a style change leaves nothing of the old style behind, and
/// the popover gives focus back to the app the user was in.
final class PopoverStyleTests: XCTestCase {
    override func tearDown() {
        MainActor.assumeIsolated {
            for window in NSApp.windows where window.isVisible
                && (window.className.contains("Popover") || window is KeyCatcherPanel) {
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

        init(mode: Config.MenuBarMode = .popover, focus: CompactDropdownController.AppFocus = UIStatusTests.quietFocus) {
            _ = NSApplication.shared
            h = Harness()
            manager = h.makeManager()
            manager.config.menuBarMode = mode
            let clock = h.clock
            controller = StatusItemController(
                manager: manager, status: PlaceholderStatus(), showSettings: {}, clock: { clock.now }, appFocus: focus
            )
        }

        var model: MenuBarModel { controller.model }

        func changeMode(_ mode: Config.MenuBarMode) {
            manager.config.menuBarMode = mode
            controller.synchronizePresentation()
        }

        func startSession(_ duration: TimeInterval = 3600) async {
            await manager.start(duration: duration)
            XCTAssertTrue(manager.isActive)
        }

        /// Waits for the latest start, extend or end the controller handed
        /// to the manager, until its result is shown.
        func waitForRequest() async {
            await controller.sessionRequest?.value
        }

        /// A plain on-screen window for the popover to hang from: a status
        /// item in a test process may never be on screen.
        func anchor() -> NSWindow {
            let window = NSWindow(contentRect: NSRect(x: 200, y: 400, width: 120, height: 40), styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.orderFrontRegardless()
            controller.popoverAnchor = window.contentView
            return window
        }
    }

    /// Returns once every block queued on the main queue before the call
    /// has run.
    @MainActor
    private func mainQueueTurn() async {
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async { done.resume() }
        }
    }

    // MARK: The bar

    /// In the time-left style the bar reads the minute text only. The
    /// manager's H:MM:SS text changes every second, and a bar that read it
    /// would be redrawn every second, which main's policy (1cd9d3a5) rules
    /// out.
    @MainActor
    func testThePopoverBarIsRedrawnOnceAMinuteNotEverySecond() async {
        let rig = Rig()
        defer { rig.h.home.destroy() }
        await rig.startSession(2 * 3600)
        rig.h.clock.advance(30)
        rig.manager.refreshCountdown()
        let root = StatusRootView(
            model: rig.model, manager: rig.manager, onTapIcon: {}, onTapPill: { _ in },
            onTapCountdown: {}, onHoldEnd: {}, onWidthChange: { _ in }
        )
        func redrawn(after seconds: TimeInterval) -> Bool {
            let changed = Locked(false)
            withObservationTracking { _ = root.body } onChange: { changed.value = true }
            rig.h.clock.advance(seconds)
            rig.manager.refreshCountdown()
            return changed.value
        }
        XCTAssertFalse(redrawn(after: 1), "a second inside the same minute")
        XCTAssertEqual(rig.manager.remainingText, "1h 59m")
        XCTAssertTrue(redrawn(after: 60), "the next minute")
        XCTAssertEqual(rig.manager.remainingText, "1h 58m")
    }

    // MARK: Hold to end

    /// The popover's ring ends the session only while the popover is up in
    /// Popover style. A hold whose ring closes after the popover was closed
    /// (a click outside, Esc, the item) or after a style change ends
    /// nothing.
    @MainActor
    func testTheRingEndsTheSessionOnlyWhileThePopoverIsUp() async {
        let rig = Rig()
        defer { rig.h.home.destroy() }
        await rig.startSession()

        rig.controller.openPopover()
        rig.controller.closePopover()
        rig.controller.popoverHoldToEnd()
        rig.controller.holdToEnd()
        await settleQueuedRequests()
        XCTAssertTrue(rig.manager.isActive, "the popover was closed before the ring closed")

        rig.controller.openPopover()
        rig.changeMode(.pills)
        XCTAssertFalse(rig.model.popoverShown)
        rig.controller.popoverHoldToEnd()
        await settleQueuedRequests()
        XCTAssertTrue(rig.manager.isActive, "the style changed under the hold")

        rig.changeMode(.popover)
        rig.controller.openPopover()
        rig.controller.popoverHoldToEnd()
        await rig.waitForRequest()
        XCTAssertFalse(rig.manager.isActive, "the ring ends the session while the popover is up")
    }

    /// The ring itself drops a hold when it leaves the screen or is turned
    /// off before it closes: the popover closing takes it away, and an end
    /// already on its way turns it off. The ring's own timer is the only
    /// thing left that could end the session, and it must not.
    @MainActor
    func testTheRingEndsNothingOnceItIsGoneOrTurnedOffMidHold() async {
        for change in [RingChange.none, .removed, .disabled] {
            let holds = await holdRing(change)
            XCTAssertEqual(holds, change == .none ? 1 : 0, "\(change)")
        }
    }

    /// Press the ring, make `change` 0.2 s in (the ring closes at 0.6 s),
    /// and return how many times it ended the session. The button stays
    /// down and the pointer still: only the change can stop the hold.
    @MainActor
    private func holdRing(_ change: RingChange) async -> Int {
        _ = NSApplication.shared
        var holds = 0
        let box = RingBox()
        let host = NSHostingView(rootView: RingHost(box: box, action: { holds += 1 }))
        host.frame = NSRect(x: 0, y: 0, width: 20, height: 20)
        let window = NSWindow(contentRect: NSRect(x: -4000, y: -4000, width: 20, height: 20),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        defer { window.orderOut(nil) }
        window.contentView = host
        window.orderFrontRegardless()
        try? await Task.sleep(for: .seconds(0.3))
        NSApp.sendEvent(NSEvent.mouseEvent(
            with: .leftMouseDown, location: NSPoint(x: 10, y: 10), modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, eventNumber: 1, clickCount: 1, pressure: 1
        )!)
        try? await Task.sleep(for: .seconds(0.2))
        switch change {
        case .none: break
        case .removed: box.shown = false
        case .disabled: box.enabled = false
        }
        try? await Task.sleep(for: .seconds(0.7))
        return holds
    }

    // MARK: Style changes

    /// Leaving Popover style with the popover up closes it, stops watching
    /// for clicks outside it and takes the button's action away; the
    /// popover does not open in another style.
    @MainActor
    func testLeavingPopoverStyleLeavesNoPopoverOrMonitorBehind() async {
        for next in [Config.MenuBarMode.pills, .compact, .minimal] {
            let rig = Rig()
            defer { rig.h.home.destroy() }
            let window = rig.anchor()
            defer { window.orderOut(nil) }
            await rig.startSession()
            rig.controller.openPopover()
            XCTAssertEqual(rig.controller.popover?.isShown, true)
            XCTAssertTrue(rig.controller.watchesForPopoverDismissal)

            rig.changeMode(next)
            XCTAssertFalse(rig.model.popoverShown, "\(next)")
            XCTAssertEqual(rig.controller.popover?.isShown, false, "\(next)")
            XCTAssertFalse(rig.controller.watchesForPopoverDismissal, "\(next)")
            XCTAssertNil(rig.controller.nativeStatusItem.button?.action, "\(next)")
            rig.controller.openPopover()
            XCTAssertFalse(rig.model.popoverShown, "\(next): no popover outside Popover style")
            XCTAssertEqual(next == .minimal, rig.controller.minimalTick != nil, "\(next): only Minimal ticks")
        }
    }

    /// Entering Popover style with the pills open, or from Minimal during a
    /// session, takes the pills, their key catcher and Minimal's tick down.
    @MainActor
    func testEnteringPopoverStyleLeavesNoPillsPanelOrTickBehind() async {
        let pills = Rig(mode: .pills)
        defer { pills.h.home.destroy() }
        pills.controller.expand(mode: .start)
        XCTAssertTrue(NSApp.windows.contains { ($0 as? KeyCatcherPanel)?.isVisible == true })
        pills.changeMode(.popover)
        XCTAssertFalse(pills.model.slotsPresent)
        XCTAssertFalse(pills.model.focusVisible)
        XCTAssertEqual(pills.model.phase, .idle)
        XCTAssertFalse(NSApp.windows.contains { ($0 as? KeyCatcherPanel)?.isVisible == true })
        XCTAssertNotNil(pills.controller.nativeStatusItem.button?.action, "the button takes the clicks now")

        let minimal = Rig(mode: .minimal)
        defer { minimal.h.home.destroy() }
        await minimal.startSession()
        XCTAssertNotNil(minimal.controller.minimalTick)
        minimal.changeMode(.popover)
        XCTAssertNil(minimal.controller.minimalTick)
    }

    /// A start asked for in the popover and still pending when the style
    /// changes keeps going in the new style: its countdown takes the new
    /// style's form, it is confirmed once, and nothing of the popover is
    /// left up.
    @MainActor
    func testAPendingPopoverStartCarriesOverToTheNewStyle() async {
        let rig = Rig()
        defer { rig.h.home.destroy() }
        let gate = AsyncGate()
        rig.h.backstop.armGate = gate
        rig.controller.openPopover()
        rig.model.texts[.hours] = "2"
        rig.controller.commit()
        await gate.waitUntilStarted()
        XCTAssertEqual(rig.model.pendingCountdown, "2h", "Popover's short form")

        rig.changeMode(.pills)
        XCTAssertFalse(rig.model.popoverShown)
        XCTAssertEqual(rig.model.phase, .starting)
        XCTAssertEqual(rig.model.pendingCountdown, "2:00:00", "the pills' form")
        await gate.open()
        await rig.waitForRequest()
        XCTAssertTrue(rig.manager.isActive)
        XCTAssertEqual(rig.model.phase, .running)
        XCTAssertNil(rig.model.pendingCountdown)
        XCTAssertEqual(rig.h.backstop.arms, 1)
        XCTAssertFalse(rig.controller.pendingTickArmed)
    }

    /// The same start refused after the change: the pills reopen on the
    /// value typed in the popover, as they do for one typed in the Compact
    /// panel.
    @MainActor
    func testAPopoverStartRefusedAfterSwitchingToPillsReopensThePillsOnTheValue() async {
        let rig = Rig()
        defer { rig.h.home.destroy() }
        let gate = AsyncGate()
        rig.h.backstop.armGate = gate
        rig.h.backstop.failArm = true
        rig.controller.openPopover()
        rig.model.texts[.hours] = "2"
        rig.controller.commit()
        await gate.waitUntilStarted()
        rig.changeMode(.pills)

        await gate.open()
        await rig.waitForRequest()
        XCTAssertTrue(rig.model.phase.isEntering)
        XCTAssertFalse(rig.manager.isActive)
        XCTAssertEqual(rig.model.input.total, 7200)
        XCTAssertEqual(rig.model.startError, MenuBarModel.startFailedText)
        XCTAssertFalse(rig.model.popoverShown)
        XCTAssertFalse(rig.controller.pendingTickArmed)
        rig.controller.collapse()
    }

    /// A chip's start refused after a switch to Pills: the pills reopen on
    /// the chip's duration, and Return asks for that duration again, not
    /// for the default preset.
    @MainActor
    func testAChipStartRefusedAfterSwitchingToPillsRetriesTheChipsDuration() async {
        let rig = Rig()
        defer { rig.h.home.destroy() }
        XCTAssertNotEqual(rig.manager.config.defaultPreset, 7200)
        let gate = AsyncGate()
        rig.h.backstop.armGate = gate
        rig.h.backstop.failArm = true
        rig.controller.openPopover()
        rig.controller.startPreset(7200)
        await gate.waitUntilStarted()
        rig.changeMode(.pills)

        await gate.open()
        await rig.waitForRequest()
        XCTAssertTrue(rig.model.phase.isEntering)
        XCTAssertFalse(rig.manager.isActive)
        XCTAssertEqual(rig.model.input.total, 7200)

        rig.h.backstop.armGate = nil
        rig.h.backstop.failArm = false
        rig.controller.commit()
        await rig.waitForRequest()
        XCTAssertTrue(rig.manager.isActive)
        let session = rig.manager.session
        XCTAssertEqual(session.map { $0.endsAt.timeIntervalSince($0.startedAt) }, 7200)
        _ = await rig.manager.end(reason: .user)
    }

    /// An extend chip refused after a switch to Compact: the panel's entry
    /// opens on the chip's duration, not on an older value, and submitting
    /// it extends by that duration.
    @MainActor
    func testAnExtendChipRefusedAfterSwitchingToCompactRetriesTheChipsDuration() async {
        let rig = Rig()
        defer { rig.h.home.destroy() }
        await rig.startSession()
        let endsAt = rig.manager.session?.endsAt
        // Left over from an earlier entry in the pills.
        rig.model.input = DurationInput.from(seconds: 4 * 3600)
        let gate = AsyncGate()
        rig.h.backstop.armGate = gate
        rig.h.backstop.failArm = true
        rig.controller.openPopover()
        rig.controller.extendBy(1800)
        await gate.waitUntilStarted()
        rig.changeMode(.compact)

        await gate.open()
        await rig.waitForRequest()
        XCTAssertFalse(rig.controller.compactModel.isBusy)
        XCTAssertTrue(rig.manager.isActive)
        XCTAssertEqual(rig.manager.session?.endsAt, endsAt)
        XCTAssertTrue(rig.controller.compactModel.isEditing)
        XCTAssertEqual(rig.controller.compactModel.entry.input.total, 1800)

        rig.h.backstop.armGate = nil
        rig.h.backstop.failArm = false
        rig.controller.compactSubmit()
        await rig.waitForRequest()
        XCTAssertNotEqual(rig.manager.session?.endsAt, endsAt)
        XCTAssertEqual(rig.manager.session?.extensions, [1800])
        _ = await rig.manager.end(reason: .user)
    }

    /// A 90 s start, from a popover chip or a Minimal click, refused after
    /// a switch to Pills or Compact. The pills and the panel's entry show
    /// whole minutes, so they read 1m, but submitting that input as it
    /// stands asks for 90 s again.
    @MainActor
    func testA90SecondStartRefusedAfterASwitchIsRetriedAt90Seconds() async {
        let switches: [(from: Config.MenuBarMode, to: Config.MenuBarMode)] = [
            (.popover, .pills), (.popover, .compact), (.minimal, .pills), (.minimal, .compact),
        ]
        for (from, to) in switches {
            let label = "\(from) to \(to)"
            let rig = Rig(mode: from)
            defer { rig.h.home.destroy() }
            let gate = AsyncGate()
            rig.h.backstop.armGate = gate
            rig.h.backstop.failArm = true
            if from == .popover {
                rig.controller.openPopover()
                rig.controller.startPreset(90)
            } else {
                rig.manager.config.defaultPreset = 90
                rig.controller.iconTapped()
            }
            await gate.waitUntilStarted()
            rig.changeMode(to)

            await gate.open()
            await rig.waitForRequest()
            XCTAssertFalse(rig.controller.compactModel.isBusy, label)
            XCTAssertFalse(rig.manager.isActive, label)
            rig.h.backstop.armGate = nil
            rig.h.backstop.failArm = false
            if to == .pills {
                XCTAssertTrue(rig.model.phase.isEntering, label)
                XCTAssertEqual(rig.model.input.total, 60, label)
                rig.controller.commit()
            } else {
                XCTAssertEqual(rig.controller.compactModel.entry.input.total, 60, label)
                rig.controller.compactSubmit()
            }
            await rig.waitForRequest()
            XCTAssertTrue(rig.manager.isActive, label)
            let session = rig.manager.session
            XCTAssertEqual(session.map { $0.endsAt.timeIntervalSince($0.startedAt) }, 90, label)
            _ = await rig.manager.end(reason: .user)
        }
    }

    /// The same for a 90 s extend chip refused after a switch to Compact:
    /// the entry reads 1m, and submitting it extends by 90 s.
    @MainActor
    func testA90SecondExtendChipRefusedAfterSwitchingToCompactIsRetriedAt90Seconds() async {
        let rig = Rig()
        defer { rig.h.home.destroy() }
        await rig.startSession()
        let endsAt = rig.manager.session?.endsAt
        let gate = AsyncGate()
        rig.h.backstop.armGate = gate
        rig.h.backstop.failArm = true
        rig.controller.openPopover()
        rig.controller.extendBy(90)
        await gate.waitUntilStarted()
        rig.changeMode(.compact)

        await gate.open()
        await rig.waitForRequest()
        XCTAssertFalse(rig.controller.compactModel.isBusy)
        XCTAssertEqual(rig.manager.session?.endsAt, endsAt)
        XCTAssertEqual(rig.controller.compactModel.entry.input.total, 60)

        rig.h.backstop.armGate = nil
        rig.h.backstop.failArm = false
        rig.controller.compactSubmit()
        await rig.waitForRequest()
        XCTAssertNotEqual(rig.manager.session?.endsAt, endsAt)
        XCTAssertEqual(rig.manager.session?.extensions, [90])
        _ = await rig.manager.end(reason: .user)
    }

    /// An edit drops the chip's 90 s, even one that leaves the input as it
    /// was: after a backspace and the same digit again, the submit asks
    /// for the 1m typed.
    @MainActor
    func testAnEditAfterARefusalAsksForWhatIsTyped() async {
        for to in [Config.MenuBarMode.pills, .compact] {
            let rig = Rig()
            defer { rig.h.home.destroy() }
            let gate = AsyncGate()
            rig.h.backstop.armGate = gate
            rig.h.backstop.failArm = true
            rig.controller.openPopover()
            rig.controller.startPreset(90)
            await gate.waitUntilStarted()
            rig.changeMode(to)

            await gate.open()
            await rig.waitForRequest()
            XCTAssertFalse(rig.controller.compactModel.isBusy, "\(to)")
            rig.h.backstop.armGate = nil
            rig.h.backstop.failArm = false
            let entry = to == .pills ? rig.model : rig.controller.compactModel.entry
            let shown = entry.input
            entry.applyInput(.focus(.minutes), reduceMotion: true)
            entry.applyInput(.backspace, reduceMotion: true)
            entry.applyInput(.digit(1), reduceMotion: true)
            XCTAssertEqual(entry.input, shown, "\(to)")
            if to == .pills {
                rig.controller.commit()
            } else {
                rig.controller.compactSubmit()
            }
            await rig.waitForRequest()
            XCTAssertTrue(rig.manager.isActive, "\(to)")
            let session = rig.manager.session
            XCTAssertEqual(session.map { $0.endsAt.timeIntervalSince($0.startedAt) }, 60, "\(to)")
            _ = await rig.manager.end(reason: .user)
        }
    }

    // MARK: Focus

    /// The popover takes focus when it opens, with the cursor asked into its
    /// fields, and gives focus back to the app the user was in when Esc,
    /// the item or a style change closes it. A close because focus went
    /// somewhere else (a click outside, another of the app's windows,
    /// Settings, a Space change, another app in front, a window of the app
    /// taking key) leaves focus there.
    @MainActor
    func testThePopoverTakesFocusAndGivesItBackToTheAppTheUserWasIn() async throws {
        _ = NSApplication.shared
        let editor = try XCTUnwrap(NSWorkspace.shared.runningApplications.first { $0 != .current })
        let recorder = PopoverFocusRecorder(front: editor)
        let rig = Rig(focus: recorder.focus)
        defer { rig.h.home.destroy() }
        let window = rig.anchor()
        defer { window.orderOut(nil) }
        let other = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 50, height: 50), styleMask: [.titled], backing: .buffered, defer: true)
        other.isReleasedWhenClosed = false

        /// Open with another app in front, as from the menu bar.
        func open() {
            recorder.active = false
            let requests = rig.model.focusRequest
            rig.controller.openPopover()
            XCTAssertTrue(rig.model.popoverShown)
            XCTAssertEqual(rig.model.focusRequest, requests + 1, "the fields are asked to take the cursor")
            recorder.active = true
        }

        // Esc.
        open()
        XCTAssertEqual(recorder.activations, 1, "opening activates Insomnia")
        XCTAssertEqual(rig.controller.popoverReturnApp, editor)
        rig.controller.makePopoverView().actions.close()
        XCTAssertEqual(recorder.yields, [editor], "Esc gives focus back")

        // A second click on the item.
        open()
        rig.controller.togglePopover()
        XCTAssertEqual(recorder.yields, [editor, editor])

        // A style change.
        open()
        rig.changeMode(.pills)
        XCTAssertEqual(recorder.yields.count, 3)
        rig.changeMode(.popover)

        // A click outside that brings no app forward, such as one on
        // another menu bar item, gives focus back once it has had its turn.
        let outside = NSPoint(x: window.frame.minX - 40, y: window.frame.midY)
        open()
        rig.controller.dismissUnlessOnItem(at: outside)
        XCTAssertFalse(rig.model.popoverShown)
        XCTAssertEqual(recorder.yields.count, 3, "not before the click has had its turn")
        await mainQueueTurn()
        XCTAssertEqual(recorder.yields.count, 4, "a click outside that leaves Insomnia in front gives focus back")
        XCTAssertEqual(recorder.yields.last, editor)

        // Focus went elsewhere: it stays there. A click outside that has
        // brought another app forward by the time it is checked, then one
        // the user followed by opening the popover again and clicking into
        // Settings before the check ran.
        open()
        rig.controller.dismissUnlessOnItem(at: outside)
        recorder.active = false
        try? await Task.sleep(for: .milliseconds(50))
        open()
        rig.controller.dismissUnlessOnItem(at: outside)
        open()
        rig.controller.clickedInApp(window: other)
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(recorder.yields.count, 4)
        open()
        rig.controller.openSettingsFromPopover()
        open()
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        await mainQueueTurn()
        XCTAssertFalse(rig.model.popoverShown, "a Space change closes it")
        open()
        recorder.keyWindow = true
        rig.controller.closePopover()
        recorder.keyWindow = false
        open()
        recorder.active = false
        rig.controller.closePopover()
        recorder.active = true
        XCTAssertEqual(recorder.yields.count, 4)

        // Opened while Insomnia was in front: there is no app to return to.
        recorder.front = .current
        open()
        XCTAssertNil(rig.controller.popoverReturnApp)
        rig.controller.closePopover()
        XCTAssertEqual(recorder.yields.count, 4)
        XCTAssertNil(rig.controller.popoverReturnApp)
    }
}

/// Stands in for the app activation calls, so a test run never changes the
/// app in front on the Mac.
@MainActor
private final class PopoverFocusRecorder {
    var front: NSRunningApplication?
    var active = true
    var keyWindow = false
    private(set) var activations = 0
    private(set) var yields: [NSRunningApplication] = []

    init(front: NSRunningApplication?) { self.front = front }

    var focus: CompactDropdownController.AppFocus {
        CompactDropdownController.AppFocus(
            frontmost: { [unowned self] in front },
            isActive: { [unowned self] in active },
            hasKeyWindow: { [unowned self] in keyWindow },
            activate: { [unowned self] in activations += 1 },
            yield: { [unowned self] app in yields.append(app) }
        )
    }
}

private enum RingChange { case none, removed, disabled }

@MainActor @Observable
fileprivate final class RingBox {
    var shown = true
    var enabled = true
}

private struct RingHost: View {
    let box: RingBox
    let action: () -> Void

    var body: some View {
        ZStack {
            Color.clear
            if box.shown {
                HoldToEndButton(
                    reduceMotion: true, isEnabled: box.enabled, action: action,
                    isPressed: { true }, pointer: { .zero }
                )
            }
        }
        .frame(width: 20, height: 20)
    }
}
