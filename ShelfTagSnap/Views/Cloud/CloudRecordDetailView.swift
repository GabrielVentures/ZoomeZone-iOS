//
//  CloudRecordDetailView.swift
//  ShelfTagSnap
//
//  Created by Claude on 2025-11-03.
//  Milestone 2: Cloud Record Detail View
//

import SwiftUI
import MapKit
import Kingfisher

/// Cloud record detail view
struct CloudRecordDetailView: View {
    // MARK: - Properties

    let record: CloudScanRecord

    // MARK: - State

    @Environment(\.dismiss) private var dismiss
    @State private var region: MKCoordinateRegion?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Large image
                    imageSection

                    // AI Result Card (Purple theme)
                    if let aiResult = record.aiResult {
                        aiResultCard(aiResult)
                    } else if record.aiPending {
                        aiPendingCard
                    } else if record.aiFailed {
                        aiFailedCard
                    }

                    // Basic information
                    basicInfoSection

                    // Location section
                    if record.hasLocation {
                        locationSection
                    }

                    // Metadata section
                    metadataSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Record Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .fontWeight(.medium)
                    }
                }
            }
            .onAppear {
                setupMapRegion()
            }
        }
    }

    // MARK: - Image Section

    private var imageSection: some View {
        // ✅ Using Kingfisher for image caching
        KFImage(URL(string: record.imageUrl))
            .placeholder {
                Rectangle()
                    .fill(Color(.systemGray6))
                    .frame(height: 300)
                    .overlay(
                        ProgressView()
                    )
            }
            .onFailure { error in
                print("❌ [Kingfisher] Failed to load image for record \(record.id ?? "unknown"): \(error)")
            }
            .retry(maxCount: 3, interval: .seconds(1))
            .cacheMemoryOnly()  // Memory-only cache for cloud images to save disk space
            .fade(duration: 0.25)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .cornerRadius(12)
    }

    // MARK: - AI Result Card (Purple Theme)

    private func aiResultCard(_ aiResult: AIResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundColor(.purple)

                Text("AI Recognition Result")
                    .font(.headline)
                    .foregroundColor(.purple)

                Spacer()

                // Confidence badge
                if let confidence = aiResult.confidence {
                    confidenceBadge(confidence)
                }
            }

            Divider()

            // Title
            if let title = aiResult.title, !title.isEmpty {
                infoRow(label: "Product", value: title, icon: "tag.fill")
            }

            // Price
            if let price = aiResult.price, !price.isEmpty {
                infoRow(label: "Price", value: price, icon: "dollarsign.circle.fill")
            }

            // Unit Price
            if let unitPrice = aiResult.unitPrice, !unitPrice.isEmpty {
                infoRow(label: "Unit Price", value: unitPrice, icon: "chart.bar.fill")
            }

            // Size
            if let size = aiResult.size, !size.isEmpty {
                infoRow(label: "Size", value: size, icon: "ruler.fill")
            }

            // Category
            if let category = aiResult.category, !category.isEmpty {
                infoRow(label: "Category", value: category, icon: "square.grid.2x2")
            }

            // Brand
            if let brand = aiResult.brand, !brand.isEmpty {
                infoRow(label: "Brand", value: brand, icon: "building.2.fill")
            }

            // Promotion
            if let promotion = aiResult.promotion, !promotion.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "gift.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Promotion")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(promotion)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.1))
                )
            }

            // Description
            if let description = aiResult.description, !description.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "text.alignleft")
                            .font(.caption)
                            .foregroundColor(.purple.opacity(0.7))
                        Text("Description")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(description)
                        .font(.body)
                        .foregroundColor(.primary)
                }
            }

            // Processed time
            if let processedDate = aiResult.processedDate {
                HStack {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                        .foregroundColor(.purple.opacity(0.5))

                    Text("Processed \(processedDate, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.3), lineWidth: 2)
        )
    }

    // MARK: - AI Pending Card

    private var aiPendingCard: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)

            Text("AI Processing...")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.orange)

            Text("This may take a few minutes")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 2)
        )
    }

    // MARK: - AI Failed Card

    private var aiFailedCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.red)

            Text("AI Processing Failed")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.red)

            if let error = record.aiError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 2)
        )
    }

    // MARK: - Basic Info Section

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Basic Information")
                .font(.headline)

            Divider()

            // Merchant
            infoRow(label: "Merchant", value: record.merchant, icon: "building.2.fill")

            // Shelf Tag Barcode (preferred display)
            infoRow(label: "Shelf Tag", value: record.displayBarcode, icon: "barcode.viewfinder")

            // Full UPC Barcode (if available and different)
            if let fullBarcode = record.barcodeFull, fullBarcode != record.displayBarcode {
                infoRow(label: "UPC", value: fullBarcode, icon: "barcode")
            }

            // Store location
            if let storeLocation = record.storeLocation {
                infoRow(label: "Store", value: storeLocation, icon: "mappin.circle.fill")
            }

            // Scan time
            infoRow(label: "Scanned", value: record.deviceDate.formatted(), icon: "clock.fill")

            // Upload time
            if let uploadDate = record.uploadDate {
                infoRow(label: "Uploaded", value: uploadDate.formatted(), icon: "icloud.and.arrow.up")
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - Location Section

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location")
                .font(.headline)

            Divider()

            // Coordinates
            if let lat = record.latitude, let lon = record.longitude {
                HStack {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("GPS Coordinates")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(String(format: "%.6f, %.6f", lat, lon))
                            .font(.body)
                            .fontDesign(.monospaced)
                    }
                }
            }

            // Map
            if let region = region {
                Map(coordinateRegion: .constant(region), annotationItems: [record]) { rec in
                    MapMarker(coordinate: CLLocationCoordinate2D(
                        latitude: rec.latitude ?? 0,
                        longitude: rec.longitude ?? 0
                    ), tint: .blue)
                }
                .frame(height: 200)
                .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - Metadata Section

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metadata")
                .font(.headline)

            Divider()

            // Record ID
            infoRow(label: "Record ID", value: record.id ?? "Unknown", icon: "number")

            // Username
            infoRow(label: "User", value: record.username, icon: "person.fill")

            // Image filename
            infoRow(label: "Image", value: record.imageFilename, icon: "photo")
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - Helper Views

    private func infoRow(label: String, value: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.body)
                    .foregroundColor(.primary)
            }

            Spacer()
        }
    }

    private func confidenceBadge(_ confidence: String?) -> some View {
        let percent = aiResult.confidencePercent
        let color: Color = percent >= 80 ? .green : .orange

        return HStack(spacing: 4) {
            Image(systemName: percent >= 80 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.caption2)

            Text("\(percent)%")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
    }

    // Helper to access aiResult for confidence badge
    private var aiResult: AIResult {
        record.aiResult ?? AIResult()
    }

    // MARK: - Helper Methods

    private func setupMapRegion() {
        guard let lat = record.latitude, let lon = record.longitude else { return }

        region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    }
}

// MARK: - Preview

#Preview("With AI Result") {
    CloudRecordDetailView(record: .sample)
}

#Preview("AI Pending") {
    CloudRecordDetailView(record: .samplePending)
}

#Preview("AI Failed") {
    CloudRecordDetailView(record: .sampleFailed)
}
