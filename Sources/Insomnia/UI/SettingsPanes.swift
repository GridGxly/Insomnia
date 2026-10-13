import SwiftUI

/// The panes in the Settings sidebar, in sidebar order.
enum SettingsPane: String, CaseIterable, Identifiable {
    case general
    case sessions
    case lidClose
    case agents
    case power
    case network

    var id: String { rawValue }

    /// The UserDefaults key that remembers the pane last shown, so the
    /// window reopens on it (HIG: restore the most recently viewed pane).
    static let storageKey = "SettingsPane"

    /// The pane the window opens on.
    static var stored: SettingsPane {
        UserDefaults.standard.string(forKey: storageKey).flatMap(SettingsPane.init(rawValue:)) ?? .general
    }

    /// The sidebar row and the window title while the pane is showing.
    var title: String {
        switch self {
        case .general: "General"
        case .sessions: "Sessions"
        case .lidClose: "Lid Close"
        case .agents: "Agent Apps"
        case .power: "Battery & Thermal"
        case .network: "Network"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape.fill"
        case .sessions: "timer"
        case .lidClose: "laptopcomputer"
        case .agents: "cpu.fill"
        case .power: "battery.75percent"
        case .network: "wifi"
        }
    }

    /// The tile behind the symbol, as System Settings draws its panes.
    var tint: Color {
        switch self {
        case .general: .gray
        case .sessions: .indigo
        case .lidClose: .purple
        case .agents: .teal
        case .power: .green
        case .network: .blue
        }
    }
}

/// One setting the search field can find: the pane it lives on, the name
/// the user sees, and other words they might type for it. `id` is the
/// anchor the pane scrolls to (`SettingsView.anchored`).
struct SettingsEntry: Identifiable, Equatable {
    let id: String
    let pane: SettingsPane
    let title: String
    let keywords: [String]
}

/// What the sidebar search field matches against.
enum SettingsSearch {
    static let entries: [SettingsEntry] = [
        .init(id: "launchAtLogin", pane: .general, title: "Launch at login", keywords: ["startup", "login items", "open at login", "boot"]),
        .init(id: "configFile", pane: .general, title: "Config file", keywords: ["config.json", "json", "path", "location", "folder"]),

        .init(id: "presets", pane: .sessions, title: "Presets", keywords: ["durations", "chips", "time", "timer", "add preset"]),
        .init(id: "defaultPreset", pane: .sessions, title: "Default preset", keywords: ["duration", "time", "timer"]),
        .init(id: "maxSession", pane: .sessions, title: "Maximum session", keywords: ["limit", "longest", "duration", "30 days"]),

        .init(id: "darken", pane: .lidClose, title: "Turn off the display and keyboard backlight", keywords: ["brightness", "screen", "dim", "dark", "keyboard"]),
        .init(id: "freezeList", pane: .lidClose, title: "Freeze while the lid is closed", keywords: ["freeze list", "SIGSTOP", "pause", "stop", "apps", "bundle identifier"]),
        .init(id: "freezeAll", pane: .lidClose, title: "Freeze every other app", keywords: ["all apps", "Dock", "would freeze", "protected"]),
        .init(id: "docker", pane: .lidClose, title: "Pause Docker Desktop", keywords: ["containers", "Docker"]),
        .init(id: "mute", pane: .lidClose, title: "Mute audio on lid close", keywords: ["sound", "volume", "speakers", "microphone", "mic", "AirPods"]),
        .init(id: "lowPowerOnLidClose", pane: .lidClose, title: "Low Power Mode while the lid is closed", keywords: ["battery", "energy", "power"]),

        .init(id: "agentList", pane: .agents, title: "Never throttle or freeze", keywords: ["agent apps", "protect", "allow", "bundle identifier", "AI"]),
        .init(id: "appNap", pane: .agents, title: "Turn App Nap off", keywords: ["App Nap", "throttle", "NSAppSleepDisabled"]),

        .init(id: "lowPowerFloor", pane: .power, title: "Low Power Mode below", keywords: ["battery", "floor", "percent", "energy"]),
        .init(id: "endFloor", pane: .power, title: "End session below", keywords: ["battery", "floor", "percent", "stop"]),
        .init(id: "thermal", pane: .power, title: "Thermal rules", keywords: ["heat", "hot", "temperature", "critical", "fan"]),

        .init(id: "hotspot", pane: .network, title: "Hotspot name", keywords: ["SSID", "Wi-Fi", "iPhone", "Personal Hotspot", "failover", "offline", "internet"]),
        .init(id: "hotspotPassword", pane: .network, title: "Hotspot password", keywords: ["keychain", "Wi-Fi password", "secret"]),
        .init(id: "location", pane: .network, title: "Location Services", keywords: ["permission", "privacy", "Wi-Fi names", "SSID"]),
        .init(id: "nudge", pane: .network, title: "tmux nudge delay", keywords: ["tmux", "continue", "offline", "threshold", "seconds", "nudge"]),
        .init(id: "pressEnter", pane: .network, title: "Press Enter after continue", keywords: ["tmux", "return", "submit"]),
        .init(id: "tmuxTargets", pane: .network, title: "tmux targets", keywords: ["tmux", "pane", "session", "window", "mark"]),
    ]

