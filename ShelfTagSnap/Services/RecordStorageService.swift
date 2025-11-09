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
        // 1. Create SwiftData entity first to get the record ID
        let entity = ScanRecordEntity(
            username: username,
            timestamp: Date(),
            merchant: merchant,
            isSynced: false
        )

        // 2. Save image using the record ID as filename (for Cloud Function mapping)
        let imageFilename = "\(entity.id).jpg"
        let imageURL = try localStorageService.saveImage(image, filename: imageFilename)

        // Get image metadata
        let imageSize = try? FileManager.default.attributesOfItem(atPath: imageURL.path)[.size] as? Int64
        let imageWidth = Int(image.size.width * image.scale)
        let imageHeight = Int(image.size.height * image.scale)

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

        // 7. Get the legacy record to return
        let savedRecord = entity.toLegacyRecord()

        print("💾 [RecordStorageService] Record saved: \(savedRecord.id)")
        print("   - Merchant: \(savedRecord.merchant)")
        print("   - Barcode: \(savedRecord.barcode)")
        print("   - Image: \(savedRecord.imageFilename)")

        // 8. Trigger cloud upload if enabled
        Task { @MainActor in
            print("☁️ [RecordStorageService] Triggering cloud upload...")
            await CloudSyncService.shared.addToQueue(savedRecord)
        }

        // 9. Return legacy ScanRecord for compatibility
        return savedRecord
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
    /// ✅ FIX P1-12: Prevent deletion of records currently being uploaded
    func deleteRecord(_ record: ScanRecord) async throws {
        // ✅ FIX P1-12: Check if record is currently being uploaded
        if await UploadCoordinator.shared.isUploading(record.id) {
            print("⚠️ [RecordStorageService] Cannot delete record \(record.id) - currently uploading")
            throw StorageError.recordLocked("Record is currently being uploaded")
        }

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

        print("✅ [RecordStorageService] Deleted record: \(record.id)")
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

    // MARK: - Cloud Upload Operations (Milestone 2)

    /// Update upload status for a record
    /// ✅ FIX P0-8: Enforce data consistency - isUploaded=true MUST have uploadedAt timestamp
    func updateUploadStatus(
        recordId: String,
        isUploaded: Bool,
        uploadedAt: Date?
    ) async throws {
        let context = swiftDataService.mainContext

        let descriptor = FetchDescriptor<ScanRecordEntity>(
            predicate: #Predicate { $0.id == recordId }
        )

        guard let entity = try context.fetch(descriptor).first else {
            throw StorageError.recordNotFound
        }

        // ✅ FIX P0-8: Data consistency validation
        if isUploaded && uploadedAt == nil {
            // If marking as uploaded, MUST provide timestamp
            throw StorageError.inconsistentUploadState(
                "Cannot mark record as uploaded without uploadedAt timestamp"
            )
        }

        entity.isUploaded = isUploaded
        entity.uploadedAt = uploadedAt

        try context.save()

        print("☁️ [RecordStorageService] Updated upload status for record \(recordId): isUploaded=\(isUploaded), uploadedAt=\(uploadedAt?.description ?? "nil")")
    }

    /// Get pending upload records (not yet uploaded)
    func getPendingUploadRecords() async throws -> [ScanRecord] {
        let context = swiftDataService.mainContext

        let descriptor = FetchDescriptor<ScanRecordEntity>(
            predicate: #Predicate { $0.isUploaded == false },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        let entities = try context.fetch(descriptor)
        let records = entities.map { $0.toLegacyRecord() }

        print("☁️ [RecordStorageService] Found \(records.count) pending upload records")
        return records
    }

    /// Get uploaded records
    func getUploadedRecords() async throws -> [ScanRecord] {
        let context = swiftDataService.mainContext

        let descriptor = FetchDescriptor<ScanRecordEntity>(
            predicate: #Predicate { $0.isUploaded == true },
            sortBy: [SortDescriptor(\.uploadedAt, order: .reverse)]
        )

        let entities = try context.fetch(descriptor)
        let records = entities.map { $0.toLegacyRecord() }

        print("☁️ [RecordStorageService] Found \(records.count) uploaded records")
        return records
    }

    /// Get upload statistics
    func getUploadStatistics() async throws -> (total: Int, uploaded: Int, pending: Int) {
        let context = swiftDataService.mainContext

        // Total count
        let totalDescriptor = FetchDescriptor<ScanRecordEntity>()
        let totalCount = try context.fetchCount(totalDescriptor)

        // Uploaded count
        let uploadedDescriptor = FetchDescriptor<ScanRecordEntity>(
            predicate: #Predicate { $0.isUploaded == true }
        )
        let uploadedCount = try context.fetchCount(uploadedDescriptor)

        // Pending count
        let pendingCount = totalCount - uploadedCount

        print("☁️ [RecordStorageService] Upload stats: total=\(totalCount), uploaded=\(uploadedCount), pending=\(pendingCount)")

        return (total: totalCount, uploaded: uploadedCount, pending: pendingCount)
    }

    // MARK: - Data Validation (Fix P0-8)

    /// Validate and fix inconsistent upload states
    /// ✅ FIX P0-8: Detect and fix records with isUploaded=true but uploadedAt=nil
    func validateAndFixUploadStates() async throws -> (fixed: Int, inconsistent: [String]) {
        let context = swiftDataService.mainContext

        // Find records with isUploaded=true but no uploadedAt timestamp
        let descriptor = FetchDescriptor<ScanRecordEntity>(
            predicate: #Predicate { entity in
                entity.isUploaded == true && entity.uploadedAt == nil
            }
        )

        let inconsistentRecords = try context.fetch(descriptor)

        if inconsistentRecords.isEmpty {
            print("✅ [RecordStorageService] No inconsistent upload states found")
            return (fixed: 0, inconsistent: [])
        }

        print("⚠️ [RecordStorageService] Found \(inconsistentRecords.count) records with inconsistent upload states")

        var fixedCount = 0
        var inconsistentIds: [String] = []

        for entity in inconsistentRecords {
            // Strategy: Mark as pending since we can't verify actual upload
            entity.isUploaded = false
            entity.uploadedAt = nil
            fixedCount += 1
            inconsistentIds.append(entity.id)

            print("   🔧 Fixed record \(entity.id): set isUploaded=false")
        }

        try context.save()

        print("✅ [RecordStorageService] Fixed \(fixedCount) inconsistent records")
        return (fixed: fixedCount, inconsistent: inconsistentIds)
    }

    /// Validate upload state for a specific record
    /// ✅ FIX P0-8: Check if a record's upload state is consistent
    func validateUploadState(recordId: String) async throws -> Bool {
        let context = swiftDataService.mainContext

        let descriptor = FetchDescriptor<ScanRecordEntity>(
            predicate: #Predicate { $0.id == recordId }
        )

        guard let entity = try context.fetch(descriptor).first else {
            throw StorageError.recordNotFound
        }

        // Validate: if isUploaded=true, uploadedAt must not be nil
        let isConsistent = !(entity.isUploaded && entity.uploadedAt == nil)

        if !isConsistent {
            print("⚠️ [RecordStorageService] Record \(recordId) has inconsistent state: isUploaded=\(entity.isUploaded), uploadedAt=\(entity.uploadedAt?.description ?? "nil")")
        }

        return isConsistent
    }
}

// MARK: - Storage Errors

extension RecordStorageService {
    enum StorageError: Error, LocalizedError {
        case recordNotFound
        case imageNotFound
        case saveFailed(String)
        case inconsistentUploadState(String)  // ✅ FIX P0-8: New error for data consistency
        case recordLocked(String)  // ✅ FIX P1-12: New error for locked records

        var errorDescription: String? {
            switch self {
            case .recordNotFound:
                return "Record not found in database"
            case .imageNotFound:
                return "Image file not found"
            case .saveFailed(let reason):
                return "Save failed: \(reason)"
            case .inconsistentUploadState(let reason):
                return "Inconsistent upload state: \(reason)"
            case .recordLocked(let reason):
                return "Record locked: \(reason)"
            }
        }
    }
}
