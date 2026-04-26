import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    let store: SessionStore
    let onBack: () -> Void

    @State private var newFlag = ""
    @State private var isAddingFlag = false
    @State private var indexStats: IndexStats?
    @State private var isRebuilding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(14)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    terminalSection
                    flagPresetsSection
                    indexSection
                    refreshSection
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            Text("Settings")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
        }
    }

    private var terminalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TERMINAL")
                .font(.system(size: 10, weight: .medium))
                .tracking(0.5)
                .foregroundStyle(.secondary)

            Picker(
                "",
                selection: Binding(
                    get: { settings.terminalApp },
                    set: {
                        settings.terminalApp = $0
                        settings.save()
                    }
                )
            ) {
                ForEach(TerminalApp.allCases) { app in
                    Text(app.rawValue).tag(app)
                }
            }
            .pickerStyle(.menu)
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
        }
    }

    private var flagPresetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FLAG PRESETS")
                .font(.system(size: 10, weight: .medium))
                .tracking(0.5)
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(settings.flagPresets.enumerated()), id: \.element.id) { index, preset in
                    HStack {
                        Text(preset.flag)
                            .font(.system(size: 12, design: .monospaced))

                        Spacer()

                        Button(action: {
                            settings.flagPresets.remove(at: index)
                            settings.save()
                        }) {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)

                        Toggle(
                            "",
                            isOn: Binding(
                                get: { settings.flagPresets[index].enabled },
                                set: {
                                    settings.flagPresets[index].enabled = $0
                                    settings.save()
                                }
                            )
                        )
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

                    if index < settings.flagPresets.count - 1 {
                        Divider().padding(.horizontal, 12)
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)

            if isAddingFlag {
                HStack(spacing: 8) {
                    TextField("--flag-name", text: $newFlag)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .onSubmit { addFlag() }
                    Button("Add") { addFlag() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.accentColor)
                    Button("Cancel") {
                        isAddingFlag = false
                        newFlag = ""
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
            } else {
                Button(action: { isAddingFlag = true }) {
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
    }

    private var indexSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("INDEX")
                .font(.system(size: 10, weight: .medium))
                .tracking(0.5)
                .foregroundStyle(.secondary)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let stats = indexStats {
                        Text("\(stats.projectCount) projects \u{00B7} \(stats.sessionCount) sessions")
                            .font(.system(size: 12))
                    }
                }
                Spacer()
                if isRebuilding {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button("Rebuild") { rebuild() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
        }
        .task { await refreshStats() }
    }

    private func rebuild() {
        isRebuilding = true
        let projectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects").path
        Task.detached { [store] in
            try? store.indexAll(projectsDir: projectsDir)
            await MainActor.run {
                isRebuilding = false
                Task { await refreshStats() }
            }
        }
    }

    private func refreshStats() async {
        indexStats = try? await Task.detached { [store] in
            try store.stats()
        }.value
    }

    private var refreshSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("REFRESH INTERVAL")
                .font(.system(size: 10, weight: .medium))
                .tracking(0.5)
                .foregroundStyle(.secondary)

            Picker(
                "",
                selection: Binding(
                    get: { settings.refreshIntervalMinutes },
                    set: {
                        settings.refreshIntervalMinutes = $0
                        settings.save()
                    }
                )
            ) {
                Text("Every 5 minutes").tag(5)
                Text("Every 10 minutes").tag(10)
                Text("Every 15 minutes").tag(15)
                Text("Every 30 minutes").tag(30)
            }
            .pickerStyle(.menu)
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
        }
    }

    private func addFlag() {
        let trimmed = newFlag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        settings.flagPresets.append(FlagPreset(flag: trimmed, enabled: false))
        settings.save()
        newFlag = ""
        isAddingFlag = false
    }
}
