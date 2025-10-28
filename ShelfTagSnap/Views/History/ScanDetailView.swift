//
//  ScanDetailView.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//

import SwiftUI
import MapKit
import ZIPFoundation

/// Scan detail view
struct ScanDetailView: View {
    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - Properties

    let record: ScanRecord

    // MARK: - State

    @State private var image: UIImage?
    @State private var showDeleteAlert: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var imageScale: CGFloat = 1.0
    @State private var imageOffset: CGSize = .zero
    @State private var shareZipURL: URL?
    @State private var isGeneratingZip: Bool = false

    // MARK: - Private Properties

    private let storageService = LocalStorageService.shared

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // Photo display
                    photoSection

                    // Scan information
                    infoSection

                    // GPS map (if available)
                    if record.hasLocation {
                        mapSection
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(Strings.Detail.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .alert(Strings.History.deleteConfirmation, isPresented: $showDeleteAlert) {
                Button(Strings.Common.cancel, role: .cancel) {}
                Button(Strings.Common.delete, role: .destructive) {
                    deleteRecord()
                }
            } message: {
                Text(Strings.History.deleteMessage)
            }
            .sheet(isPresented: $showShareSheet) {
                if let zipURL = shareZipURL {
                    ShareSheet(items: [zipURL])
                }
            }
            .task {
                loadImage()
            }
            .onDisappear {
                cleanupTempFiles()
            }
        }
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        VStack(spacing: 12) {

            Text(Strings.Detail.scannedPhoto)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let image = image {
                ZoomableImage(image: image)
                    .frame(maxHeight: 400)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            } else {

                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .frame(height: 300)
                    .overlay(
                        VStack(spacing: 12) {
                            ProgressView()
                            Text(Strings.Common.loading)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    )
            }
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(spacing: 16) {

            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                    .accessibilityHidden(true)

                Text(Strings.Detail.scanInformation)
                    .font(.headline)

                Spacer()
            }

            InfoDetailRow(
                icon: "barcode.viewfinder",
                title: Strings.Detail.barcode,
                value: record.barcode,
                iconColor: .blue
            )

            InfoDetailRow(
                icon: "clock.fill",
                title: Strings.Detail.time,
                value: formattedTimestamp(),
                iconColor: .orange
            )

            if let storeLocation = record.storeLocation, !storeLocation.isEmpty {
                InfoDetailRow(
                    icon: "mappin.circle.fill",
                    title: Strings.Detail.storeLocation,
                    value: storeLocation,
                    iconColor: .red
                )
            }

            if let latitude = record.latitude, let longitude = record.longitude {
                InfoDetailRow(
                    icon: "location.fill",
                    title: Strings.Detail.gpsCoordinates,
                    value: String(format: "%.6f, %.6f", latitude, longitude),
                    iconColor: .purple
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Map Section

    @available(iOS 17.0, *)
    private var mapSection: some View {
        VStack(spacing: 12) {

            HStack {
                Image(systemName: "map.fill")
                    .foregroundColor(.green)
                    .accessibilityHidden(true)

                Text(Strings.Detail.locationMap)
                    .font(.headline)

                Spacer()
            }

            if let coordinate = record.coordinate {
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))) {
                    Marker(Strings.Detail.scanLocation, coordinate: coordinate)
                    .tint(.red)
                }
                .frame(height: 200)
                .cornerRadius(12)
                .accessibilityLabel(Strings.Detail.mapShowingScanLocation)
            }
        }
    }

    // MARK: - Toolbar

    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .cancellationAction) {
                Button(Strings.Common.close) {
                    dismiss()
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        Task {
                            await generateAndShareZip()
                        }
                    } label: {
                        if isGeneratingZip {
                            Label("Preparing...", systemImage: "arrow.triangle.2.circlepath")
                        } else {
                            Label(Strings.Common.share, systemImage: "square.and.arrow.up")
                        }
                    }
                    .disabled(isGeneratingZip)

                    Divider()

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label(Strings.Common.delete, systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel(Strings.Common.moreOptions)
            }
        }
    }

    // MARK: - Helper Methods

    private func loadImage() {
        image = try? storageService.loadImage(filename: record.imageFilename)
    }

    private func deleteRecord() {

        // TODO: Implement delete functionality, need to pass back to parent view
        dismiss()
    }

    private func getMerchantIcon() -> String {
        if let merchant = Merchant(rawValue: record.merchant) {
            return merchant.iconName
        }
        return "storefront"
    }

    private func getMerchantDisplayName() -> String {
        if let merchant = Merchant(rawValue: record.merchant) {
            return merchant.displayName
        }
        return record.merchant
    }

