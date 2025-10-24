//
//  ExportManager.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/24.
//

import Foundation
import ZIPFoundation
import UIKit
import Combine

/// Export progress information

struct ExportProgress {
    let currentItem: Int
    let totalItems: Int
    let status: String

    var percentage: Double {
        guard totalItems > 0 else { return 0 }
        return Double(currentItem) / Double(totalItems)
    }
}

/// Export manager for creating ZIP archives with CSV and images

@MainActor
class ExportManager: ObservableObject {
    // MARK: - Singleton

    static let shared = ExportManager()

    // MARK: - Properties

    /// Progress handler

    @Published var progress: ExportProgress?

    /// Is currently exporting

    @Published var isExporting: Bool = false

    /// Export directory

    private lazy var exportDirectory: URL = {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let exportURL = documentsURL.appendingPathComponent("Exports", isDirectory: true)

        // Create directory if needed

        if !FileManager.default.fileExists(atPath: exportURL.path) {
            try? FileManager.default.createDirectory(at: exportURL, withIntermediateDirectories: true)
        }

        return exportURL
    }()

    // MARK: - Initialization

    private init() {}

    // MARK: - Export Methods

    /// Export records as ZIP containing CSV and all images

    ///

    func exportAsZIP(records: [ScanRecord]) async throws -> URL {
        guard !records.isEmpty else {
            throw ExportError.noRecords
        }

        isExporting = true
        defer { isExporting = false }

        do {
            // Step 1: Create temporary directory for export contents

            progress = ExportProgress(
                currentItem: 0,
                totalItems: records.count + 1,
                status: Strings.Export.preparing
            )

            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            // Step 2: Generate CSV file

            progress = ExportProgress(
                currentItem: 1,
                totalItems: records.count + 1,
                status: "Generating CSV..."
            )

            let csvURL = try CSVExporter.shared.export(records: records)
            let csvDestination = tempDir.appendingPathComponent("scan_records.csv")
            try FileManager.default.copyItem(at: csvURL, to: csvDestination)

            // Step 3: Copy all images

            let photosDir = tempDir.appendingPathComponent("photos", isDirectory: true)
            try FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)

            for (index, record) in records.enumerated() {
                progress = ExportProgress(
                    currentItem: index + 2,
                    totalItems: records.count + 1,
                    status: "\(Strings.Export.exportingFiles) (\(index + 1)/\(records.count))"
                )

                // Copy photo if it exists

                let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let imagesDirectory = documentsDirectory.appendingPathComponent("ScanImages")
                let photoURL = imagesDirectory.appendingPathComponent(record.imageFilename)

                if FileManager.default.fileExists(atPath: photoURL.path) {
                    let photoDestination = photosDir.appendingPathComponent(record.imageFilename)
                    try? FileManager.default.copyItem(at: photoURL, to: photoDestination)
                } else {

                    // Debug: Log missing images
                    print("⚠️ [EXPORT] Image not found: \(photoURL.path)")
                }

                // Small delay to make progress visible

                try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
            }

            // Step 4: Create ZIP archive

            progress = ExportProgress(
                currentItem: records.count + 1,
                totalItems: records.count + 1,
                status: Strings.Export.generatingZip
            )

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
            let timestamp = dateFormatter.string(from: Date())
            let zipFileName = "scan_records_\(timestamp).zip"
            let zipURL = exportDirectory.appendingPathComponent(zipFileName)

            // Remove existing ZIP if it exists

            if FileManager.default.fileExists(atPath: zipURL.path) {
                try FileManager.default.removeItem(at: zipURL)
            }

            // Create ZIP using ZIPFoundation

            try FileManager.default.zipItem(at: tempDir, to: zipURL, shouldKeepParent: false)

            // Step 5: Clean up temporary directory

            try? FileManager.default.removeItem(at: tempDir)

            // Clear progress

            progress = nil

            return zipURL

        } catch {
            // Clear progress on error

            progress = nil
            throw error
        }
    }

    /// Export records as CSV only (for backward compatibility)

    ///

    func exportAsCSV(records: [ScanRecord]) async throws -> URL {
        guard !records.isEmpty else {
            throw ExportError.noRecords
        }

        isExporting = true
        defer { isExporting = false }

        progress = ExportProgress(
            currentItem: 1,
            totalItems: 1,
            status: "Generating CSV..."
        )

        do {
            let url = try CSVExporter.shared.export(records: records)
            progress = nil
            return url
        } catch {
            progress = nil
            throw error
        }
    }

    // MARK: - File Management

    /// Clean up old export files (older than 7 days)

    func cleanupOldExports() {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(
            at: exportDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)

        for fileURL in files {
            guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                  let creationDate = attributes[.creationDate] as? Date else {
                continue
            }

            if creationDate < sevenDaysAgo {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }
}

// MARK: - Export Error

enum ExportError: LocalizedError {
    case noRecords
    case csvGenerationFailed
    case zipCreationFailed
    case fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .noRecords:
            return Strings.Export.noRecordsSelected
        case .csvGenerationFailed:
            return "Failed to generate CSV file"
        case .zipCreationFailed:
            return "Failed to create ZIP archive"
        case .fileNotFound(let fileName):
            return "File not found: \(fileName)"
        }
    }
}
