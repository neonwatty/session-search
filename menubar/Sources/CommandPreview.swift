import SwiftUI

struct CommandPreview: View {
    let command: String

    var body: some View {
        Text(command)
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(Color.accentColor)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
            .cornerRadius(4)
    }
}
