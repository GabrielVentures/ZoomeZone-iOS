//
//  StatisticsCardView.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/28.
//

import SwiftUI

/// Statistics card view showing daily scan counts for the last 14 days
struct StatisticsCardView: View {
    // MARK: - Properties

    /// Daily statistics (last 14 days, sorted by date descending)
    let dailyStats: [DailyStats]

    /// Total count (sum of all statistics)
    let totalCount: Int

    /// Is card expanded
    @State private var isExpanded: Bool = true

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header (always visible)
            headerView
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }

            // Expanded content (statistics grid)
            if isExpanded {
                statisticsGrid
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.blue)

            // Title and count
            VStack(alignment: .leading, spacing: 2) {
                Text("Statistics")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)

                Text("\(dailyStats.count) days • \(totalCount) scans")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Expand/collapse icon
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Statistics Grid

    private var statisticsGrid: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal, 16)

            // Grid content
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ],
                spacing: 8
            ) {
                ForEach(dailyStats) { stat in
                    statisticsItemView(stat)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Statistics Item View

    private func statisticsItemView(_ stat: DailyStats) -> some View {
        HStack(spacing: 8) {
            // Date label
            Text(stat.displayString)
                .font(.system(size: 14, weight: stat.isToday || stat.isYesterday ? .semibold : .regular))
                .foregroundColor(stat.isToday || stat.isYesterday ? .primary : .secondary)
                .lineLimit(1)

            Spacer(minLength: 4)

            // Count badge
            Text("\(stat.count)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .frame(minWidth: 24, minHeight: 20)
                .padding(.horizontal, 6)
                .background(countColor(for: stat.count))
                .cornerRadius(10)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }

    // MARK: - Helper Methods

    /// Get color for count badge based on value
    private func countColor(for count: Int) -> Color {
        switch count {
        case 0:
            return Color.gray.opacity(0.6)
        case 1...5:
            return Color.blue
        case 6...10:
            return Color.green
        default:
            return Color.orange
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleStats = [
        DailyStats(date: Date(), count: 12),
        DailyStats(date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, count: 8),
        DailyStats(date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!, count: 5),
        DailyStats(date: Calendar.current.date(byAdding: .day, value: -3, to: Date())!, count: 3),
        DailyStats(date: Calendar.current.date(byAdding: .day, value: -4, to: Date())!, count: 0),
        DailyStats(date: Calendar.current.date(byAdding: .day, value: -5, to: Date())!, count: 7),
        DailyStats(date: Calendar.current.date(byAdding: .day, value: -6, to: Date())!, count: 4),
        DailyStats(date: Calendar.current.date(byAdding: .day, value: -7, to: Date())!, count: 2),
        DailyStats(date: Calendar.current.date(byAdding: .day, value: -8, to: Date())!, count: 6),
        DailyStats(date: Calendar.current.date(byAdding: .day, value: -9, to: Date())!, count: 1),
        DailyStats(date: Calendar.current.date(byAdding: .day, value: -10, to: Date())!, count: 9),
        DailyStats(date: Calendar.current.date(byAdding: .day, value: -11, to: Date())!, count: 3),
        DailyStats(date: Calendar.current.date(byAdding: .day, value: -12, to: Date())!, count: 5),
        DailyStats(date: Calendar.current.date(byAdding: .day, value: -13, to: Date())!, count: 2)
    ]

    return ScrollView {
        VStack {
            StatisticsCardView(
                dailyStats: sampleStats,
                totalCount: sampleStats.reduce(0) { $0 + $1.count }
            )

            Spacer()
        }
    }
    .background(Color(.systemGroupedBackground))
}
