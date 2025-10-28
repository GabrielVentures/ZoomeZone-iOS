//
//  EmptyFilterResultsView.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/27.
//

import SwiftUI

/// Empty filter results view - shown when filter returns no results
struct EmptyFilterResultsView: View {
    // MARK: - Properties

    let currentFilter: DateFilterType
    let suggestions: [(filter: DateFilterType, count: Int)]
    let onSelectFilter: (DateFilterType) -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            Image(systemName: "magnifyingglass")
                .font(.system(size: 70))
                .foregroundStyle(.gray.gradient)
                .accessibilityHidden(true)

            // Message
            VStack(spacing: 12) {
                Text("No scans found")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("No records match the filter: \(currentFilter.title)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Smart suggestions
            if !suggestions.isEmpty {
                VStack(spacing: 16) {
                    Text("Try these dates:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    VStack(spacing: 12) {
                        ForEach(suggestions, id: \.filter) { suggestion in
                            suggestionButton(filter: suggestion.filter, count: suggestion.count)
                        }
                    }
                }
                .padding(.top, 8)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Suggestion Button

    private func suggestionButton(filter: DateFilterType, count: Int) -> some View {
        Button {
            onSelectFilter(filter)
        } label: {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: filter.icon)
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
                    .frame(width: 24)

                // Filter name
                Text(filter.title)
                    .font(.body)
                    .foregroundColor(.primary)

                Spacer()

                // Count badge
                Text("\(count)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.blue)
                    )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview("With Suggestions") {
    EmptyFilterResultsView(
        currentFilter: .yesterday,
        suggestions: [
            (.today, 35),
            (.last7Days, 127),
            (.last30Days, 543)
        ],
        onSelectFilter: { filter in
            print("Selected: \(filter.title)")
        }
    )
    .background(Color(.systemGroupedBackground))
}

#Preview("No Suggestions") {
    EmptyFilterResultsView(
        currentFilter: .last30Days,
        suggestions: [],
        onSelectFilter: { _ in }
    )
    .background(Color(.systemGroupedBackground))
}

#Preview("Specific Date") {
    EmptyFilterResultsView(
        currentFilter: .specificDate(Date().addingTimeInterval(-86400 * 5)),
        suggestions: [
            (.today, 42),
            (.yesterday, 28)
        ],
        onSelectFilter: { _ in }
    )
    .background(Color(.systemGroupedBackground))
}
