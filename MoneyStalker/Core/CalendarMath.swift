import Foundation

enum RecurrenceCalendar {
    static func nextDate(after date: Date, frequency: RecurrenceFrequency, interval: Int, calendar: Calendar) -> Date? {
        let step = max(1, interval)
        switch frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: step, to: date)
        case .weekly:
            return calendar.date(byAdding: .day, value: 7 * step, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: step, to: date)
        case .yearly:
            return calendar.date(byAdding: .year, value: step, to: date)
        }
    }

    static func occurrenceKey(ruleID: UUID, date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let year = parts.year ?? 0
        let month = parts.month ?? 0
        let day = parts.day ?? 0
        let hour = parts.hour ?? 0
        let minute = parts.minute ?? 0
        return "\(ruleID.uuidString)|\(year)-\(month)-\(day)-\(hour)-\(minute)"
    }
}

struct MonthCell: Identifiable, Hashable, Sendable {
    var id: String
    var date: Date?
}

enum MonthGridBuilder {
    static func cells(for month: Date, calendar: Calendar) -> [MonthCell] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let dayRange = calendar.range(of: .day, in: .month, for: interval.start) else {
            return []
        }
        let weekday = calendar.component(.weekday, from: interval.start)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var cells: [MonthCell] = []
        for index in 0..<leading {
            cells.append(MonthCell(id: "lead-\(interval.start.timeIntervalSinceReferenceDate)-\(index)", date: nil))
        }
        for day in dayRange {
            var parts = calendar.dateComponents([.year, .month], from: interval.start)
            parts.day = day
            parts.hour = 12
            let date = calendar.date(from: parts)
            cells.append(MonthCell(id: "day-\(parts.year ?? 0)-\(parts.month ?? 0)-\(day)", date: date))
        }
        var tail = 0
        while cells.count % 7 != 0 {
            cells.append(MonthCell(id: "tail-\(interval.start.timeIntervalSinceReferenceDate)-\(tail)", date: nil))
            tail += 1
        }
        return cells
    }
}
