//
//  ScanResultView.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//

import SwiftUI
import Combine

/// Scan result confirmation view
struct ScanResultView: View {
    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - Properties

    let photo: UIImage
    let barcode: String
    let merchant: Merchant
    @Binding var storeLocation: String

    let onSave: () -> Void
    let onCancel: () -> Void

    // MARK: - State

    @FocusState private var isStoreLocationFocused: Bool

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // Photo preview
                    photoPreview

                    // Scan information
                    scanInfoSection

                    // Store location input (optional)
                    storeLocationSection

                    // Save button
                    saveButton
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(Strings.ScanResult.confirmScan)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Strings.Common.cancel) {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Photo Preview

    private var photoPreview: some View {
        VStack(spacing: 12) {

            Text(Strings.ScanResult.scannedPhoto)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(uiImage: photo)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                .accessibilityLabel(Strings.ScanResult.scannedPhotoAlt)
                .accessibilityValue(Strings.ScanResult.photoOfBarcode)
                .accessibilityAddTraits(.isImage)
        }
    }

    // MARK: - Scan Info Section

    private var scanInfoSection: some View {
        VStack(spacing: 16) {

            // Barcode info
            InfoRow(
                icon: "barcode.viewfinder",
                title: Strings.ScanResult.barcode,
                value: barcode,
                iconColor: .blue
            )

            // Scan time
            InfoRow(
                icon: "clock.fill",
                title: Strings.ScanResult.time,
                value: formattedCurrentTime(),
                iconColor: .orange
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Store Location Section

    private var storeLocationSection: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text(Strings.ScanResult.storeLocationOptional)
                .font(.headline)

            TextField(Strings.ScanResult.storeLocationPlaceholder, text: $storeLocation)
                .textFieldStyle(.roundedBorder)
                .focused($isStoreLocationFocused)
                .submitLabel(.done)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Save Button

    private var saveButton: some View {
        LoadingButton(
            title: Strings.ScanResult.saveScanRecord,
            style: .primary,
            iconName: "checkmark.circle.fill"
        ) {
            onSave()
            dismiss()
        }
        .padding(.top, 8)
    }

    // MARK: - Helper Methods

    private func formattedCurrentTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }
}

// MARK: - Info Row

/// Information row component
struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    let iconColor: Color

    var body: some View {
        HStack(spacing: 16) {

            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(iconColor.opacity(0.15))
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
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
    ScanResultView(
        photo: UIImage(systemName: "photo")!,
        barcode: "1234567890123",
        merchant: .walmart,
        storeLocation: .constant("一楼入口"),
        onSave: {
            print("Save tapped")
        },
        onCancel: {
            print("Cancel tapped")
        }
    )
}
