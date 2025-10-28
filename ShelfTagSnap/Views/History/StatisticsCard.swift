//
//  StatisticsCard.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/27.
//

import SwiftUI

/// Statistics card showing scan counts and insights
struct StatisticsCard: View {
    // MARK: - Properties

    let totalCount: Int
    let todayCount: Int
    let weekCount: Int
    let monthCount: Int
    let topStore: String
    let topStoreCount: Int

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            // Statistics grid (4 cards)
            statisticsGrid

            // Quick insights
            if totalCount > 0 {
                quickInsights
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Statistics Grid

    private var statisticsGrid: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Total",
                value: totalCount,
                icon: "chart.bar.fill",
                color: .blue
            )

            StatCard(
                title: "Today",
                value: todayCount,
                icon: "calendar",
                color: .green
            )

            StatCard(
                title: "Week",
                value: weekCount,
                icon: "calendar.badge.clock",
                color: .orange
            )

            StatCard(
                title: "Month",
                value: monthCount,
                icon: "calendar.circle.fill",
                color: .purple
            )
        }
    }

    // MARK: - Quick Insights

    private var quickInsights: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.vertical, 4)

            HStack(spacing: 16) {
                // On fire indicator
                if todayCount >= 10 {
                    InsightBadge(
                        icon: "flame.fill",
                        text: "On Fire!",
                        color: .orange
                    )
                }

                // Top store
                if !topStore.isEmpty && topStoreCount > 0 {
                    InsightBadge(
                        icon: "star.fill",
                        text: "\(topStore) (\(topStoreCount))",
                        color: .yellow
                    )
                }

                Spacer()
            }
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: Int
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .accessibilityHidden(true)

            Text("\(value)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .monospacedDigit()

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value) scans")
    }
}

// MARK: - Insight Badge

struct InsightBadge: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
                .accessibilityHidden(true)

            Text(text)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(icon == "flame.fill" ? "High activity" : "Top store"): \(text)")
    }
}

// MARK: - Preview

#Preview("With Data") {
    ScrollView {
        VStack(spacing: 20) {
            StatisticsCard(
                totalCount: 156,
                todayCount: 12,
                weekCount: 48,
                monthCount: 89,
                topStore: "Walmart #1234",
                topStoreCount: 35
            )
            .padding()
        }
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("High Activity") {
    ScrollView {
        VStack(spacing: 20) {
            StatisticsCard(
                totalCount: 256,
                todayCount: 25,
                weekCount: 128,
                monthCount: 189,
                topStore: "Target Store",
                topStoreCount: 68
            )
            .padding()
        }
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Empty State") {
    ScrollView {
        VStack(spacing: 20) {
            StatisticsCard(
                totalCount: 0,
                todayCount: 0,
                weekCount: 0,
                monthCount: 0,
                topStore: "",
                topStoreCount: 0
            )
            .padding()
        }
    }
    .background(Color(.systemGroupedBackground))
}
