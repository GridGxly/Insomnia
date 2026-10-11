import SwiftUI

struct QuickMenuView: View {
    let manager: SessionManager
    let model: MenuBarModel
    let onPreset: (TimeInterval) -> Void
    let onToggle: () -> Void
    let onSettings: () -> Void
    let onDetails: () -> Void
    let onQuit: () -> Void
    let onDismiss: () -> Void

    private var starting: Bool { model.phase == .starting }

    var body: some View {
        GlassEffectContainer(spacing: 8) {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Insomnia").font(.system(size: 15, weight: .semibold)).tracking(-0.3)
                Spacer()
                HStack(spacing: 5) {
                    Circle().fill(starting ? Color.orange : manager.isActive ? Color.green : Color.secondary).frame(width: 5, height: 5)
                    Text(starting ? "Starting" : manager.isActive ? "Awake" : "Off")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.secondary)
            }
            QuickSessionSummary(manager: manager, model: model)
            VStack(alignment: .leading, spacing: 9) {
                Text(manager.isActive ? "Add time" : "Quick start")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())], spacing: 8) {
                    ForEach([TimeInterval(1800), 3600, 7200, 14400], id: \.self) { duration in
                        Button { onPreset(duration) } label: {
                            HStack {
                                Text(chipLabel(for: duration)).monospacedDigit()
                                Spacer()
                                Image(systemName: manager.isActive ? "plus" : "play")
                                    .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                            }
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 12)
                            .frame(height: 40)
                            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 11))
                            .glassRim(radius: 11)
                            .contentShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(QuietButtonStyle())
                        .disabled(starting || duration > manager.config.maxDuration)
                        .accessibilityLabel("\(manager.isActive ? "Add" : "Start") \(chipLabel(for: duration))")
                    }
                }
            }
            if let error = manager.lastError ?? manager.foreignSleepWarning {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange).lineLimit(3)
            }
            Divider()
            VStack(spacing: 2) {
                menuRow(starting ? "Starting session…" : manager.isActive ? "End session" : "Start \(chipLabel(for: manager.config.defaultPreset))", symbol: manager.isActive ? "stop.circle" : "play.circle", emphasized: true, action: onToggle)
                    .disabled(starting)
                menuRow("Settings", symbol: "gearshape", shortcut: "⌘,", action: onSettings)
                    .keyboardShortcut(",", modifiers: .command)
                menuRow("Status details", symbol: "info.circle", action: onDetails)
                menuRow("Quit Insomnia", symbol: "power", shortcut: "⌘Q", action: onQuit)
                    .keyboardShortcut("q", modifiers: .command)
            }
            Text("Right-click to toggle · ⌘-drag to move")
                .font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(width: 300)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .glassRim(radius: 20)
        .onExitCommand(perform: onDismiss)
        }
    }

    private func menuRow(_ title: String, symbol: String, shortcut: String? = nil, emphasized: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol).frame(width: 16)
                Text(title)
                Spacer(minLength: 8)
                if let shortcut {
                    Text(shortcut).font(.system(size: 11)).foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .font(.system(size: 13, weight: emphasized ? .medium : .regular))
            .padding(.horizontal, 8)
            .frame(height: 40)
            .modifier(QuickActionSurface(emphasized: emphasized))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(QuietButtonStyle())
    }
}

private struct QuickActionSurface: ViewModifier {
    let emphasized: Bool
    func body(content: Content) -> some View {
        if emphasized {
            content
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 10))
                .glassRim(radius: 10)
        } else {
            content
        }
    }
}

/// Isolates the second-by-second text from the menu's controls.
private struct QuickSessionSummary: View {
    let manager: SessionManager
    let model: MenuBarModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(manager.isActive || model.phase == .starting
                 ? StatusRootView.countdownText(pending: model.pendingCountdown, live: manager.countdownText, phase: model.phase)
                 : chipLabel(for: manager.config.defaultPreset))
                .font(.system(size: 34, weight: .medium, design: .rounded))
                .tracking(-1)
                .monospacedDigit()
                .contentTransition(reduceMotion ? .opacity : .numericText(countsDown: true))
                .animation(Motion.tick(reduceMotion: reduceMotion), value: manager.countdownText)
            Text(manager.isActive ? "Your Mac stays awake until the timer ends." : "Default session")
                .font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
