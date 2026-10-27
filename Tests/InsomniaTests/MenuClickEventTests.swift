import AppKit
import SwiftUI
import XCTest
@testable import Insomnia

/// Right clicks and Control-clicks on the idle eye, delivered as real mouse
/// events to the SwiftUI status view, with one-click start on.
///
/// #63 made the eye a SwiftUI Button, which a right click or a Control-click
/// also pressed, so opening the menu toggled the session; b180afad fixed
/// that with a monitor that took the whole menu gesture first. The eye here
/// takes its click with `onTapGesture`, which a right click does not fire.
/// A Control-click did fire it: SwiftUI saw the press although the host's
/// `mouseDown` sent it to the menu, and tapped on the release. With
/// one-click start on, that tap starts a session, so the host's monitor
/// now takes the whole Control-click. These pin that the menu gestures
/// only open the menu, on macOS 26 and on 27, where the same monitor also
/// moves relayed clicks. The keys of an Option-click, which the same
/// monitor keeps for the tap, are tested here too.
final class MenuClickEventTests: XCTestCase {
    private final class Counts {
        var taps = 0
        var menus = 0
    }

    @MainActor
    private struct Rig {
        let h: Harness
        let manager: SessionManager
        let controller: StatusItemController
        let window: NSWindow
        let host: StatusHostingView
        let counts: Counts

        /// The eye. The window is the idle item's size; the host can be
        /// wider, since it only grows while the pills open, as in the menu
        /// bar, where the item's window cuts it off.
        var middle: NSPoint { NSPoint(x: window.frame.width / 2, y: window.frame.height / 2) }

        func tearDown() {
            window.orderOut(nil)
            controller.collapse(returnFocus: false)
            for panel in NSApp.windows.compactMap({ $0 as? KeyCatcherPanel }) where panel.isVisible {
                panel.orderOut(nil)
            }
            h.home.destroy()
        }
    }

