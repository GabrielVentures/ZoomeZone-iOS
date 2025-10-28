//
//  DateSectionHeader.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/27.
//

import SwiftUI

/// Date section header with expand/collapse functionality
struct DateSectionHeader: View {
    // MARK: - Properties

    let dateGroup: DateGroup
    let onToggle: () -> Void

    // MARK: - Body

    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 8) {
                // Main header
                HStack(spacing: 12) {
                    // Date icon
                    ZStack {
                        Circle()
                            .fill(dateColor.opacity(0.1))
                            .frame(width: 40, height: 40)

                        Image(systemName: dateIcon)
                            .font(.system(size: 18))
                            .foregroundColor(dateColor)
                    }

                    // Date text
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dateDisplayText)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)

                        if dateGroup.isToday || dateGroup.isYesterday {
                            Text(dateGroup.dateString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Count badge
                    Text("\(dateGroup.records.count)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(dateColor)
                        )

                    // Expand/collapse icon
                    Image(systemName: dateGroup.isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }

                // Top stores summary (only when collapsed)
                if !dateGroup.isExpanded && !dateGroup.topStores.isEmpty {
                    topStoresSummary
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Top Stores Summary

    private var topStoresSummary: some View {
        VStack(spacing: 6) {
            Divider()
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(dateGroup.topStores.prefix(2)), id: \.name) { store in
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)

                        Text(store.name)
                            .font(.caption)
                            .foregroundColor(.primary)

                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("\(store.count) scans")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                }

                if dateGroup.topStores.count > 2 {
                    Text("+\(dateGroup.topStores.count - 2) more stores")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var dateDisplayText: String {
        if dateGroup.isToday {
            return "Today"
        } else if dateGroup.isYesterday {
            return "Yesterday"
        } else {
            return dateGroup.dateString
        }
    }

    private var dateIcon: String {
        if dateGroup.isToday {
            return "sun.max.fill"
        } else if dateGroup.isYesterday {
            return "moon.fill"
        } else {
            return "calendar"
        }
    }

    private var dateColor: Color {
        if dateGroup.isToday {
            return .green
        } else if dateGroup.isYesterday {
            return .orange
        } else {
            return .blue
        }
    }
}

// MARK: - Preview

#Preview("Today - Collapsed") {
    VStack(spacing: 16) {
        DateSectionHeader(
            dateGroup: DateGroup(
                date: Date(),
                records: Array(repeating: ScanRecord(
                    username: "test",
                    merchant: "Walmart",
                    barcode: "123456",
                    location: nil,
                    storeLocation: "Walmart #1234",
                    imageFilename: "test.jpg"
                ), count: 35),
                isExpanded: false
            ),
            onToggle: {}
        )
        .padding()

        Spacer()
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Yesterday - Expanded") {
    VStack(spacing: 16) {
        DateSectionHeader(
            dateGroup: DateGroup(
                date: Date().addingTimeInterval(-86400),
                records: Array(repeating: ScanRecord(
                    username: "test",
                    merchant: "Target",
                    barcode: "123456",
                    location: nil,
                    storeLocation: "Target Store",
                    imageFilename: "test.jpg"
                ), count: 127),
                isExpanded: true
            ),
            onToggle: {}
        )
        .padding()

        Spacer()
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Regular Date") {
    VStack(spacing: 16) {
        DateSectionHeader(
            dateGroup: DateGroup(
                date: Date().addingTimeInterval(-86400 * 5),
                records: Array(repeating: ScanRecord(
                    username: "test",
                    merchant: "Costco",
                    barcode: "123456",
                    location: nil,
                    storeLocation: "Costco",
                    imageFilename: "test.jpg"
                ), count: 89),
                isExpanded: false
            ),
            onToggle: {}
        )
        .padding()

        Spacer()
    }
    .background(Color(.systemGroupedBackground))
}
