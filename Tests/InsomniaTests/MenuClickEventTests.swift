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
/// takes its click with `onTapGesture`, which a right click does not fire,
/// and the host takes a Control-click before SwiftUI sees it. With one-click
/// start on, a click on the idle eye starts a session, so these pin that the
/// menu gestures still only open the menu, on macOS 26 and on 27, where the
/// host's pointer monitor sees every left click first.
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

        var middle: NSPoint { NSPoint(x: host.frame.width / 2, y: host.frame.height / 2) }

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

    @MainActor
    private func click(_ down: NSEvent.EventType, _ up: NSEvent.EventType, modifiers: NSEvent.ModifierFlags = [], _ rig: Rig) async {
        for (number, type) in [down, up].enumerated() {
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
            XCTAssertEqual(rig.counts.menus, 2, "macOS \(os)")
            XCTAssertEqual(rig.counts.taps, 0, "macOS \(os)")
            await settleQueuedRequests()
            XCTAssertEqual(rig.controller.model.phase, .idle, "macOS \(os)")
            XCTAssertEqual(rig.h.backstop.arms, 0, "macOS \(os)")
            XCTAssertFalse(rig.manager.isActive, "macOS \(os)")

            // The same delivery does reach the eye: a plain click starts.
            await click(.leftMouseDown, .leftMouseUp, rig)
            XCTAssertEqual(rig.counts.taps, 1, "macOS \(os)")
            XCTAssertEqual(rig.counts.menus, 2, "macOS \(os)")
            let started = await eventually { rig.manager.isActive }
            XCTAssertTrue(started, "macOS \(os)")
            await rig.manager.end(reason: .user)
            rig.tearDown()
        }
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
