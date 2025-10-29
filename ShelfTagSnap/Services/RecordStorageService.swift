//
//  RecordStorageService.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/27.
//

import Foundation
import SwiftData
import UIKit
import CoreLocation

/// Record storage service - High-level API for saving and loading scan records
/// Uses SwiftData for database and LocalStorageService for images
@MainActor
class RecordStorageService {
    // MARK: - Singleton

    static let shared = RecordStorageService()

    // MARK: - Dependencies

    private let swiftDataService: SwiftDataService
    private let localStorageService: LocalStorageService
    private let paginationService: PaginationService

    // MARK: - Initialization

    private init(
        swiftDataService: SwiftDataService = .shared,
        localStorageService: LocalStorageService = .shared
    ) {
        self.swiftDataService = swiftDataService
        self.localStorageService = localStorageService
        self.paginationService = PaginationService(swiftDataService: swiftDataService)
    }

    // MARK: - Save Operations

    /// Save a new scan record
    func saveScanRecord(
        username: String,
        merchant: String,
        barcode: String,
        location: CLLocation?,
        storeLocation: String?,
        image: UIImage
    ) async throws -> ScanRecord {
        // 1. Save image first
        let imageFilename = "\(UUID().uuidString).jpg"
        let imageURL = try localStorageService.saveImage(image, filename: imageFilename)

        // Get image metadata
        let imageSize = try? FileManager.default.attributesOfItem(atPath: imageURL.path)[.size] as? Int64
        let imageWidth = Int(image.size.width * image.scale)
        let imageHeight = Int(image.size.height * image.scale)

        // 2. Create SwiftData entity
        let entity = ScanRecordEntity(
            username: username,
            timestamp: Date(),
            merchant: merchant,
            isSynced: false
        )

        // 3. Create barcode info
        entity.barcodeInfo = BarcodeInfoEntity(
            code: barcode,
            type: detectBarcodeType(barcode),
            isValid: !barcode.isEmpty
        )

        // 4. Create store info
        entity.storeInfo = StoreInfoEntity(
            merchantName: merchant,
            storeName: storeLocation,
            latitude: location?.coordinate.latitude,
            longitude: location?.coordinate.longitude,
            locationAccuracy: location?.horizontalAccuracy
        )

        // 5. Create photo info
        entity.photoInfo = PhotoInfoEntity(
            filename: imageFilename,
            fileSize: imageSize,
            width: imageWidth,
            height: imageHeight,
            compressionQuality: 0.58,  // Match LocalStorageService compression
            imageFormat: "JPEG"
        )

        // 6. Save to database
        try swiftDataService.insertScanRecord(entity)

        // 7. Return legacy ScanRecord for compatibility
        return entity.toLegacyRecord()
    }

    // MARK: - Load Operations

    /// Load all records for a user (for backward compatibility)
    func loadRecords(forUsername username: String) async throws -> [ScanRecord] {
        let entities = try await paginationService.fetchRecords(
            forUsername: username,
            dateFilter: .allTime
        )

        return entities.map { $0.toLegacyRecord() }
    }

    /// Load records with pagination
    func loadRecordsPaginated(
        forUsername username: String,
        dateFilter: DateFilterType
    ) async throws -> [ScanRecord] {
        paginationService.configure(username: username, dateFilter: dateFilter)
        let entities = try await paginationService.fetchNextPage()
        return entities.map { $0.toLegacyRecord() }
    }

    /// Count records
    func countRecords(
        forUsername username: String,
        dateFilter: DateFilterType? = nil
    ) async throws -> Int {
        return try await paginationService.countRecords(
            forUsername: username,
            dateFilter: dateFilter
        )
    }

    /// Get a single record by barcode
    func getRecord(byBarcode barcode: String) -> ScanRecord? {
        let context = swiftDataService.mainContext
        let descriptor = FetchDescriptor<ScanRecordEntity>(
            predicate: #Predicate { entity in
                entity.barcodeInfo?.code == barcode
            }
        )

        do {
            let entities = try context.fetch(descriptor)
            return entities.first?.toLegacyRecord()
        } catch {
            print("[RecordStorageService] Failed to fetch record by barcode: \(error)")
            return nil
        }
    }

    // MARK: - Delete Operations

    /// Delete a single record
    func deleteRecord(_ record: ScanRecord) async throws {
        // 1. Find entity in database
        let context = swiftDataService.mainContext
        let entities = try context.fetch(
            FetchDescriptor<ScanRecordEntity>(
                predicate: #Predicate { $0.id == record.id }
            )
        )

        guard let entity = entities.first else {
            throw StorageError.recordNotFound
        }

        // 2. Delete image
        try? localStorageService.deleteImage(filename: record.imageFilename)

        // 3. Delete from database (cascade will delete related entities)
        try swiftDataService.deleteScanRecord(entity)
    }

    /// Delete multiple records
    func deleteRecords(_ records: [ScanRecord]) async throws {
        for record in records {
            try await deleteRecord(record)
        }
    }

    /// Delete all records for a user
    func deleteAllRecords(forUsername username: String) async throws {
        // 1. Fetch all entities
        let context = swiftDataService.mainContext
        let entities = try context.fetch(
            FetchDescriptor<ScanRecordEntity>(
                predicate: #Predicate { $0.username == username }
            )
        )

        // 2. Delete all images
        for entity in entities {
            if let filename = entity.photoInfo?.filename {
                try? localStorageService.deleteImage(filename: filename)
            }
        }

        // 3. Delete from database
        try swiftDataService.deleteScanRecords(entities)
    }

    // MARK: - Image Operations

    /// Load image for a record
    func loadImage(for record: ScanRecord) -> UIImage? {
        return try? localStorageService.loadImage(filename: record.imageFilename)
    }

    // MARK: - Helper Methods

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

// MARK: - Storage Errors

extension RecordStorageService {
    enum StorageError: Error, LocalizedError {
        case recordNotFound
        case imageNotFound
        case saveFailed(String)

        var errorDescription: String? {
            switch self {
            case .recordNotFound:
                return "Record not found in database"
            case .imageNotFound:
                return "Image file not found"
            case .saveFailed(let reason):
                return "Save failed: \(reason)"
            }
        }
    }
}
