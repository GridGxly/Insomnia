import Foundation
import Observation

/// Whether the keychain holds a password the failover can read for the
/// configured hotspot, as the popover last found it. Read again each time
/// the popover opens, with the same prompt-free peek the Network pane's
/// recheck uses, so the row never raises a keychain dialog.
@MainActor
@Observable
final class HotspotPasswordCheck {
    struct Reading: Equatable {
        /// The normalized hotspot name the peek read for.
        let ssid: String
        let saved: Bool
        /// Why the saved password can't be read, as the Network pane says it.
        let notice: String?
    }

    private(set) var reading: Reading?
    /// Bumped by every refresh, so an older answer does not overwrite a newer one.
    @ObservationIgnored private var request = 0

    init() {}

    /// The last reading, if it is about `ssid`, the hotspot configured now.
    func reading(for ssid: String) -> Reading? {
        guard let reading, reading.ssid == HotspotSSID.normalized(ssid), !reading.ssid.isEmpty else { return nil }
        return reading
    }

    /// Peeks for `ssid`; nothing to read while no hotspot is set.
    func refresh(ssid: String, peek: () async throws -> String?) async {
        let name = HotspotSSID.normalized(ssid)
        guard !name.isEmpty else { return }
        request += 1
        let mine = request
        let answer = await HotspotPasswordField.loadedPassword(peek)
        guard mine == request else { return }
        reading = Reading(ssid: name, saved: !answer.password.isEmpty, notice: answer.notice)
    }
}

/// The popover's hotspot failover row: the Network pane's verdict
/// (`HotspotSetupStatus`) worded as a status row, with the longer line as
/// its tooltip.
enum HotspotFailoverRow {
    static let symbol = "personalhotspot"

    static func item(_ status: HotspotSetupStatus, notice: String? = nil) -> StatusMenu.Item {
        let title: String
        var help = status.text
        switch (status.level, status.missing) {
        case (.off, _):
            title = "Hotspot failover off"
            help = "Enter your hotspot\u{2019}s name in Settings to turn failover on."
        case (.incomplete, .location):
            title = "Hotspot failover needs Location access"
            help = "Allow Location in Settings so Insomnia can find \u{201C}\(status.ssid)\u{201D}."
        case (.incomplete, _):
            title = "Hotspot failover needs the password"
            help = notice ?? "Save the password for \u{201C}\(status.ssid)\u{201D} in Settings."
        case (.ready, _):
            title = "Hotspot failover ready"
        }
        return StatusMenu.Item(title: title, kind: .info, symbol: symbol, help: help)
    }

    /// The row for the hotspot `ssid` configured now. nil while a hotspot
    /// is set but its password has not been checked yet, rather than a
    /// guess.
    static func item(ssid: String, password: HotspotPasswordCheck.Reading?, locationAuthorized: Bool) -> StatusMenu.Item? {
        if HotspotSSID.normalized(ssid).isEmpty {
            return item(.of(ssid: ssid, passwordEntered: false, passwordNotice: nil, locationAuthorized: locationAuthorized))
        }
        guard let password else { return nil }
        let status = HotspotSetupStatus.of(
            ssid: ssid,
            passwordEntered: password.saved,
            passwordNotice: password.notice,
            locationAuthorized: locationAuthorized
        )
        return item(status, notice: password.notice)
    }
}
