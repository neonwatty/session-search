import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    let store: SessionStore
    let onBack: () -> Void

    @State private var indexStats: IndexStats?
    @State private var isRebuilding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(14)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    terminalSection
                    FlagPresetsSection(settings: settings)
                    indexSection
                    refreshSection
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
        .onReceive(NotificationCenter.default.publisher(for: .sessionSearchIndexDidChange)) { _ in
            Task { await refreshStats() }
        }
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
                        if let lastIndexedAt = stats.lastIndexedAt {
                            Text("Last indexed \(relativeTime(lastIndexedAt))")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
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
        let projectsDir = AppDelegate.projectsDirectoryPath()
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

}
