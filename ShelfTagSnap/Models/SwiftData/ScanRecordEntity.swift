//
//  ScanRecordEntity.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/27.
//

import Foundation
import SwiftData
import CoreLocation

/// SwiftData entity for scan records
@Model
final class ScanRecordEntity {
    // MARK: - Properties

    /// Unique identifier
    @Attribute(.unique) var id: String

    /// Username who created the scan
    var username: String

    /// Timestamp when scan was created
    var timestamp: Date

    /// Merchant name (e.g., "Walmart", "Target")
    var merchant: String

    /// Whether the record has been synced to server
    var isSynced: Bool

    // MARK: - Relationships

    /// Barcode information
    @Relationship(deleteRule: .cascade)
    var barcodeInfo: BarcodeInfoEntity?

    /// Store information
    @Relationship(deleteRule: .cascade)
    var storeInfo: StoreInfoEntity?

    /// Photo information
    @Relationship(deleteRule: .cascade)
    var photoInfo: PhotoInfoEntity?

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        username: String,
        timestamp: Date = Date(),
        merchant: String,
        isSynced: Bool = false,
        barcodeInfo: BarcodeInfoEntity? = nil,
        storeInfo: StoreInfoEntity? = nil,
        photoInfo: PhotoInfoEntity? = nil
    ) {
        self.id = id
        self.username = username
        self.timestamp = timestamp
        self.merchant = merchant
        self.isSynced = isSynced
        self.barcodeInfo = barcodeInfo
        self.storeInfo = storeInfo
        self.photoInfo = photoInfo
    }

    // MARK: - Computed Properties

    /// Formatted timestamp string
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: timestamp)
    }

    /// Whether has location data
    var hasLocation: Bool {
        return storeInfo?.latitude != nil && storeInfo?.longitude != nil
    }

    /// GPS coordinate if available
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = storeInfo?.latitude,
              let lon = storeInfo?.longitude else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Barcode string (convenience accessor)
    var barcode: String {
        return barcodeInfo?.code ?? ""
    }

    /// Store location string (convenience accessor)
    var storeLocation: String? {
        return storeInfo?.storeName
    }

    /// Image filename (convenience accessor)
    var imageFilename: String {
        return photoInfo?.filename ?? ""
    }
}

// MARK: - Conversion Extensions

extension ScanRecordEntity {
    /// Convert to legacy ScanRecord for compatibility
    func toLegacyRecord() -> ScanRecord {
        return ScanRecord(
            id: id,
            username: username,
            timestamp: timestamp,
            merchant: merchant,
            barcode: barcodeInfo?.code ?? "",
            latitude: storeInfo?.latitude,
            longitude: storeInfo?.longitude,
            imageFilename: photoInfo?.filename ?? "",
            storeLocation: storeInfo?.storeName,
            isSynced: isSynced
        )
    }

    /// CSV format string representation
    func toCSVRow() -> String {
        let components = [
            id,
            username,
            formattedTimestamp,
            escapeCSVField(merchant),
            barcodeInfo?.code ?? "",
            storeInfo?.latitude.map { String(format: "%.6f", $0) } ?? "",
            storeInfo?.longitude.map { String(format: "%.6f", $0) } ?? "",
            photoInfo?.filename ?? "",
            escapeCSVField(storeInfo?.storeName ?? "")
        ]
        return components.joined(separator: ",")
    }

    /// Escape CSV field
    private func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\n") || field.contains("\"") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
}

// MARK: - Legacy ScanRecord Extension

extension ScanRecord {
    /// Create entity from legacy record
    func toEntity() -> ScanRecordEntity {
        let entity = ScanRecordEntity(
            id: id,
            username: username,
            timestamp: timestamp,
            merchant: merchant,
            isSynced: isSynced
        )

        // Create barcode info
        entity.barcodeInfo = BarcodeInfoEntity(
            code: barcode,
            type: detectBarcodeType(barcode),
            isValid: !barcode.isEmpty
        )

        // Create store info
        entity.storeInfo = StoreInfoEntity(
            merchantName: merchant,
            storeName: storeLocation,
            latitude: latitude,
            longitude: longitude
        )

        // Create photo info
        entity.photoInfo = PhotoInfoEntity(
            filename: imageFilename
        )

        return entity
    }

    /// Detect barcode type from code string
    private func detectBarcodeType(_ code: String) -> String {
        switch code.count {
        case 12:
            return "UPC-A"
        case 13:
            return "EAN-13"
        case 8:
            return "EAN-8"
        default:
            return "Unknown"
        }
    }
}
