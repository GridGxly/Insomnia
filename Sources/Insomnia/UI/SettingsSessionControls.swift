import SwiftUI

struct SettingsSessionControls: View {
    let presets: [TimeInterval]
    @Binding var defaultPreset: TimeInterval
    let maximum: TimeInterval
    let add: (TimeInterval) -> Void
    let remove: (TimeInterval) -> Void
    @State private var expanded = false
    @State private var newPreset = ""
    @State private var error: String?

    var body: some View {
        Section {
            Picker("Default duration", selection: $defaultPreset) {
                ForEach(presets, id: \.self) { preset in
                    Text(chipLabel(for: preset)).tag(preset)
                }
                if !presets.contains(defaultPreset) {
                    Text(chipLabel(for: defaultPreset)).tag(defaultPreset)
                }
            }
            .handCursor()
            DisclosureGroup("Manage durations", isExpanded: $expanded) {
                if expanded {
                    if presets.isEmpty {
                        Text("No saved durations").font(.callout).foregroundStyle(.secondary)
                    }
                    ForEach(presets, id: \.self) { preset in
                        HStack {
                            Text(chipLabel(for: preset)).monospacedDigit()
                            Spacer()
                            if preset == defaultPreset {
                                Text("Default").font(.caption).foregroundStyle(.secondary)
                            }
                            Button { remove(preset) } label: {
                                Image(systemName: "minus.circle")
                                    .frame(width: 40, height: 40)
                                    .contentShape(Rectangle())
                            }
                                .buttonStyle(.plain)
                                .handCursor()
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("Remove \(chipLabel(for: preset)) preset")
                        }
                    }
                    HStack {
                        TextField("", text: $newPreset, prompt: Text("e.g. 1h 30m"))
                            .labelsHidden()
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(addPreset)
                            .accessibilityLabel("New duration")
                        Button("Add", action: addPreset)
                            .handCursor()
                            .disabled(DurationParser.seconds(from: newPreset) == nil)
                    }
                    if let error { Text(error).font(.caption).foregroundStyle(.red) }
                    LabeledContent("Maximum", value: chipLabel(for: maximum))
                }
            }
            .animation(Motion.interface(), value: expanded)
        } header: {
            Text("Session")
        } footer: {
            Text("Left-click the menu bar eye to start this duration. Right-click for quick actions.")
        }
    }

    private func addPreset() {
        guard let seconds = DurationParser.seconds(from: newPreset) else { return }
        guard seconds <= maximum else {
            error = "Durations cannot exceed \(chipLabel(for: maximum))."
            return
        }
        error = nil
        add(seconds)
        newPreset = ""
    }
}
