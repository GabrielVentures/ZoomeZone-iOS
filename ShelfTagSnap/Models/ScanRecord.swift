//
//  ScanRecord.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//

import Foundation
import CoreLocation

/// Scan record data model containing all information about a barcode scan
struct ScanRecord: Codable, Identifiable, Hashable {
    // MARK: - Properties

    let id: String

    let username: String

    let timestamp: Date

    let merchant: String

    let barcode: String

    let latitude: Double?

    let longitude: Double?

    let imageFilename: String

    let storeLocation: String?

    var isSynced: Bool

    // MARK: - Initialization

    /// Create a new scan record
    /// - Parameters:
    init(
        username: String,
        merchant: String,
        barcode: String,
        location: CLLocation?,
        storeLocation: String?,
        imageFilename: String
    ) {
        self.id = UUID().uuidString
        self.username = username
        self.timestamp = Date()
        self.merchant = merchant
        self.barcode = barcode
        self.latitude = location?.coordinate.latitude
        self.longitude = location?.coordinate.longitude
        self.imageFilename = imageFilename
        self.storeLocation = storeLocation
        self.isSynced = false
    }

    /// Create from all fields (for conversion)
    init(
        id: String,
        username: String,
        timestamp: Date,
        merchant: String,
        barcode: String,
        latitude: Double?,
        longitude: Double?,
        imageFilename: String,
        storeLocation: String?,
        isSynced: Bool
    ) {
        self.id = id
        self.username = username
        self.timestamp = timestamp
        self.merchant = merchant
        self.barcode = barcode
        self.latitude = latitude
        self.longitude = longitude
        self.imageFilename = imageFilename
        self.storeLocation = storeLocation
        self.isSynced = isSynced
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
        latitude != nil && longitude != nil
    }

    /// GPS coordinate if available
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case id = "Scan_ID"
        case username = "Username"
        case timestamp = "Timestamp"
        case merchant = "Merchant"
        case barcode = "Barcode"
        case latitude = "Latitude"
        case longitude = "Longitude"
        case imageFilename = "Image_Filename"
        case storeLocation = "Store_Location"
        case isSynced
    }
}

// MARK: - Extensions

extension ScanRecord {

    /// CSV format string representation
    func toCSVRow() -> String {
        let components = [
            id,
            username,
            formattedTimestamp,
            escapeCSVField(merchant),
            barcode,
            latitude.map { String(format: "%.6f", $0) } ?? "",
            longitude.map { String(format: "%.6f", $0) } ?? "",
            imageFilename,
            escapeCSVField(storeLocation ?? "")
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
