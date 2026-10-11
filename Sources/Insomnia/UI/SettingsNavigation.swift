import SwiftUI

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

struct SettingsSidebar: View {
    @Binding var selection: SettingsPage
    @Namespace private var highlight
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GlassEffectContainer(spacing: 5) {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(SettingsPage.allCases) { page in
                Button {
                    withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .spring(duration: 0.22, bounce: 0)) {
                        selection = page
                    }
                } label: {
                    Label(page.title, systemImage: page.symbol)
                        .font(.system(size: 13, weight: selection == page ? .semibold : .medium))
                        .tracking(-0.1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .frame(height: 40)
                        .modifier(NavigationGlass(selected: selection == page, namespace: highlight))
                        .contentShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(QuietButtonStyle())
                .keyboardShortcut(page.shortcut, modifiers: .command)
                .accessibilityAddTraits(selection == page ? [.isSelected] : [])
            }
            Spacer()
            HStack(spacing: 7) {
                EyeMarkView(progress: 1, size: 15)
                Text("Insomnia").font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
        .padding(12)
        }
        .background(.ultraThinMaterial)
    }
}

private struct NavigationGlass: ViewModifier {
    let selected: Bool
    let namespace: Namespace.ID
    func body(content: Content) -> some View {
        if selected {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))
                .glassEffectID("selection", in: namespace)
                .glassRim(radius: 10)
        } else {
            content
        }
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
            .animation(.easeOut(duration: 0.12), value: pressed)
            .animation(.easeOut(duration: 0.12), value: hovered)
            .onHover { hovered = $0 }
            .handCursor()
    }
}

/// The entire disclosure row is clickable, including its label. Keeps the
/// same binding and content as the native disclosure group.
struct SettingsDisclosureStyle: DisclosureGroupStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: reduceMotion ? 0.12 : 0.18)) {
                    configuration.isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .rotationEffect(.degrees(configuration.isExpanded ? 90 : 0))
                    configuration.label
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(QuietButtonStyle())
            .accessibilityValue(configuration.isExpanded ? "Expanded" : "Collapsed")
            if configuration.isExpanded {
                configuration.content
                    .disclosureGroupStyle(SettingsDisclosureStyle())
                    .padding(.top, 12)
                    .transition(.opacity)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct SettingsPageHeader: View {
    let page: SettingsPage
    var body: some View {
        Text(page.title)
            .font(.system(size: 22, weight: .semibold))
            .tracking(-0.55)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.top, 23)
            .padding(.bottom, 5)
    }
}
