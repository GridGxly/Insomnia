import SwiftUI

/// Compact editor over the existing configuration bindings. Secondary app
/// identifiers remain available as tooltips and in the manual entry field.
struct SettingsAppList: View {
    let title: String
    let items: [String]
    @Binding var newValue: String
    let add: (String) -> Void
    let remove: (String) -> Void
    @State private var showAll = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var visibleItems: [String] { showAll ? items : Array(items.prefix(4)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text("\(items.count) \(items.count == 1 ? "app" : "apps")").monospacedDigit()
            }
            .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            if items.isEmpty {
                Text("No apps added").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(visibleItems, id: \.self) { id in
                let name = RunningApps.displayName(for: id)
                HStack {
                    Text(name).help(id)
                    Spacer()
                    Button { remove(id) } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(.secondary)
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(QuietButtonStyle())
                    .help("Remove")
                    .accessibilityLabel("Remove \(name)")
                }
            }
            if items.count > 4 {
                Button {
                    withAnimation(Motion.interface(reduceMotion: reduceMotion)) { showAll.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Text(showAll ? "Show fewer apps" : "Show all \(items.count) apps")
                        Image(systemName: showAll ? "chevron.up" : "chevron.down").font(.system(size: 9, weight: .semibold))
                    }
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                    .frame(height: 32)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .handCursor()
            }
            Menu {
                let apps = RunningApps.candidates(excluding: items)
                if apps.isEmpty { Text("No other apps running") }
                ForEach(apps.filter { !$0.isBackground }, id: \.bundleID) { app in
                    Button(app.name) { add(app.bundleID) }
                }
                let background = apps.filter(\.isBackground)
                if !background.isEmpty {
                    Menu("Background apps") {
                        ForEach(background, id: \.bundleID) { app in
                            Button(app.name) { add(app.bundleID) }
                        }
                    }
                }
            } label: { Label("Add app", systemImage: "plus") }
            .fixedSize()
            .handCursor()
            DisclosureGroup("Add by bundle identifier") {
                HStack {
                    TextField("", text: $newValue, prompt: Text("Bundle identifier"))
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addIdentifier)
                        .accessibilityLabel("App bundle identifier")
                    Button("Add", action: addIdentifier)
                        .handCursor()
                        .disabled(newValue.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func addIdentifier() {
        let id = newValue.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty else { return }
        add(id)
        newValue = ""
    }
}
