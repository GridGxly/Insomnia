import SwiftUI
import Observation

enum SettingsPage: String, CaseIterable, Identifiable {
    case general, lid, advanced
    var id: String { rawValue }
    var title: String {
        switch self {
        case .general: "General"
        case .lid: "Lid actions"
        case .advanced: "Advanced"
        }
    }
    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .lid: "laptopcomputer"
        case .advanced: "slider.horizontal.3"
        }
    }
    var shortcut: KeyEquivalent {
        switch self {
        case .general: "1"
        case .lid: "2"
        case .advanced: "3"
        }
    }

    var contentSize: CGSize {
        switch self {
        case .general: CGSize(width: 620, height: 340)
        case .lid: CGSize(width: 620, height: 500)
        case .advanced: CGSize(width: 620, height: 420)
        }
    }
}

@MainActor
@Observable
final class SettingsNavigationModel {
    var selection: SettingsPage = .general
}

/// Keep the system disclosure rendering while giving its label a full-row
/// hit target. The native triangle remains the accessibility control.
struct SettingsDisclosureGroup<Content: View>: View {
    let title: String
    private let expansion: Binding<Bool>?
    private let content: Content
    @State private var localExpansion = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ title: String, isExpanded: Binding<Bool>? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        expansion = isExpanded
        self.content = content()
    }

    var body: some View {
        let expanded = expansion ?? $localExpansion
        DisclosureGroup(isExpanded: expanded) {
            content
        } label: {
            Button {
                withAnimation(Motion.interface(reduceMotion: reduceMotion)) { expanded.wrappedValue.toggle() }
            } label: {
                Text(title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .handCursor()
            .focusable(false)
            .accessibilityHidden(true)
        }
        .accessibilityLabel(title)
    }
}

struct FreezePreviewScope: Equatable {
    let enabled: Bool
    let freezeList: [String]
    let agentList: [String]
    init(config: Config) {
        enabled = config.freezeAllApps
        freezeList = config.freezeList
        agentList = config.agentList
    }
}

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        QuietButtonBody(label: configuration.label, pressed: configuration.isPressed)
    }
}

private struct QuietButtonBody<Label: View>: View {
    let label: Label
    let pressed: Bool
    @State private var hovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        label
            .foregroundStyle(.primary)
            .background(.primary.opacity(hovered ? 0.045 : 0), in: RoundedRectangle(cornerRadius: 8))
            .opacity(pressed ? 0.65 : 1)
            .scaleEffect(pressed && !reduceMotion ? 0.96 : 1)
            .animation(.easeOut(duration: 0.06), value: pressed)
            .animation(.easeOut(duration: 0.06), value: hovered)
            .onHover { hovered = $0 }
            .handCursor()
    }
}
