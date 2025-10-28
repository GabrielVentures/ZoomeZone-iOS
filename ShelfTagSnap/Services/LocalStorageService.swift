//
//  LocalStorageService.swift
//  ShelfTagSnap
//
//  Created by Claude on 2025/10/23.
//

import Foundation
import UIKit

/// Local storage service for managing scan records and images
class LocalStorageService {
    // MARK: - Singleton

    static let shared = LocalStorageService()

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let documentsDirectory: URL
    private let recordsURL: URL
    private let imagesDirectory: URL
    private let backupDirectory: URL

    // MARK: - Errors

    enum StorageError: LocalizedError {
        case fileNotFound
        case encodingFailed
        case decodingFailed
        case saveFailed
        case loadFailed

        var errorDescription: String? {
            switch self {
            case .fileNotFound:
                return "File not found"
            case .encodingFailed:
                return "Data encoding failed"
            case .decodingFailed:
                return "Data decoding failed"
            case .saveFailed:
                return "Save failed"
            case .loadFailed:
                return "Load failed"
            }
        }
    }

    // MARK: - Initialization

    private init() {
        // Get Documents directory
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]

        // Set paths
        recordsURL = documentsDirectory.appendingPathComponent("ScanRecords.json")
        imagesDirectory = documentsDirectory.appendingPathComponent("ScanImages")
        backupDirectory = documentsDirectory.appendingPathComponent("Backups")

