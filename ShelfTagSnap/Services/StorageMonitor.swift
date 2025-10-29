//
//  StorageMonitor.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//

import Foundation
import UIKit

/// Storage space monitoring service
///
/// Features:
/// - Check available storage
/// - Calculate used space
/// - Storage warning thresholds
/// - Cleanup suggestions
class StorageMonitor {
    // MARK: - Singleton

    static let shared = StorageMonitor()

    // MARK: - Constants

    /// Storage thresholds (bytes)
    private enum Threshold {
        static let critical: Int64 = 500 * 1024 * 1024      // 500 MB
        static let warning: Int64 = 1024 * 1024 * 1024      // 1 GB
    }

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let storageService = LocalStorageService.shared
    private let recordStorageService = RecordStorageService.shared

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Get available storage space
    ///
    /// - Returns: Available space in bytes
    func getAvailableSpace() -> Int64 {
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())

        guard let values = try? homeURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
              let availableSpace = values.volumeAvailableCapacityForImportantUsage else {
            return 0
        }

        return availableSpace
    }

    /// Get total storage space
    ///
    /// - Returns: Total space in bytes
    func getTotalSpace() -> Int64 {
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())

        guard let values = try? homeURL.resourceValues(forKeys: [.volumeTotalCapacityKey]),
              let totalSpace = values.volumeTotalCapacity else {
            return 0
        }

        return Int64(totalSpace)
    }

    /// Calculate used space
    ///
    /// - Returns: Used space in bytes
    func getUsedSpace() -> Int64 {
        let total = getTotalSpace()
        let available = getAvailableSpace()
        return total - available
    }

    /// Calculate app used space
    ///
    /// - Returns: App used space in bytes
    func getAppUsedSpace() -> Int64 {
        var totalSize: Int64 = 0

        // Calculate photo storage
        totalSize += getPhotosSize()

        // Calculate database and other files
        totalSize += getDocumentsSize()

        return totalSize
    }

    /// Get photos storage size
    func getPhotosSize() -> Int64 {
        return calculateDirectorySize(at: storageService.photosDirectory)
    }

    /// Get documents storage size
    func getDocumentsSize() -> Int64 {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return calculateDirectorySize(at: documentsURL)
    }

    /// Get scan records count
    func getRecordsCount() -> Int {
        return (try? storageService.loadRecords().count) ?? 0
    }

    /// Check storage status
    ///
    /// - Returns: Storage status
    func checkStorageStatus() -> StorageStatus {
        let available = getAvailableSpace()

        if available < Threshold.critical {
            return .critical
        } else if available < Threshold.warning {
            return .warning
        } else {
            return .normal
        }
    }

    /// Get storage info
    ///
    /// - Returns: Storage info
    func getStorageInfo() -> StorageInfo {
        let totalSpace = getTotalSpace()
        let availableSpace = getAvailableSpace()
        let usedSpace = getUsedSpace()
        let appUsedSpace = getAppUsedSpace()
        let photosSize = getPhotosSize()
        let recordsCount = getRecordsCount()
        let status = checkStorageStatus()

        return StorageInfo(
            totalSpace: totalSpace,
            availableSpace: availableSpace,
            usedSpace: usedSpace,
            appUsedSpace: appUsedSpace,
            photosSize: photosSize,
            recordsCount: recordsCount,
            status: status
        )
    }

    /// Check if cleanup needed
    func shouldCleanup() -> Bool {
        let status = checkStorageStatus()
        return status == .critical || status == .warning
    }

    /// Get cleanup suggestions
    ///
    /// - Returns: Cleanup suggestions list
    func getCleanupSuggestions() -> [CleanupSuggestion] {
        var suggestions: [CleanupSuggestion] = []

        let recordsCount = getRecordsCount()
        let photosSize = getPhotosSize()
        let status = checkStorageStatus()

        // If many records exist
        if recordsCount > 100 {
            suggestions.append(CleanupSuggestion(
                type: .deleteOldRecords,
                title: "Delete Old Records",
                description: "Delete scan records older than 30 days",
                estimatedSpace: Int64(recordsCount / 2) * 2 * 1024 * 1024, // Estimate 2MB per record
                priority: status == .critical ? .high : .medium
            ))
        }

        // If photos use much space
        if photosSize > 50 * 1024 * 1024 { // > 50 MB
            suggestions.append(CleanupSuggestion(
                type: .compressPhotos,
                title: "Compress Photos",
                description: "Compress stored photos to save space",
                estimatedSpace: photosSize / 2, // Estimate 50% savings
                priority: status == .critical ? .high : .low
            ))
        }

        // Clean export files
        if let exportedFiles = try? CSVExporter.shared.getAllExportedFiles(),
           !exportedFiles.isEmpty {
            let exportSize = exportedFiles.reduce(Int64(0)) { total, url in
                if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    return total + Int64(size)
                }
                return total
            }

            if exportSize > 0 {
                suggestions.append(CleanupSuggestion(
                    type: .deleteExports,
                    title: "Delete Export Files",
                    description: "Delete exported CSV files",
                    estimatedSpace: exportSize,
                    priority: .low
                ))
            }
        }

        // Sort by priority
        return suggestions.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }

    /// Perform cleanup
    ///
    /// - Parameter type: Cleanup type
    /// - Returns: Cleaned space in bytes
    @discardableResult
    func performCleanup(type: CleanupType) async throws -> Int64 {
        switch type {
        case .deleteOldRecords:
            return try await deleteOldRecords()

        case .deleteExports:
            return try deleteExportedFiles()

        case .deleteAllData:
            return try await deleteAllData()

        case .compressPhotos:
            // TODO: Implement photo compression
            return 0
        }
    }

    // MARK: - Private Methods

    /// Calculate directory size
    private func calculateDirectorySize(at url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var totalSize: Int64 = 0

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = resourceValues.fileSize else {
                continue
            }
            totalSize += Int64(fileSize)
        }

        return totalSize
    }

    /// Delete old records (older than 30 days)
    private func deleteOldRecords() async throws -> Int64 {
        let records = try storageService.loadRecords()
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)

        var deletedSize: Int64 = 0
        var remainingRecords: [ScanRecord] = []

        for record in records {
            if record.timestamp < thirtyDaysAgo {
                // Delete photo
                if let imageSize = try? storageService.getImageSize(filename: record.imageFilename) {
                    deletedSize += imageSize
                }
                try? storageService.deleteImage(filename: record.imageFilename)
            } else {
                remainingRecords.append(record)
            }
        }

        // Save remaining records
        try storageService.saveRecords(remainingRecords)

        return deletedSize
    }

    /// Delete exported files
    private func deleteExportedFiles() throws -> Int64 {
        let files = try CSVExporter.shared.getAllExportedFiles()

        var deletedSize: Int64 = 0

        for fileURL in files {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                deletedSize += Int64(size)
            }
            try CSVExporter.shared.deleteFile(at: fileURL)
        }

        return deletedSize
    }

    /// Delete all data
    private func deleteAllData() async throws -> Int64 {
        let beforeSize = getAppUsedSpace()

        // Get current user
        guard let username = FirebaseManager.shared.currentUser?.username else {
            throw NSError(
                domain: "StorageMonitor",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No current user found"]
            )
        }

        // Delete SwiftData records
        try await recordStorageService.deleteAllRecords(forUsername: username)

        // Delete legacy JSON records (for backward compatibility)
        try? storageService.deleteAllRecords()

        // Delete all photos (both old and new)
        try storageService.deleteAllImages()

        // Delete all exports
        try CSVExporter.shared.deleteAllExportedFiles()

        let afterSize = getAppUsedSpace()
        return beforeSize - afterSize
    }
}

