//
//  HistoryRow.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//

import SwiftUI

/// History record row component

struct HistoryRow: View {
    // MARK: - Properties

    let record: ScanRecord
    let image: UIImage?
    let layoutMode: HistoryLayoutMode

    // MARK: - Private Properties

    private var thumbnailSize: CGFloat {
        switch layoutMode {
        case .compact:
            return 50
        case .comfortable:
            return 70
        case .gallery:
            return 60 // Not used in gallery mode
        }
    }

    private var cornerRadius: CGFloat {
        switch layoutMode {
        case .compact:
            return 6
        case .comfortable:
            return 10
        case .gallery:
            return 8
        }
    }

    // MARK: - Body

    var body: some View {
        switch layoutMode {
        case .compact:
            compactLayout
        case .comfortable:
            comfortableLayout
        case .gallery:
            compactLayout // Fallback, should use gallery grid instead
        }
    }

    // MARK: - Compact Layout

    private var compactLayout: some View {
        HStack(spacing: 12) {
            // Thumbnail

            thumbnail

            // Information area

            VStack(alignment: .leading, spacing: 4) {
                // Barcode

                barcodeText

                // Time and location (inline)

                HStack(spacing: 8) {
                    timeText

                    if let location = record.storeLocation, !location.isEmpty {
                        locationText(location)
                    }
                }
            }

            Spacer()

            // Arrow indicator

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.5))
                .accessibilityHidden(true)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint(Strings.History.viewDetails)
    }

    // MARK: - Comfortable Layout

    private var comfortableLayout: some View {
        HStack(spacing: 16) {
            // Thumbnail

            thumbnail

            // Information area

            VStack(alignment: .leading, spacing: 6) {
                // Merchant name

                merchantName

                // Barcode

                barcodeText

                // Time and location

                HStack(spacing: 12) {
                    timeText

                    if let location = record.storeLocation, !location.isEmpty {
                        locationText(location)
                    }
                }
            }

            Spacer()

            // Arrow indicator

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.5))
                .accessibilityHidden(true)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint(Strings.History.viewDetails)
    }

    // MARK: - Thumbnail

    private var thumbnail: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: thumbnailSize, height: thumbnailSize)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color(.systemGray5), lineWidth: 1)
                    )
            } else {
                // Placeholder

                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(.systemGray6))
                    .frame(width: thumbnailSize, height: thumbnailSize)
                    .overlay(
                        Image(systemName: "photo")
                            .font(layoutMode == .comfortable ? .title2 : .title3)
                            .foregroundColor(.secondary)
                    )
            }
        }
        .accessibilityLabel(Strings.History.scannedPhotoThumbnail)
    }

    // MARK: - Merchant Name

    private var merchantName: some View {
        Text(getMerchantDisplayName())
            .font(layoutMode == .comfortable ? .headline : .subheadline)
            .fontWeight(layoutMode == .comfortable ? .semibold : .medium)
            .foregroundColor(.primary)
    }

    // MARK: - Barcode Text

    private var barcodeText: some View {
        HStack(spacing: 6) {
            Image(systemName: "barcode.viewfinder")
                .font(.caption)
                .foregroundColor(.blue)
                .accessibilityHidden(true)

            Text(record.barcode)
                .font(layoutMode == .comfortable ? .subheadline : .caption)
                .fontWeight(layoutMode == .comfortable ? .medium : .regular)
                .foregroundColor(.secondary)
                .fontDesign(.monospaced)
        }
    }

    // MARK: - Time Text

    private var timeText: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.caption2)
                .foregroundColor(.secondary)
                .accessibilityHidden(true)

            Text(formattedDate())
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Location Text

    private func locationText(_ location: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "mappin.circle")
                .font(.caption2)
                .foregroundColor(.green)
                .accessibilityHidden(true)

            Text(location)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }

    // MARK: - Helper Methods

    /// Get merchant display name
    private func getMerchantDisplayName() -> String {
        if let merchant = Merchant(rawValue: record.merchant) {
            return merchant.displayName
        }
        return record.merchant
    }

    /// Format date
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: record.timestamp)
    }

    /// Accessibility description
    private var accessibilityDescription: String {
        var description = "\(getMerchantDisplayName()), 条形码 \(record.barcode), \(formattedDate())"

        if let location = record.storeLocation, !location.isEmpty {
            description += ", 位置 \(location)"
        }

        return description
    }
}

// MARK: - Preview

#Preview("Compact") {
    List {
        HistoryRow(
            record: ScanRecord(
                username: "testuser",
                merchant: "walmart",
                barcode: "1234567890123",
                location: nil,
                storeLocation: "7-Eleven",
                imageFilename: "test.jpg"
            ),
            image: UIImage(systemName: "photo"),
            layoutMode: .compact
        )
    }
}

#Preview("Comfortable") {
    List {
        HistoryRow(
            record: ScanRecord(
                username: "testuser",
                merchant: "target",
                barcode: "9876543210987",
                location: nil,
                storeLocation: "Store 2",
                imageFilename: "test2.jpg"
            ),
            image: UIImage(systemName: "photo"),
            layoutMode: .comfortable
        )
    }
}

#Preview("Multiple Rows") {
    List {
        ForEach(0..<5) { index in
            HistoryRow(
                record: ScanRecord(
                    username: "testuser",
                    merchant: ["walmart", "target", "costco", "wholefoods", "traderjoes"][index],
                    barcode: "123456789012\(index)",
                    location: nil,
                    storeLocation: index % 2 == 0 ? "Floor 1" : nil,
                    imageFilename: "test\(index).jpg"
                ),
                image: UIImage(systemName: "photo"),
                layoutMode: index % 2 == 0 ? .compact : .comfortable
            )
        }
    }
}
