//
//  ExportPreviewView.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//

import SwiftUI

/// Export preview view
///

struct ExportPreviewView: View {
    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - Properties

    let statistics: ExportStatistics
    let onConfirm: () -> Void
    @Binding var exportProgress: ExportProgress?

    // MARK: - State

    @State private var isExporting: Bool = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // Icon
                    iconSection

                    // Statistics
                    statisticsSection

                    // Description
                    descriptionSection

                    // Buttons or Loading
                    if isExporting {
                        loadingSection
                    } else {
                        buttonsSection
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(Strings.Export.exportConfirmation)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !isExporting {
                        Button(Strings.Common.cancel) {
                            dismiss()
                        }
                    }
                }
            }
            .interactiveDismissDisabled(isExporting)
        }
    }

    // MARK: - Icon Section

    private var iconSection: some View {
        Image(systemName: "doc.text.fill")
            .font(.system(size: 60))
            .foregroundStyle(
                LinearGradient(
                    colors: [.blue, .cyan],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .accessibilityHidden(true)
    }

    // MARK: - Statistics Section

    private var statisticsSection: some View {
        VStack(spacing: 16) {

            // Title
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                    .accessibilityHidden(true)

                Text(Strings.Export.exportStatistics)
                    .font(.headline)

                Spacer()
            }

            VStack(spacing: 16) {

                // Total records
                StatisticRow(
                    icon: "number",
                    title: Strings.Export.totalRecordsLabel,
                    value: "\(statistics.totalRecords) \(Strings.History.totalRecords)",
                    iconColor: .blue
                )

                // Date range
                if let dateRange = statistics.formattedDateRange {
                    StatisticRow(
                        icon: "calendar",
                        title: Strings.Export.dateRange,
                        value: dateRange,
                        iconColor: .green
                    )
                }

                // Estimated file size
                StatisticRow(
                    icon: "doc.fill",
                    title: Strings.Export.estimatedSize,
                    value: statistics.formattedFileSize,
                    iconColor: .orange
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(Strings.Export.csvFileWillContain)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Text(Strings.Export.chineseEncodingSupport)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(Strings.Export.canBeOpenedInExcel)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Buttons Section

    private var buttonsSection: some View {
        VStack(spacing: 12) {

            // Export button
            Button {
                performExport()
            } label: {
                Label(Strings.Export.exportButton, systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .accessibilityLabel(Strings.Export.exportCSVFile)

            // Cancel button
            Button {
                dismiss()
            } label: {
                Text(Strings.Common.cancel)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
            }
            .accessibilityLabel(Strings.Export.cancelExport)
        }
    }

    // MARK: - Loading Section

    private var loadingSection: some View {
        VStack(spacing: 20) {
            // Progress view
            if let progress = exportProgress {
                VStack(spacing: 12) {
                    ProgressView(value: progress.percentage, total: 1.0)
                        .progressViewStyle(.linear)
                        .tint(.blue)

                    Text(progress.status)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("\(progress.currentItem)/\(progress.totalItems)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.blue)

                    Text("Preparing export...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .accessibilityLabel("Exporting data")
    }

    // MARK: - Helper Methods

    private func performExport() {
        isExporting = true
        onConfirm()

        // Note: dismiss() is called by parent view after export completes
    }
}

// MARK: - Statistic Row

struct StatisticRow: View {
    let icon: String
    let title: String
    let value: String
    let iconColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 16) {

            // Icon
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(iconColor.opacity(0.15))
                )
                .accessibilityHidden(true)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.body)
                    .fontWeight(.semibold)
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}

// MARK: - Preview

#Preview {
    ExportPreviewView(
        statistics: ExportStatistics(
            totalRecords: 123,
            dateRange: (
                start: Date(timeIntervalSince1970: 1704067200),
                end: Date(timeIntervalSince1970: 1729641600)
            ),
            estimatedFileSize: 25000
        ),
        onConfirm: {
            print("Export confirmed")
        },
        exportProgress: .constant(nil)
    )
}

#Preview("Empty Records") {
    ExportPreviewView(
        statistics: ExportStatistics(
            totalRecords: 0,
            dateRange: nil,
            estimatedFileSize: 100
        ),
        onConfirm: {
            print("Export confirmed")
        },
        exportProgress: .constant(nil)
    )
}

#Preview("Large Dataset") {
    ExportPreviewView(
        statistics: ExportStatistics(
            totalRecords: 15000,
            dateRange: (
                start: Date(timeIntervalSince1970: 1672531200),
                end: Date(timeIntervalSince1970: 1729641600)
            ),
            estimatedFileSize: 3000000
        ),
        onConfirm: {
            print("Export confirmed")
        },
        exportProgress: .constant(nil)
    )
}
