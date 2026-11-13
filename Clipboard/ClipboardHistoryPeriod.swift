import Foundation

enum ClipboardHistoryPeriod: String, CaseIterable, Identifiable {
    case all = "Any time"
    case today = "Today"
    case week = "Past 7 days"
    case month = "Past 30 days"

    var id: String { rawValue }

    var startDate: Date? {
        switch self {
        case .all: return nil
        case .today: return Calendar.current.startOfDay(for: Date())
        case .week: return Calendar.current.date(byAdding: .day, value: -7, to: Date())
        case .month: return Calendar.current.date(byAdding: .day, value: -30, to: Date())
        }
    }
}