    /// The entries every word of `query` matches, in sidebar order. A word
    /// matches when it starts a word of the entry's title, its keywords or
    /// its pane's title, ignoring case, accents and hyphens ("wifi" finds
    /// "Wi-Fi", "freez" finds "Freeze").
    static func results(for query: String) -> [SettingsEntry] {
        let wanted = words(query)
        guard !wanted.isEmpty else { return [] }
        return entries.filter { entry in
            let have = words(([entry.title, entry.pane.title] + entry.keywords).joined(separator: " "))
            return wanted.allSatisfy { w in have.contains { $0.hasPrefix(w) } }
        }
    }

    static func entry(_ id: String) -> SettingsEntry? {
        entries.first { $0.id == id }
    }

    private static func words(_ text: String) -> [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .replacingOccurrences(of: "-", with: "")
            .split { !$0.isLetter && !$0.isNumber && $0 != "." }
            .map(String.init)
    }
}

/// The line at the top of the hotspot section. Failover has no switch of
/// its own: it is on whenever a hotspot name is set, so this says whether
/// it is on and, if it cannot join yet, what is missing.
struct HotspotSetupStatus: Equatable {
    enum Level: Equatable {
        case off
        case incomplete
        case ready
    }

    let level: Level
    let text: String

    /// `passwordEntered` is whether the password field holds anything (a
    /// load fills it with the saved password); `passwordNotice` is the
    /// notice under the field.
    static func of(ssid: String, passwordEntered: Bool, passwordNotice: String?, locationAuthorized: Bool) -> HotspotSetupStatus {
        let name = HotspotSSID.normalized(ssid)
        if name.isEmpty {
            return .init(level: .off, text: "Off. Enter your hotspot's name to turn failover on.")
        }
        if passwordNotice != nil || !passwordEntered {
            return .init(level: .incomplete, text: "Needs the password for \u{201C}\(name)\u{201D}.")
        }
        if !locationAuthorized {
            return .init(level: .incomplete, text: "Needs Location access to find \u{201C}\(name)\u{201D}.")
        }
        return .init(level: .ready, text: "On. If Wi-Fi drops during a session, Insomnia joins \u{201C}\(name)\u{201D}.")
    }
}

private struct RevealedSettingKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    /// The setting a search result just jumped to, tinted for a moment.
    /// (Written out by hand: the `@Entry` macro needs Xcode's plugin.)
    var revealedSetting: String? {
        get { self[RevealedSettingKey.self] }
        set { self[RevealedSettingKey.self] = newValue }
    }
}

/// Rows that make up one searchable setting: the scroll target for its
/// search result, tinted while the jump lands on it.
struct SettingAnchor<Content: View>: View {
    let id: String
    let content: Content
    @Environment(\.revealedSetting) private var revealed

    var body: some View {
        Group { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(id)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.accentColor.opacity(revealed == id ? 0.16 : 0))
                    .padding(.horizontal, -6)
                    .padding(.vertical, -3)
            }
    }
}

/// A pane's sidebar icon, drawn as System Settings draws its own: a white
/// glyph centred on a coloured rounded square. The glyph is fitted into a
/// box 60% of the tile high and 70% wide, so square symbols keep a 4 pt
/// margin and wide ones (the laptop, the battery) 3 pt, instead of running
/// to the tile's edges.
struct PaneIcon: View {
    let pane: SettingsPane

    static let tile: CGFloat = 20
    static let glyph = CGSize(width: 14, height: 12)
    static let radius: CGFloat = 5

    var body: some View {
        Image(systemName: pane.symbol)
            .resizable()
            .scaledToFit()
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .frame(width: Self.glyph.width, height: Self.glyph.height)
            .frame(width: Self.tile, height: Self.tile)
            .background(pane.tint.gradient, in: .rect(cornerRadius: Self.radius, style: .continuous))
    }
}
