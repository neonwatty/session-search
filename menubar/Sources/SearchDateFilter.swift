import Foundation

enum SearchDateFilter: String, CaseIterable, Identifiable {
    case all
    case day
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "Any time"
        case .day: "Past day"
        case .week: "Past week"
        case .month: "Past month"
        }
    }

    var cutoffDate: Date? {
        let now = Date()
        switch self {
        case .all:
            return nil
        case .day:
            return Calendar.current.date(byAdding: .day, value: -1, to: now)
        case .week:
            return Calendar.current.date(byAdding: .day, value: -7, to: now)
        case .month:
            return Calendar.current.date(byAdding: .month, value: -1, to: now)
        }
    }
}
