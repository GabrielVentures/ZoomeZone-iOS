//
//  DateFilterType.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/27.
//

import Foundation

/// Date filter type for history records
enum DateFilterType: Equatable, Hashable {
    case today
    case yesterday
    case last7Days
    case last30Days
    case allTime
    case specificDate(Date)
    case customRange(start: Date, end: Date)

    // MARK: - Custom Equatable Implementation

    /// Custom equality comparison that normalizes dates to start of day
    static func == (lhs: DateFilterType, rhs: DateFilterType) -> Bool {
        switch (lhs, rhs) {
        case (.today, .today),
             (.yesterday, .yesterday),
             (.last7Days, .last7Days),
             (.last30Days, .last30Days),
             (.allTime, .allTime):
            return true

        case (.specificDate(let lhsDate), .specificDate(let rhsDate)):
            // Compare dates at day granularity (ignore time components)
            let calendar = Calendar.current
            return calendar.isDate(lhsDate, inSameDayAs: rhsDate)

        case (.customRange(let lhsStart, let lhsEnd), .customRange(let rhsStart, let rhsEnd)):
            // Compare ranges at day granularity
            let calendar = Calendar.current
            return calendar.isDate(lhsStart, inSameDayAs: rhsStart) &&
                   calendar.isDate(lhsEnd, inSameDayAs: rhsEnd)

        default:
            return false
        }
    }

    // MARK: - Custom Hashable Implementation

    /// Custom hash that normalizes dates to start of day
    func hash(into hasher: inout Hasher) {
        let calendar = Calendar.current

        switch self {
        case .today:
            hasher.combine("today")
        case .yesterday:
            hasher.combine("yesterday")
        case .last7Days:
            hasher.combine("last7Days")
        case .last30Days:
            hasher.combine("last30Days")
        case .allTime:
            hasher.combine("allTime")
        case .specificDate(let date):
            hasher.combine("specificDate")
            // Hash only the day components, not the exact timestamp
            let startOfDay = calendar.startOfDay(for: date)
            hasher.combine(startOfDay.timeIntervalSince1970)
        case .customRange(let start, let end):
            hasher.combine("customRange")
            let startOfStartDay = calendar.startOfDay(for: start)
            let startOfEndDay = calendar.startOfDay(for: end)
            hasher.combine(startOfStartDay.timeIntervalSince1970)
            hasher.combine(startOfEndDay.timeIntervalSince1970)
        }
    }

    var title: String {
        switch self {
        case .today:
            return "Today"
        case .yesterday:
            return "Yesterday"
        case .last7Days:
            return "Last 7 Days"
        case .last30Days:
            return "Last 30 Days"
        case .allTime:
            return "All Time"
        case .specificDate(let date):
            return date.formatted(date: .abbreviated, time: .omitted)
        case .customRange(let start, let end):
            return "\(start.formatted(date: .abbreviated, time: .omitted)) - \(end.formatted(date: .abbreviated, time: .omitted))"
        }
    }

    var icon: String {
        switch self {
        case .today:
            return "sun.max.fill"
        case .yesterday:
            return "moon.fill"
        case .last7Days:
            return "calendar.badge.clock"
        case .last30Days:
            return "calendar"
        case .allTime:
            return "calendar.circle.fill"
        case .specificDate:
            return "calendar.day.timeline.left"
        case .customRange:
            return "calendar.badge.plus"
        }
    }

    /// Get date range for filtering
    func dateRange(from referenceDate: Date = Date()) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let endOfToday = calendar.startOfDay(for: referenceDate).addingTimeInterval(86400) // Next day 00:00

        switch self {
        case .today:
            let startOfToday = calendar.startOfDay(for: referenceDate)
            return (startOfToday, endOfToday)

        case .yesterday:
            let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: referenceDate))!
            let endOfYesterday = calendar.startOfDay(for: referenceDate)
            return (startOfYesterday, endOfYesterday)

        case .last7Days:
            let start = calendar.date(byAdding: .day, value: -7, to: endOfToday)!
            return (start, endOfToday)

        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -30, to: endOfToday)!
            return (start, endOfToday)

        case .allTime:
            // From 2020 to today
            let start = calendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!
            return (start, endOfToday)

        case .specificDate(let date):
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = startOfDay.addingTimeInterval(86400)
            return (startOfDay, endOfDay)

        case .customRange(let start, let end):
            let startOfDay = calendar.startOfDay(for: start)
            let endOfDay = calendar.startOfDay(for: end).addingTimeInterval(86400)
            return (startOfDay, endOfDay)
        }
    }

    /// Check if a date is within this filter
    func contains(_ date: Date) -> Bool {
        let range = dateRange()
        return date >= range.start && date < range.end
    }
}

/// Date group for organizing records by date
struct DateGroup: Identifiable {
    let id: String
    let date: Date
    var records: [ScanRecord]
    var isExpanded: Bool

    /// Top stores in this date group
    var topStores: [(name: String, count: Int)] {
        let storeGroups = Dictionary(grouping: records) { record in
            record.storeLocation ?? "Unknown"
        }

        return storeGroups
            .map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(3)
            .map { $0 }
    }

    /// Date display string (e.g., "Sunday, Oct 27")
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    /// Short date string (e.g., "Oct 27")
    var shortDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    /// Is today
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    /// Is yesterday
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(date)
    }

    init(date: Date, records: [ScanRecord], isExpanded: Bool = false) {
        self.id = ISO8601DateFormatter().string(from: date)
        self.date = date
        self.records = records
        self.isExpanded = isExpanded
    }
}

/// Specific date item for the date picker list
struct SpecificDateItem: Identifiable {
    let id: String
    let date: Date
    let count: Int

    var displayString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    var shortDisplayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    init(date: Date, count: Int) {
        self.id = ISO8601DateFormatter().string(from: date)
        self.date = date
        self.count = count
    }
}