    @MainActor
    private func makeRig(osMajorVersion: Int) async -> Rig {
        _ = NSApplication.shared
        let h = Harness()
        let manager = h.makeManager()
        manager.config.oneClickStart = true
        let controller = StatusItemController(
            manager: manager, status: PlaceholderStatus(), showSettings: {}, appFocus: UIStatusTests.quietFocus
        )
        let counts = Counts()
        // The item's own view over the controller's model, in a window the
        // test can send events to; the eye's tap goes to the controller as
        // it does in the menu bar.
        let root = StatusRootView(
            model: controller.model, manager: manager,
            onTapIcon: { counts.taps += 1; controller.iconTapped(modifiers: []) },
            onTapPill: { _ in }, onTapCountdown: {}, onHoldEnd: {}, onWidthChange: { _ in },
            buttonIsDown: { false }, pointerLocation: { .zero }
        )
        let host = StatusItemController.makeHostingView(root)
        host.osMajorVersion = osMajorVersion
        host.onRightMouseDown = { _ in counts.menus += 1 }
        let size = host.fittingSize
        host.frame = NSRect(origin: .zero, size: size)
        host.pointerInWindow = { _ in NSPoint(x: size.width / 2, y: size.height / 2) }
        host.buttonIsDown = { false }
        // Off screen: the window only needs to exist to deliver events.
        let window = NSWindow(contentRect: NSRect(x: -4000, y: -4000, width: size.width, height: size.height),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFrontRegardless()
        try? await Task.sleep(for: .seconds(0.5))
        return Rig(h: h, manager: manager, controller: controller, window: window, host: host, counts: counts)
    }

    /// Sends `down` and, unless it is nil, `up`. A nil `up` is a release
    /// the open menu's own tracking took, as it does in the menu bar.
    @MainActor
    private func click(_ down: NSEvent.EventType, _ up: NSEvent.EventType?, modifiers: NSEvent.ModifierFlags = [], _ rig: Rig) async {
        for (number, type) in [down, up].compactMap({ $0 }).enumerated() {
            let event = NSEvent.mouseEvent(
                with: type, location: rig.middle, modifierFlags: modifiers,
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: rig.window.windowNumber,
                context: nil, eventNumber: number + 1, clickCount: 1, pressure: type == down ? 1 : 0
            )!
            NSApp.sendEvent(event)
        }
        try? await Task.sleep(for: .seconds(0.2))
    }

    @MainActor
    func testRightClickAndControlClickOnlyOpenTheMenu() async {
        for os in [26, 27] {
            let rig = await makeRig(osMajorVersion: os)
            await click(.rightMouseDown, .rightMouseUp, rig)
            await click(.leftMouseDown, .leftMouseUp, modifiers: .control, rig)
            // A Control-click whose release the menu took, then a release
            // that reaches the window later, as when a click closes the menu.
            await click(.leftMouseDown, nil, modifiers: .control, rig)
            await click(.leftMouseUp, nil, rig)
            XCTAssertEqual(rig.counts.menus, 3, "macOS \(os)")
            XCTAssertEqual(rig.counts.taps, 0, "macOS \(os)")
            await settleQueuedRequests()
            XCTAssertEqual(rig.controller.model.phase, .idle, "macOS \(os)")
            XCTAssertEqual(rig.h.backstop.arms, 0, "macOS \(os)")
            XCTAssertFalse(rig.manager.isActive, "macOS \(os)")

            // The same delivery does reach the eye: a plain click after a
            // menu whose release went to its tracking starts a session.
            await click(.leftMouseDown, nil, modifiers: .control, rig)
            await click(.leftMouseDown, .leftMouseUp, rig)
            XCTAssertEqual(rig.counts.taps, 1, "macOS \(os)")
            XCTAssertEqual(rig.counts.menus, 4, "macOS \(os)")
            let started = await eventually { rig.manager.isActive }
            XCTAssertTrue(started, "macOS \(os)")
            await rig.manager.end(reason: .user)
            rig.tearDown()
        }
    }

    /// The controller's own status view, moved from its status item into a
    /// window the test can send events to, so the eye's tap reaches the
    /// controller as it does in the menu bar. The keys held now are none.
    @MainActor
    private func makeControllerRig(_ mode: Config.MenuBarMode, osMajorVersion: Int) async -> Rig {
        _ = NSApplication.shared
        let h = Harness()
        let manager = h.makeManager()
        manager.config.oneClickStart = true
        manager.config.menuBarMode = mode
        let controller = StatusItemController(
            manager: manager, status: PlaceholderStatus(), showSettings: {},
            appFocus: UIStatusTests.quietFocus, heldModifiers: { [] }
        )
        let host = controller.nativeStatusItem.button!.subviews.compactMap { $0 as? StatusHostingView }.first!
        host.removeFromSuperview()
        host.osMajorVersion = osMajorVersion
        let counts = Counts()
        host.onRightMouseDown = { _ in counts.menus += 1 }
        let size = host.fittingSize
        host.frame = NSRect(origin: .zero, size: size)
        host.pointerInWindow = { _ in NSPoint(x: size.width / 2, y: size.height / 2) }
        host.buttonIsDown = { false }
        let window = NSWindow(contentRect: NSRect(x: -4000, y: -4000, width: size.width, height: size.height),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFrontRegardless()
        try? await Task.sleep(for: .seconds(0.5))
        return Rig(h: h, manager: manager, controller: controller, window: window, host: host, counts: counts)
    }

    /// The eye's tap comes on the release, and a person can let go of
    /// Option as they let go of the button. A macOS 26.6.2 VM run posted
    /// Option on both mouse events and released it 0.5 ms after the
    /// mouse-up: Pills and Compact read only the keys held when the tap
    /// ran, found none and started a session. Here Option is on the press
    /// alone, then on the release alone, with no key held: the controls
    /// open and nothing starts. An Option press that never became a tap
    /// (dragged off the item and released there) does not count for the
    /// next click: a plain click then starts the default length.
    @MainActor
    func testAnOptionClickOpensTheControlsThoughOptionIsUpWhenTheTapRuns() async {
        for mode in [Config.MenuBarMode.pills, .compact] {
            for os in [26, 27] {
                let rig = await makeControllerRig(mode, osMajorVersion: os)
                let label = "\(mode), macOS \(os)"
                var controlsOpen: Bool {
                    mode == .pills ? rig.controller.model.phase.isEntering : rig.controller.compactModel.isPresented
                }
                for (press, release) in [(NSEvent.ModifierFlags.option, NSEvent.ModifierFlags()), ([], .option)] {
                    await click(.leftMouseDown, nil, modifiers: press, rig)
                    await click(.leftMouseUp, nil, modifiers: release, rig)
                    XCTAssertTrue(controlsOpen, "\(label), press \(press.rawValue), release \(release.rawValue)")
                    rig.controller.collapse(returnFocus: false)
                    rig.controller.closeCompactDropdown(returnFocus: false)
                    let closed = await eventually { !controlsOpen && rig.controller.model.phase == .idle }
                    XCTAssertTrue(closed, label)
                }
                await settleQueuedRequests()
                XCTAssertEqual(rig.h.backstop.arms, 0, label)
                XCTAssertFalse(rig.manager.isActive, label)

                let away = NSPoint(x: rig.middle.x + 300, y: rig.middle.y)
                await click(.leftMouseDown, nil, modifiers: .option, rig)
                await send(.leftMouseDragged, at: away, rig)
                await send(.leftMouseUp, at: away, rig)
                XCTAssertFalse(controlsOpen, "\(label): the press dragged away is no tap")
                XCTAssertEqual(rig.controller.model.phase, .idle, label)
                await click(.leftMouseDown, .leftMouseUp, rig)
                let started = await eventually { rig.manager.isActive }
                XCTAssertTrue(started, label)
                await rig.manager.end(reason: .user)
                rig.tearDown()
            }
        }
    }

    @MainActor
    private func send(_ type: NSEvent.EventType, at point: NSPoint, _ rig: Rig) async {
        let event = NSEvent.mouseEvent(
            with: type, location: point, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: rig.window.windowNumber,
            context: nil, eventNumber: 1, clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1
        )!
        NSApp.sendEvent(event)
        try? await Task.sleep(for: .seconds(0.2))
    }

    @MainActor
    private func eventually(_ condition: @MainActor () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }
}
