import SwiftUI

struct FlagPresetsSection: View {
    @ObservedObject var settings: AppSettings

    @State private var newFlag = ""
    @State private var isAddingFlag = false
    @State private var flagError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FLAG PRESETS")
                .font(.system(size: 10, weight: .medium))
                .tracking(0.5)
                .foregroundStyle(.secondary)

            presetsList
            addFlagControl
        }
    }

    private var presetsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(settings.flagPresets.enumerated()), id: \.element.id) { index, preset in
                FlagPresetRow(
                    preset: preset,
                    isEnabled: Binding(
                        get: { settings.flagPresets[index].enabled },
                        set: {
                            settings.flagPresets[index].enabled = $0
                            settings.save()
                        }
                    ),
                    onRemove: {
                        settings.flagPresets.remove(at: index)
                        settings.save()
                    }
                )

                if index < settings.flagPresets.count - 1 {
                    Divider().padding(.horizontal, 12)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }

    @ViewBuilder
    private var addFlagControl: some View {
        if isAddingFlag {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    TextField("--flag-name", text: $newFlag)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .onSubmit { addFlag() }
                    Button("Add") { addFlag() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.accentColor)
                    Button("Cancel") { cancelAdd() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)

                if let flagError {
                    Text(flagError)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
            }
        } else {
            Button(action: beginAdd) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.accentColor)
                    Text("Add flag preset...")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
    }

    private func beginAdd() {
        isAddingFlag = true
        flagError = nil
    }

    private func cancelAdd() {
        isAddingFlag = false
        newFlag = ""
        flagError = nil
    }

    private func addFlag() {
        let trimmed = newFlag.trimmingCharacters(in: .whitespaces)
        guard validateFlag(trimmed) else { return }

        settings.flagPresets.append(FlagPreset(flag: trimmed, enabled: false))
        settings.save()
        cancelAdd()
    }

    private func validateFlag(_ value: String) -> Bool {
        guard !value.isEmpty else {
            flagError = "Enter a CLI flag first."
            return false
        }
        guard value.hasPrefix("-") else {
            flagError = "Flags should start with '-' or '--'."
            return false
        }
        guard !hasUnclosedQuote(value) else {
            flagError = "Close the quote before adding this flag."
            return false
        }
        guard !settings.flagPresets.contains(where: { $0.flag == value }) else {
            flagError = "That flag preset already exists."
            return false
        }
        return true
    }

    private func hasUnclosedQuote(_ value: String) -> Bool {
        var quote: Character?
        var escaping = false
        for char in value {
            if escaping {
                escaping = false
                continue
            }
            if char == "\\" {
                escaping = true
                continue
            }
            if let activeQuote = quote {
                if char == activeQuote {
                    quote = nil
                }
            } else if char == "'" || char == "\"" {
                quote = char
            }
        }
        return quote != nil
    }
}

private struct FlagPresetRow: View {
    let preset: FlagPreset
    @Binding var isEnabled: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack {
            Text(preset.flag)
                .font(.system(size: 12, design: .monospaced))
            Spacer()
            Button(action: onRemove) {
                Image(systemName: "minus.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
