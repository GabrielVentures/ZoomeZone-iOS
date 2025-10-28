//
//  StoreInfoEntity.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/27.
//

import Foundation
import SwiftData
import CoreLocation

/// SwiftData entity for store information
@Model
final class StoreInfoEntity {
    // MARK: - Properties

    /// Merchant name (e.g., "Walmart", "Target")
    var merchantName: String

    /// Specific store name/location (e.g., "Walmart #1234", "Target Downtown")
    var storeName: String?

    /// Store address (full address string)
    var storeAddress: String?

    /// Store ID (if available from merchant)
    var storeId: String?

    /// GPS latitude
    var latitude: Double?

    /// GPS longitude
    var longitude: Double?

    /// Location accuracy in meters
    var locationAccuracy: Double?

    /// Additional store metadata (JSON string)
    var metadata: String?

    // MARK: - Initialization

    init(
        merchantName: String,
        storeName: String? = nil,
        storeAddress: String? = nil,
        storeId: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationAccuracy: Double? = nil,
        metadata: String? = nil
    ) {
        self.merchantName = merchantName
        self.storeName = storeName
        self.storeAddress = storeAddress
        self.storeId = storeId
        self.latitude = latitude
        self.longitude = longitude
        self.locationAccuracy = locationAccuracy
        self.metadata = metadata
    }

    // MARK: - Computed Properties

    /// Whether has location data
    var hasLocation: Bool {
        return latitude != nil && longitude != nil
    }

    /// GPS coordinate if available
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Display name (store name or merchant name)
    var displayName: String {
        return storeName ?? merchantName
    }

    /// Full location string
    var fullLocationString: String {
        var parts: [String] = []

        if let storeName = storeName {
            parts.append(storeName)
        } else {
            parts.append(merchantName)
        }

        if let address = storeAddress {
            parts.append(address)
        }

        return parts.joined(separator: " - ")
    }
}

// MARK: - Location Extensions

extension StoreInfoEntity {
    /// Set location from CLLocation
    func setLocation(_ location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.locationAccuracy = location.horizontalAccuracy
    }

    /// Get CLLocation if available
    var location: CLLocation? {
        guard let lat = latitude, let lon = longitude else {
            return nil
        }
        return CLLocation(latitude: lat, longitude: lon)
    }
}
