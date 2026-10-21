import AppKit

/// Reports when every display goes to sleep and when the first one wakes,
/// from NSWorkspace's screensDidSleep and screensDidWake notifications.
/// Nothing runs between them. Lives as long as the app, so the state is
/// known when a session starts.
@MainActor
final class DisplaySleepObserver {
    private let center: NotificationCenter
    private var tokens: [NSObjectProtocol] = []

    /// `center` is NSWorkspace's; tests pass their own.
    init(center: NotificationCenter = NSWorkspace.shared.notificationCenter, onChange: @escaping @MainActor (_ asleep: Bool) -> Void) {
        self.center = center
        for (name, asleep) in [(NSWorkspace.screensDidSleepNotification, true), (NSWorkspace.screensDidWakeNotification, false)] {
            tokens.append(center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { onChange(asleep) }
            })
        }
    }

    isolated deinit {
        tokens.forEach(center.removeObserver)
    }
}
