//
//  DailyStats.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/28.
//

import Foundation

/// Daily statistics model for history statistics card
struct DailyStats: Identifiable {
    // MARK: - Properties

    /// Unique identifier (date string)
    let id: String

    /// The date for this statistic
    let date: Date

    /// Number of scans on this date
    let count: Int

    // MARK: - Computed Properties

    /// Display string for the date (e.g., "Today", "Yesterday", "Oct 25")
    var displayString: String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM dd"
            return formatter.string(from: date)
        }
    }

    /// Whether this is today
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    /// Whether this is yesterday
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(date)
    }

    // MARK: - Initialization

    init(date: Date, count: Int) {
        self.date = date
        self.count = count
        self.id = date.ISO8601Format()
    }
}

// MARK: - Comparable

extension DailyStats: Comparable {
    static func < (lhs: DailyStats, rhs: DailyStats) -> Bool {
        return lhs.date < rhs.date
    }
}