        // Create required directories
        createDirectoriesIfNeeded()
    }

    // MARK: - Directory Management

    /// Create necessary directories
    private func createDirectoriesIfNeeded() {
        let directories = [imagesDirectory, backupDirectory]

        for directory in directories {
            if !fileManager.fileExists(atPath: directory.path) {
                try? fileManager.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }
        }
    }

    // MARK: - Record Operations

    /// Save scan records
    /// - Parameter records: Array of scan records
    /// - Throws: StorageError
    func saveRecords(_ records: [ScanRecord]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(records) else {
            throw StorageError.encodingFailed
        }

        // Atomic write: write to a temporary file first
        let tempURL = recordsURL.appendingPathExtension("tmp")

        do {
            try data.write(to: tempURL, options: .atomic)

            // If an old file exists, create a backup
            if fileManager.fileExists(atPath: recordsURL.path) {
                let backupURL = recordsURL.appendingPathExtension("backup")
                try? fileManager.removeItem(at: backupURL)
                try? fileManager.copyItem(at: recordsURL, to: backupURL)
            }

            // Replace the old file
            try? fileManager.removeItem(at: recordsURL)
            try fileManager.moveItem(at: tempURL, to: recordsURL)

        } catch {
            throw StorageError.saveFailed
        }
    }

    /// Load scan records
    /// - Returns: Array of scan records
    /// - Throws: StorageError
    func loadRecords() throws -> [ScanRecord] {
        // Check if file exists
        guard fileManager.fileExists(atPath: recordsURL.path) else {
            // File not found, return empty array
            return []
        }

        do {
            let data = try Data(contentsOf: recordsURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let records = try decoder.decode([ScanRecord].self, from: data)
            return records

        } catch {
            // Try to recover from backup
            return try loadFromBackup()
        }
    }

    /// Load from backup
    /// - Returns: Array of scan records
    /// - Throws: StorageError
    private func loadFromBackup() throws -> [ScanRecord] {
        let backupURL = recordsURL.appendingPathExtension("backup")

        guard fileManager.fileExists(atPath: backupURL.path) else {
            throw StorageError.fileNotFound
        }

        do {
            let data = try Data(contentsOf: backupURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let records = try decoder.decode([ScanRecord].self, from: data)

            // On success, copy back to the main file
            try? fileManager.copyItem(at: backupURL, to: recordsURL)

            return records

        } catch {
            throw StorageError.decodingFailed
        }
    }
    
    func getRecord(byBarcode barcode: String) -> ScanRecord? {
        guard let records = try? loadRecords() else {
            return nil
        }
        
        return records.first { $0.barcode == barcode }
    }

    // MARK: - Image Operations

    /// Save image
    /// - Parameters:
    ///   - image: UIImage
    ///   - filename: File name
    /// - Returns: Image URL
    /// - Throws: StorageError
    func saveImage(_ image: UIImage, filename: String) throws -> URL {
        // Optimization: Balanced for print quality and file size
        // 900px @ 58% quality → 200-500KB (perfect for reports & email)
        let maxDimension: CGFloat = 900
        let resizedImage = resizeImage(image, maxDimension: maxDimension)

        guard let data = resizedImage.jpegData(compressionQuality: 0.58) else {
            throw StorageError.encodingFailed
        }

        let fileURL = imagesDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            throw StorageError.saveFailed
        }
    }

    /// Resize image
    /// - Parameters:
    ///   - image: Original image
    ///   - maxDimension: Max width or height
    /// - Returns: Resized image
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size

        // If the image is already small enough, return as-is
        if size.width <= maxDimension && size.height <= maxDimension {
            return image
        }

        // Calculate scale
        let scale = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        // High-quality rendering
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// Load image
    /// - Parameter filename: File name
    /// - Returns: UIImage
    /// - Throws: StorageError
    func loadImage(filename: String) throws -> UIImage {
        let fileURL = imagesDirectory.appendingPathComponent(filename)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw StorageError.fileNotFound
        }

        guard let image = UIImage(contentsOfFile: fileURL.path) else {
            throw StorageError.loadFailed
        }

        return image
    }

    /// Delete image
    /// - Parameter filename: File name
    /// - Throws: Error
    func deleteImage(filename: String) throws {
        let fileURL = imagesDirectory.appendingPathComponent(filename)

        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }

    // MARK: - Backup Operations

    /// Create incremental backup
    func createIncrementalBackup() {
        guard fileManager.fileExists(atPath: recordsURL.path) else {
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())

        let backupFilename = "backup_\(timestamp).json"
        let backupURL = backupDirectory.appendingPathComponent(backupFilename)

        try? fileManager.copyItem(at: recordsURL, to: backupURL)

        // Clean old backups (keep the last 3 days)
        cleanOldBackups(keepDays: 3)
    }

    /// Clean old backups
    /// - Parameter keepDays: Number of days to keep
    private func cleanOldBackups(keepDays: Int) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -keepDays, to: Date())!

        guard let backupFiles = try? fileManager.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.creationDateKey]
        ) else {
            return
        }

        for fileURL in backupFiles {
            guard let creationDate = try? fileURL.resourceValues(forKeys: [.creationDateKey]).creationDate else {
                continue
            }

            if creationDate < cutoffDate {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }

    // MARK: - Storage Info

    /// Get used storage space in bytes
    /// - Returns: Total bytes used
    func getUsedSpace() -> Int64 {
        var totalSize: Int64 = 0

        // Sum images directory size
        if let imageFiles = try? fileManager.contentsOfDirectory(at: imagesDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for fileURL in imageFiles {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }

        // Add JSON file size
        if let recordSize = try? recordsURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
            totalSize += Int64(recordSize)
        }

        return totalSize
    }

    /// Get record count
    /// - Returns: Number of records
    func getRecordCount() -> Int {
        guard let records = try? loadRecords() else {
            return 0
        }
        return records.count
    }

    // MARK: - Cleanup Operations

    /// Delete all records
    func deleteAllRecords() throws {
        // Create backup
        if fileManager.fileExists(atPath: recordsURL.path) {
            let backupURL = recordsURL.appendingPathExtension("backup")
            try? fileManager.removeItem(at: backupURL)
            try? fileManager.copyItem(at: recordsURL, to: backupURL)
        }

        // Remove main file
        if fileManager.fileExists(atPath: recordsURL.path) {
            try fileManager.removeItem(at: recordsURL)
        }
    }

    /// Delete all images
    func deleteAllImages() throws {
        if let imageFiles = try? fileManager.contentsOfDirectory(at: imagesDirectory, includingPropertiesForKeys: nil) {
            for fileURL in imageFiles {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }

    /// Images directory
    var photosDirectory: URL {
        return imagesDirectory
    }

    /// Get image size
    func getImageSize(filename: String) throws -> Int64 {
        let fileURL = imagesDirectory.appendingPathComponent(filename)
        let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
        return Int64(resourceValues.fileSize ?? 0)
    }
}
