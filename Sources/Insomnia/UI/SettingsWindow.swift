import AppKit
import SwiftUI

/// The settings window, owned by AppKit instead of SwiftUI's `Settings` scene.
///
/// `LSUIElement` apps have no app menu and, most of the time, no key window.
/// `NSApp.sendAction(Selector(("showSettingsWindow:")))` walks the responder
/// chain looking for whoever SwiftUI registered for that action and finds
/// nobody, so the scene never opens. (Quit works from the same menu because
/// `NSApplication.terminate` needs no responder chain at all.) Holding the
/// window ourselves removes the private selector and the guesswork.
@MainActor
final class SettingsWindow {
    private var window: NSWindow?
    private let content: () -> SettingsView

    init(content: @escaping () -> SettingsView) {
        self.content = content
        super.init()
    }

    isolated deinit {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
    }

    /// Bring the window up, creating it the first time. An accessory app has
    /// to activate itself first or the window opens behind whatever is front.
    func show() {
        let window = makeWindow()
        NSApp.activate(ignoringOtherApps: true)
        if !window.isVisible, let form = window.contentView {
            // The form's full height, for the rows it shows now. AppKit
            // fits a resizable window to a shorter screen, and the form
            // scrolls the rest.
            window.setContentSize(form.fittingSize)
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
    }

    func make() -> NSWindow {
        let host = NSHostingController(rootView: content())
        let window = NSWindow(contentViewController: host)
        window.title = "Insomnia Settings"
        // Resizable only so it can fit the screen (the form fixes the
        // width). HIG Settings: minimize and zoom dimmed; the menu bar icon
        // reopens it.
        window.styleMask = [.titled, .closable, .resizable]
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        // Closing settings must not deallocate the window: the status item
        // keeps a reference and reopens the same one.
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        self.window = window
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let handled = MainActor.assumeIsolated { self?.handleShortcut(event) ?? false }
            return handled ? nil : event
        }
        return window
    }

    func select(_ page: SettingsPage) {
        guard navigation.selection != page else { return }
        withAnimation(Motion.interface()) { navigation.selection = page }
        guard let window else { return }
        window.title = page.title
        window.toolbar?.selectedItemIdentifier = Self.identifier(for: page)
        if window.isVisible {
            // Let SwiftUI replace the Form before AppKit applies its size.
            // Otherwise first-responder/layout changes can override the resize.
            Task { @MainActor [weak self, weak window] in
                await Task.yield()
                guard let self, let window, self.navigation.selection == page else { return }
                window.contentView?.layoutSubtreeIfNeeded()
                self.resize(window, for: page)
            }
        } else {
            resize(window, for: page)
        }
    }

    private func resize(_ window: NSWindow, for page: SettingsPage) {
        let desired = window.frameRect(forContentRect: NSRect(origin: .zero, size: page.contentSize)).size
        let frame = NSRect(x: window.frame.minX, y: window.frame.maxY - desired.height, width: desired.width, height: desired.height)
        window.setFrame(window.constrainFrameRect(frame, to: window.screen), display: true, animate: window.isVisible && !Motion.reduceMotion)
    }

    func handleShortcut(_ event: NSEvent) -> Bool {
        guard let window, event.window === window,
              event.modifierFlags.intersection([.command, .control, .option, .shift]) == .command,
              let key = event.charactersIgnoringModifiers,
              let index = Int(key), (1...SettingsPage.allCases.count).contains(index) else { return false }
        select(SettingsPage.allCases[index - 1])
        return true
    }

    private static func identifier(for page: SettingsPage) -> NSToolbarItem.Identifier {
        NSToolbarItem.Identifier("insomnia.settings.\(page.rawValue)")
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace] + SettingsPage.allCases.map(Self.identifier(for:)) + [.flexibleSpace]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        SettingsPage.allCases.map(Self.identifier(for:))
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let page = SettingsPage.allCases.first(where: { Self.identifier(for: $0) == identifier }) else { return nil }
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = page.title
        item.paletteLabel = page.title
        item.image = NSImage(systemSymbolName: page.symbol, accessibilityDescription: page.title)
        item.target = self
        item.action = #selector(selectToolbarPane(_:))
        return item
    }

    @objc private func selectToolbarPane(_ sender: NSToolbarItem) {
        guard let page = SettingsPage.allCases.first(where: { Self.identifier(for: $0) == sender.itemIdentifier }) else { return }
        select(page)
    }
}

private final class PreferencesWindow: NSWindow {
    override func animationResizeTime(_ newFrame: NSRect) -> TimeInterval { 0.16 }
}