    private func formattedTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: record.timestamp)
    }

    private var recordDescription: String {
        var description = "\(Strings.Detail.scanRecord)\n\n"
        description += "\(Strings.Detail.barcode): \(record.barcode)\n"
        description += "\(Strings.Detail.merchant): \(getMerchantDisplayName())\n"
        description += "\(Strings.Detail.time): \(formattedTimestamp())\n"

        if let storeLocation = record.storeLocation, !storeLocation.isEmpty {
            description += "\(Strings.Detail.storeLocation): \(storeLocation)\n"
        }

        if let latitude = record.latitude, let longitude = record.longitude {
            description += String(format: "GPS: %.6f, %.6f\n", latitude, longitude)
        }

        return description
    }

    /// Generate ZIP file with photo + CSV for single record
    private func generateAndShareZip() async {
        guard !isGeneratingZip else { return }

        isGeneratingZip = true
        defer { isGeneratingZip = false }

        do {
            // Step 1: Create temporary directory
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            // Step 2: Generate CSV file with single record
            let csvURL = try CSVExporter.shared.export(records: [record])
            let csvDestination = tempDir.appendingPathComponent("scan_records.csv")
            try FileManager.default.copyItem(at: csvURL, to: csvDestination)

            // Step 3: Copy photo to photos/ subdirectory
            let photosDir = tempDir.appendingPathComponent("photos", isDirectory: true)
            try FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)

            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let imagesDirectory = documentsDirectory.appendingPathComponent("ScanImages")
            let photoURL = imagesDirectory.appendingPathComponent(record.imageFilename)

            if FileManager.default.fileExists(atPath: photoURL.path) {
                let photoDestination = photosDir.appendingPathComponent(record.imageFilename)
                try FileManager.default.copyItem(at: photoURL, to: photoDestination)
            }

            // Step 4: Create ZIP archive
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
            let timestamp = dateFormatter.string(from: Date())
            let zipFileName = "scan_record_\(timestamp).zip"
            let zipURL = FileManager.default.temporaryDirectory.appendingPathComponent(zipFileName)

            // Remove existing ZIP if it exists
            if FileManager.default.fileExists(atPath: zipURL.path) {
                try FileManager.default.removeItem(at: zipURL)
            }

            // Create ZIP using ZIPFoundation
            try FileManager.default.zipItem(at: tempDir, to: zipURL, shouldKeepParent: false)

            // Step 5: Clean up temporary directory (but keep ZIP)
            try? FileManager.default.removeItem(at: tempDir)

            // Step 6: Set share URL and show sheet
            await MainActor.run {
                shareZipURL = zipURL
                showShareSheet = true
            }

        } catch {
            print("❌ [SCAN_DETAIL] Failed to generate ZIP: \(error)")
            // TODO: Show error alert
        }
    }

    /// Clean up temporary ZIP files
    private func cleanupTempFiles() {
        if let zipURL = shareZipURL {
            try? FileManager.default.removeItem(at: zipURL)
            shareZipURL = nil
        }
    }
}

// MARK: - Info Detail Row

struct InfoDetailRow: View {
    let icon: String
    let title: String
    let value: String
    let iconColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 16) {

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
                    .textSelection(.enabled)
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}

// MARK: - Zoomable Image

struct ZoomableImage: View {
    let image: UIImage

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = lastScale * value
                    }
                    .onEnded { _ in
                        lastScale = scale

                        if scale < 1.0 {
                            withAnimation(.spring()) {
                                scale = 1.0
                                lastScale = 1.0
                            }
                        } else if scale > 4.0 {
                            withAnimation(.spring()) {
                                scale = 4.0
                                lastScale = 4.0
                            }
                        }
                    }
            )
            .gesture(
                // Only allow dragging when zoomed in (scale > 1.0)
                DragGesture()
                    .onChanged { value in
                        // Only allow drag when zoomed
                        if scale > 1.0 {
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                    }
                    .onEnded { _ in
                        if scale > 1.0 {
                            lastOffset = offset
                        } else {
                            // Reset offset if not zoomed
                            withAnimation(.spring()) {
                                offset = .zero
                                lastOffset = .zero
                            }
                        }
                    }
            )
            .onTapGesture(count: 2) {

                withAnimation(.spring()) {
                    scale = 1.0
                    lastScale = 1.0
                    offset = .zero
                    lastOffset = .zero
                }
            }
            .accessibilityLabel(Strings.Detail.photoSupportsZoom)
            .accessibilityHint(Strings.Detail.doubleTapToResetZoom)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    ScanDetailView(
        record: ScanRecord(
            username: "testuser",
            merchant: "walmart",
            barcode: "1234567890123",
            location: CLLocation(latitude: 37.7749, longitude: -122.4194),
            storeLocation: "Floor 1 entrance",
            imageFilename: "test.jpg"
        )
    )
}
