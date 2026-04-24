import SwiftUI

func highlightedSnippet(_ raw: String) -> Text {
    let highlightColor = Color(red: 0.93, green: 0.55, blue: 0.24)
    var result = Text("")

    let segments = raw.components(separatedBy: "<<")
    for (i, segment) in segments.enumerated() {
        if i == 0 {
            result = result + Text(segment).foregroundColor(.secondary)
        } else {
            let parts = segment.components(separatedBy: ">>")
            if parts.count >= 2 {
                result = result + Text(parts[0]).foregroundColor(highlightColor).bold()
                result = result + Text(parts[1...].joined(separator: ">>")).foregroundColor(.secondary)
            } else {
                result = result + Text(segment).foregroundColor(.secondary)
            }
        }
    }

    return result
}