// MARK: - Storage Status

/// Storage status
enum StorageStatus {
    case normal     // > 1GB available
    case warning    // 500MB - 1GB available
    case critical   // < 500MB available

    var title: String {
        switch self {
        case .normal:
            return "Normal"
        case .warning:
            return "Warning"
        case .critical:
            return "Critical"
        }
    }

    var color: UIColor {
        switch self {
        case .normal:
            return .systemGreen
        case .warning:
            return .systemOrange
        case .critical:
            return .systemRed
        }
    }

    var icon: String {
        switch self {
        case .normal:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .critical:
            return "xmark.octagon.fill"
        }
    }
}

// MARK: - Storage Info

/// Storage information
struct StorageInfo {
    let totalSpace: Int64
    let availableSpace: Int64
    let usedSpace: Int64
    let appUsedSpace: Int64
    let photosSize: Int64
    let recordsCount: Int
    let status: StorageStatus

    /// Used space percentage
    var usedPercentage: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(usedSpace) / Double(totalSpace)
    }

    /// App space percentage
    var appPercentage: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(appUsedSpace) / Double(totalSpace)
    }

    /// Formatted total space
    var formattedTotalSpace: String {
        ByteCountFormatter.string(fromByteCount: totalSpace, countStyle: .file)
    }

    /// Formatted available space
    var formattedAvailableSpace: String {
        ByteCountFormatter.string(fromByteCount: availableSpace, countStyle: .file)
    }

    /// Formatted used space
    var formattedUsedSpace: String {
        ByteCountFormatter.string(fromByteCount: usedSpace, countStyle: .file)
    }

    /// Formatted app used space
    var formattedAppUsedSpace: String {
        ByteCountFormatter.string(fromByteCount: appUsedSpace, countStyle: .file)
    }

    /// Formatted photos size
    var formattedPhotosSize: String {
        ByteCountFormatter.string(fromByteCount: photosSize, countStyle: .file)
    }
}

// MARK: - Cleanup Type

/// Cleanup type
enum CleanupType {
    case deleteOldRecords   // Delete old records
    case deleteExports      // Delete export files
    case deleteAllData      // Delete all data
    case compressPhotos     // Compress photos
}

// MARK: - Cleanup Suggestion

/// Cleanup suggestion
struct CleanupSuggestion {
    let type: CleanupType
    let title: String
    let description: String
    let estimatedSpace: Int64
    let priority: Priority

    enum Priority: Int {
        case low = 1
        case medium = 2
        case high = 3
    }

    /// Formatted estimated space
    var formattedEstimatedSpace: String {
        ByteCountFormatter.string(fromByteCount: estimatedSpace, countStyle: .file)
    }
}
