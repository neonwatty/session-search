import Foundation

private let relativeDateFormatter: RelativeDateTimeFormatter = {
    let f = RelativeDateTimeFormatter()
    f.unitsStyle = .abbreviated
    return f
}()

func relativeTime(_ date: Date) -> String {
    relativeDateFormatter.localizedString(for: date, relativeTo: Date())
}
