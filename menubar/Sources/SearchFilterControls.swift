import SwiftUI

struct SearchFilterControls: View {
    let projectOptions: [String]
    @Binding var selectedProject: String?
    @Binding var dateFilter: SearchDateFilter
    let onChange: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Picker(
                "",
                selection: Binding(
                    get: { selectedProject ?? "" },
                    set: {
                        selectedProject = $0.isEmpty ? nil : $0
                        onChange()
                    }
                )
            ) {
                Text("All projects").tag("")
                ForEach(projectOptions, id: \.self) { project in
                    Text(resolveProjectName(project)).tag(project)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)

            Picker(
                "",
                selection: Binding(
                    get: { dateFilter },
                    set: {
                        dateFilter = $0
                        onChange()
                    }
                )
            ) {
                ForEach(SearchDateFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 118)
        }
        .font(.system(size: 11))
    }
}
