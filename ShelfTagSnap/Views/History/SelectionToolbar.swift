//
//  SelectionToolbar.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/24.
//

import SwiftUI

/// Floating selection toolbar for History list
///
/// Design inspired by Apple Photos selection mode
/// Features:
/// - Frosted glass background (.ultraThinMaterial)
/// - Rounded corners with shadow
/// - Spring animation on enter/exit
/// - Three action buttons: Select All/Deselect All, Delete, Export
struct SelectionToolbar: View {
    // MARK: - Properties

    let selectedCount: Int
    let totalCount: Int
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    let onDelete: () -> Void
    let onExport: () -> Void
    let isExporting: Bool

    // MARK: - Computed Properties

    private var allSelected: Bool {
        selectedCount == totalCount
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 20) {
            // Select All / Deselect All Button
            Button {
                if allSelected {
                    onDeselectAll()
                } else {
                    onSelectAll()
                }
                HapticFeedbackManager.shared.light()
            } label: {
                Text(allSelected ? Strings.History.deselectAll : Strings.History.selectAll)
                    .font(.body)
                    .fontWeight(.medium)
            }
            .disabled(totalCount == 0)
            .opacity(totalCount == 0 ? 0.4 : 1.0)

            Spacer()

            // Delete Button
            Button(role: .destructive) {
                onDelete()
                HapticFeedbackManager.shared.medium()
            } label: {
                Label(Strings.Export.deleteSelected, systemImage: "trash")
                    .font(.body)
                    .fontWeight(.medium)
            }
            .disabled(selectedCount == 0)
            .opacity(selectedCount == 0 ? 0.4 : 1.0)

            Spacer()

            // Export Button
            Button {
                onExport()
                HapticFeedbackManager.shared.light()
            } label: {
                if isExporting {
                    ProgressView()
                        .scaleEffect(0.9)
                } else {
                    Label(Strings.History.export, systemImage: "square.and.arrow.up")
                        .font(.body)
                        .fontWeight(.medium)
                }
            }
            .disabled(selectedCount == 0 || isExporting)
            .opacity(selectedCount == 0 || isExporting ? 0.4 : 1.0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Selection toolbar")
    }
}

// MARK: - Preview

#Preview("Some Selected") {
    VStack {
        Spacer()

        SelectionToolbar(
            selectedCount: 3,
            totalCount: 10,
            onSelectAll: { print("Select All") },
            onDeselectAll: { print("Deselect All") },
            onDelete: { print("Delete") },
            onExport: { print("Export") },
            isExporting: false
        )
        .padding(.bottom, 80)
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("All Selected") {
    VStack {
        Spacer()

        SelectionToolbar(
            selectedCount: 10,
            totalCount: 10,
            onSelectAll: { print("Select All") },
            onDeselectAll: { print("Deselect All") },
            onDelete: { print("Delete") },
            onExport: { print("Export") },
            isExporting: false
        )
        .padding(.bottom, 80)
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Exporting") {
    VStack {
        Spacer()

        SelectionToolbar(
            selectedCount: 5,
            totalCount: 10,
            onSelectAll: { print("Select All") },
            onDeselectAll: { print("Deselect All") },
            onDelete: { print("Delete") },
            onExport: { print("Export") },
            isExporting: true
        )
        .padding(.bottom, 80)
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Empty List") {
    VStack {
        Spacer()

        SelectionToolbar(
            selectedCount: 0,
            totalCount: 0,
            onSelectAll: { print("Select All") },
            onDeselectAll: { print("Deselect All") },
            onDelete: { print("Delete") },
            onExport: { print("Export") },
            isExporting: false
        )
        .padding(.bottom, 80)
    }
    .background(Color(.systemGroupedBackground))
}
