import Foundation

struct DateWindow: Hashable, Sendable {
    var start: Date
    var end: Date

    func contains(_ date: Date) -> Bool {
        date >= start && date < end
    }

    static func covering(startDay: Date, endDay: Date, calendar: Calendar) -> DateWindow {
        let start = calendar.startOfDay(for: min(startDay, endDay))
        let inclusiveEnd = calendar.startOfDay(for: max(startDay, endDay))
        let exclusiveEnd = calendar.date(byAdding: .day, value: 1, to: inclusiveEnd) ?? inclusiveEnd.addingTimeInterval(86_400)
        return DateWindow(start: start, end: exclusiveEnd)
    }
}

enum PeriodPreset: String, CaseIterable, Identifiable, Sendable {
    case today
    case week
    case month
    case year
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .week: "This week"
        case .month: "This month"
        case .year: "This year"
        case .custom: "Custom"
        }
    }
}

enum PeriodMath {
    static func window(preset: PeriodPreset, customStart: Date, customEnd: Date, now: Date, calendar: Calendar) -> DateWindow {
        switch preset {
        case .today:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
            return DateWindow(start: start, end: end)
        case .week:
            if let interval = calendar.dateInterval(of: .weekOfYear, for: now) {
                return DateWindow(start: interval.start, end: interval.end)
            }
            return window(preset: .today, customStart: customStart, customEnd: customEnd, now: now, calendar: calendar)
        case .month:
            if let interval = calendar.dateInterval(of: .month, for: now) {
                return DateWindow(start: interval.start, end: interval.end)
            }
            return window(preset: .today, customStart: customStart, customEnd: customEnd, now: now, calendar: calendar)
        case .year:
            if let interval = calendar.dateInterval(of: .year, for: now) {
                return DateWindow(start: interval.start, end: interval.end)
            }
            return window(preset: .today, customStart: customStart, customEnd: customEnd, now: now, calendar: calendar)
        case .custom:
            return DateWindow.covering(startDay: customStart, endDay: customEnd, calendar: calendar)
        }
    }

    static func previous(of window: DateWindow, calendar: Calendar) -> DateWindow {
        let length = window.end.timeIntervalSince(window.start)
        let start = window.start.addingTimeInterval(-length)
        return DateWindow(start: start, end: window.start)
    }
}
