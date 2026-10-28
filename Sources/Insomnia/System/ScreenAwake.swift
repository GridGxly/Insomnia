import Foundation
import IOKit.pwr_mgt

/// Keeps the screen on and unlocked during a session
/// (`Config.keepScreenAwake`, off by default).
///
/// `pmset -a disablesleep 1` stops system sleep only. The display still
/// sleeps after the `displaysleep` minutes, and with "Require password after
/// screen saver begins or display is turned off" set to Immediately the
/// screen locks right then, which stops agents that drive the screen. This
/// holds a `PreventUserIdleDisplaySleep` assertion, the one `caffeinate -d`
/// holds, from session start to session end, so the display never idles off,
/// the screen saver never starts and the lock never triggers. The lock
/// setting itself is never read or written.
///
/// Nothing is journaled: macOS releases the assertion when the process
/// exits, so a crash or a force-quit restores idle display sleep by itself
/// and the recovery agent has nothing to undo.
protocol DisplayAssertionHolding: Sendable {
    /// Creates the assertion and returns its id.
    func create(name: String) throws -> IOPMAssertionID
    func release(_ id: IOPMAssertionID)
}

struct ScreenAwakeError: Error, LocalizedError, Sendable {
    let status: IOReturn

    var errorDescription: String? { "IOPMAssertionCreateWithName(PreventUserIdleDisplaySleep) returned \(status)" }
}

/// IOKit power management.
struct IOPMDisplayAssertions: DisplayAssertionHolding {
    func create(name: String) throws -> IOPMAssertionID {
        var id: IOPMAssertionID = 0
        let status = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            name as CFString,
            &id)
        guard status == kIOReturnSuccess else { throw ScreenAwakeError(status: status) }
        return id
    }

    func release(_ id: IOPMAssertionID) {
        let status = IOPMAssertionRelease(id)
        if status != kIOReturnSuccess {
            Log.error("screen awake: IOPMAssertionRelease(\(id)) returned \(status)")
        }
    }
}

/// Creates nothing. The default for every wiring that does not pass the real
/// one, so no test holds the display of the Mac it runs on.
struct NoopDisplayAssertions: DisplayAssertionHolding {
    func create(name: String) throws -> IOPMAssertionID { 1 }
    func release(_ id: IOPMAssertionID) {}
}

/// At most one assertion, held while `set(true)` was the last call.
@MainActor
final class ScreenAwake {
    static let assertionName = "Insomnia session: keep the screen on and unlocked"

    private let assertions: any DisplayAssertionHolding
    private var held: IOPMAssertionID?

    var isHeld: Bool { held != nil }

    init(assertions: any DisplayAssertionHolding = NoopDisplayAssertions()) {
        self.assertions = assertions
    }

    /// Holds the assertion when `on` and releases it when not. Repeating
    /// the current state does nothing. A failed create is logged and leaves
    /// nothing held, so the next call tries again.
    func set(_ on: Bool) {
        if on {
            guard held == nil else { return }
            do {
                held = try assertions.create(name: Self.assertionName)
                Log.info("screen awake: display sleep held off for the session")
            } catch {
                Log.error("screen awake: \(error.localizedDescription); the display can still sleep and lock the screen")
            }
        } else {
            guard let id = held else { return }
            held = nil
            assertions.release(id)
            Log.info("screen awake: released, idle display sleep and the screen lock are back")
        }
    }
}
