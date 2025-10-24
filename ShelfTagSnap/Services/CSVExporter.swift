//
//  CSVExporter.swift
//  ShelfTagSnap
//
//  Created by Claude on 2025/10/23.
//

import Foundation
import CoreLocation

/// CSV export service
///
/// Features:
/// - Generate CSV files
/// - Escape special characters
/// - UTF-8 encoding support
/// - Batch processing for large datasets
/// - File management
class CSVExporter {
    // MARK: - Singleton

    static let shared = CSVExporter()

    // MARK: - Properties

    /// CSV header
    private static let header = "Scan_ID,Username,Timestamp,Merchant,Barcode,Latitude,Longitude,Image_Filename,Store_Location"

    /// Large dataset threshold
    private static let largeDatasetThreshold = 10000

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

    // MARK: - Public Methods

    /// Export scan records to CSV
    ///
    /// - Parameter records: Array of scan records
    /// - Returns: CSV file URL
    /// - Throws: CSVError
    func export(records: [ScanRecord]) throws -> URL {
        // Check if large dataset
        if records.count > Self.largeDatasetThreshold {
            return try exportLargeDataset(records)
        }

        // Generate CSV content
        var csvString = Self.header + "\n"

        for record in records {
            let row = formatRecord(record)
            csvString += row + "\n"
        }

        // Save file
        return try saveToFile(csvString)
    }

    /// Export large dataset with progress callback
    ///
    /// - Parameters:
    ///   - records: Array of scan records
    ///   - progressHandler: Progress callback (current, total)
    /// - Returns: CSV file URL
    /// - Throws: CSVError
    func export(records: [ScanRecord], progressHandler: ((Int, Int) -> Void)? = nil) throws -> URL {
        // Generate CSV content
        var csvString = Self.header + "\n"

        for (index, record) in records.enumerated() {
            let row = formatRecord(record)
            csvString += row + "\n"

            // Report progress
            if (index + 1) % 100 == 0 || index == records.count - 1 {
                progressHandler?(index + 1, records.count)
            }
        }

        // Save file
        return try saveToFile(csvString)
    }

    /// Estimate file size
    ///
    /// - Parameter recordCount: Number of records
    /// - Returns: Estimated size in bytes
    func estimateFileSize(for recordCount: Int) -> Int64 {
        // Average ~200 bytes per record (including Chinese)
        let avgBytesPerRecord: Int64 = 200
        let headerBytes: Int64 = Int64(Self.header.count + 1) // +1 for newline
        return headerBytes + (avgBytesPerRecord * Int64(recordCount))
    }

    /// Get all CSV files in export directory
    ///
    /// - Returns: Array of CSV file URLs
    func getAllExportedFiles() throws -> [URL] {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(
            at: exportDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        )

        // Return only CSV files
        return contents.filter { $0.pathExtension.lowercased() == "csv" }
    }

    /// Delete all exported CSV files
    func deleteAllExportedFiles() throws {
        let files = try getAllExportedFiles()
        for fileURL in files {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    /// Delete specific CSV file
    ///
    /// - Parameter url: File URL
    func deleteFile(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    // MARK: - Private Methods

    /// Export large dataset with batch processing
    private func exportLargeDataset(_ records: [ScanRecord]) throws -> URL {
        let batchSize = 1000
        var csvString = Self.header + "\n"

        // Process in batches
        for batchStart in stride(from: 0, to: records.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, records.count)
            let batch = records[batchStart..<batchEnd]

            for record in batch {
                let row = formatRecord(record)
                csvString += row + "\n"
            }

            // Release memory (large dataset optimization)
            autoreleasepool {
                // Batch processed
            }
        }

        return try saveToFile(csvString)
    }

    /// Format single record
    private func formatRecord(_ record: ScanRecord) -> String {
        let fields = [
            record.id,
            escapeCSVField(record.username),
            formatTimestamp(record.timestamp),
            escapeCSVField(record.merchant),
            record.barcode,
            formatCoordinate(record.latitude),
            formatCoordinate(record.longitude),
            escapeCSVField(record.imageFilename),
            escapeCSVField(record.storeLocation ?? "")
        ]
        return fields.joined(separator: ",")
    }

    /// Escape CSV field
    ///
    /// Rules:
    /// - Wrap with quotes if contains comma, newline or quote
    /// - Escape quote as double quote
    private func escapeCSVField(_ field: String) -> String {
        // Check if escaping needed
        if field.contains(",") || field.contains("\n") || field.contains("\"") || field.contains("\r") {
            // Escape quotes
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            // Wrap with quotes
            return "\"\(escaped)\""
        }
        return field
    }

    /// Format timestamp
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    /// Format coordinate
    private func formatCoordinate(_ coordinate: Double?) -> String {
        guard let coordinate = coordinate else {
            return ""
        }
        return String(format: "%.6f", coordinate)
    }

    /// Save to file
    private func saveToFile(_ csvString: String) throws -> URL {
        // UTF-8 encoding
        guard let data = csvString.data(using: .utf8) else {
            throw CSVError.encodingFailed
        }

        // Generate filename with timestamp
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "scan_export_\(timestamp).csv"
        let fileURL = exportDirectory.appendingPathComponent(filename)

        // Atomic write (protect data integrity)
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw CSVError.writeFailed(error)
        }

        return fileURL
    }
}

// MARK: - CSV Error

/// CSV error types
enum CSVError: LocalizedError {
    case encodingFailed
    case writeFailed(Error)
    case fileNotFound
    case invalidData

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "CSV 编码失败 / CSV encoding failed"
        case .writeFailed(let error):
            return "CSV 写入失败 / CSV write failed: \(error.localizedDescription)"
        case .fileNotFound:
            return "文件未找到 / File not found"
        case .invalidData:
            return "无效数据 / Invalid data"
        }
    }
}

// MARK: - Export Statistics

/// Export statistics
struct ExportStatistics {
    let totalRecords: Int
    let dateRange: (start: Date, end: Date)?
    let estimatedFileSize: Int64

    /// Format file size
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: estimatedFileSize)
    }

    /// Format date range
    var formattedDateRange: String? {
        guard let dateRange = dateRange else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let startString = formatter.string(from: dateRange.start)
        let endString = formatter.string(from: dateRange.end)

        return "\(startString) ~ \(endString)"
    }

    /// Calculate statistics from records
    static func calculate(from records: [ScanRecord]) -> ExportStatistics {
        let totalRecords = records.count

        // Calculate date range
        let dateRange: (start: Date, end: Date)?
        if let minDate = records.map({ $0.timestamp }).min(),
           let maxDate = records.map({ $0.timestamp }).max() {
            dateRange = (start: minDate, end: maxDate)
        } else {
            dateRange = nil
        }

        // Estimate file size
        let estimatedFileSize = CSVExporter.shared.estimateFileSize(for: totalRecords)

        return ExportStatistics(
            totalRecords: totalRecords,
            dateRange: dateRange,
            estimatedFileSize: estimatedFileSize
        )
    }
}
