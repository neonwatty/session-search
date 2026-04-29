import AppKit
import SwiftUI

struct SearchFooter: View {
    let resultCount: Int
    let hasCopiedResult: Bool
    let indexStats: IndexStats?

    var body: some View {
        HStack {
            if hasCopiedResult {
                Text("Copied!")
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
            } else {
                Text("\(resultCount) result\(resultCount == 1 ? "" : "s") \u{00B7} click to copy, dbl-click to open")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if let indexStats {
                Text("indexed \(indexStats.sessionCount) sessions")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
        }
    }
}
