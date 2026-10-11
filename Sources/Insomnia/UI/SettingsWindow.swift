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
    private let content: () -> AnyView

    init(content: @escaping () -> AnyView) {
        self.content = content
    }

    /// Bring the window up, creating it the first time. An accessory app has
    /// to activate itself first or the window opens behind whatever is front.
    func show() {
        let window = window ?? make()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func make() -> NSWindow {
        let host = NSHostingController(rootView: content())
        let window = NSWindow(contentViewController: host)
        window.title = "Insomnia Settings"
        window.identifier = NSUserInterfaceItemIdentifier("insomnia.settings")
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .visible
        window.toolbarStyle = .unified
        window.isOpaque = false
        window.backgroundColor = .windowBackgroundColor
        // Closing settings must not deallocate the window: the status item
        // keeps a reference and reopens the same one.
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 640, height: 460)
        window.setContentSize(NSSize(width: 740, height: 540))
        window.center()
        #if DEBUG
        if UIPreview.isEnabled && CommandLine.arguments.contains("--ui-preview-compact") {
            // Deterministic capture size without editing saved window preferences.
        } else {
            window.setFrameAutosaveName("insomnia.settings")
        }
        #else
        window.setFrameAutosaveName("insomnia.settings")
        #endif
        window.isRestorable = false
        return window
    }
}
