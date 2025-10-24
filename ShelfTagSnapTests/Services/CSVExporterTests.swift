//
//  CSVExporterTests.swift
//  ShelfTagSnapTests
//
//  Created by kent.sun on 2025/10/23.
//

import Testing
import Foundation
import CoreLocation
@testable import ShelfTagSnap

/// Unit tests for CSVExporter
@Suite("CSVExporter Tests")
struct CSVExporterTests {
    // MARK: - Basic Export Tests

    @Test("基本 CSV 导出 / Basic CSV export")
    func testBasicExport() async throws {
        let exporter = CSVExporter.shared

        // Create test records
        let records = [
            createMockRecord(
                username: "testuser",
                merchant: "walmart",
                barcode: "1234567890",
                storeLocation: "Floor 1"
            )
        ]

        // Export
        let fileURL = try exporter.export(records: records)

        // Verify file exists
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        // Read content
        let content = try String(contentsOf: fileURL, encoding: .utf8)

        // Verify contains header
        #expect(content.contains("Scan_ID,Username,Timestamp,Merchant,Barcode"))

        // Verify contains data
        #expect(content.contains("testuser"))
        #expect(content.contains("walmart"))
        #expect(content.contains("1234567890"))
        #expect(content.contains("Floor 1"))

        // Cleanup
        try? exporter.deleteFile(at: fileURL)
    }

    @Test("空记录导出 / Empty records export")
    func testEmptyExport() async throws {
        let exporter = CSVExporter.shared

        // Export empty list
        let fileURL = try exporter.export(records: [])

        // Verify file exists
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        // Read content
        let content = try String(contentsOf: fileURL, encoding: .utf8)

        // Should only contain header
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lines.count == 1)
        #expect(lines.first?.contains("Scan_ID") == true)

        // Cleanup
        try? exporter.deleteFile(at: fileURL)
    }

    // MARK: - Special Character Escaping Tests

    @Test("转义逗号 / Escape commas")
    func testEscapeCommas() async throws {
        let exporter = CSVExporter.shared

        // Data with commas
        let records = [
            createMockRecord(
                merchant: "walmart",
                storeLocation: "Floor 1, Section A"
            )
        ]

        let fileURL = try exporter.export(records: records)
        let content = try String(contentsOf: fileURL, encoding: .utf8)

        // Verify commas are properly escaped (wrapped in quotes)
        #expect(content.contains("\"Floor 1, Section A\""))

        // Cleanup
        try? exporter.deleteFile(at: fileURL)
    }

    @Test("转义换行符 / Escape newlines")
    func testEscapeNewlines() async throws {
        let exporter = CSVExporter.shared

        // Data with newlines
        let records = [
            createMockRecord(
                storeLocation: "Floor 1\nSection A"
            )
        ]

        let fileURL = try exporter.export(records: records)
        let content = try String(contentsOf: fileURL, encoding: .utf8)

        // Verify newlines are properly escaped
        #expect(content.contains("\"Floor 1\nSection A\""))

        // Cleanup
        try? exporter.deleteFile(at: fileURL)
    }

    @Test("转义引号 / Escape quotes")
    func testEscapeQuotes() async throws {
        let exporter = CSVExporter.shared

        // Data with quotes
        let records = [
            createMockRecord(
                storeLocation: "Floor 1 \"Main\""
            )
        ]

        let fileURL = try exporter.export(records: records)
        let content = try String(contentsOf: fileURL, encoding: .utf8)

        // Verify quotes are properly escaped (doubled)
        #expect(content.contains("\"Floor 1 \"\"Main\"\"\""))

        // Cleanup
        try? exporter.deleteFile(at: fileURL)
    }

    // MARK: - UTF-8 Encoding Tests

    @Test("UTF-8 编码 - 中文支持 / UTF-8 encoding - Chinese support")
    func testUTF8EncodingChinese() async throws {
        let exporter = CSVExporter.shared

        // Data with Chinese
        let records = [
            createMockRecord(
                username: "测试用户",
                merchant: "沃尔玛",
                storeLocation: "一楼入口"
            )
        ]

        let fileURL = try exporter.export(records: records)
        let content = try String(contentsOf: fileURL, encoding: .utf8)

        // Verify Chinese is correctly saved
        #expect(content.contains("测试用户"))
        #expect(content.contains("沃尔玛"))
        #expect(content.contains("一楼入口"))

        // Cleanup
        try? exporter.deleteFile(at: fileURL)
    }

    @Test("UTF-8 编码 - 多语言混合 / UTF-8 encoding - multilingual")
    func testUTF8EncodingMultilingual() async throws {
        let exporter = CSVExporter.shared

        // Multilingual data
        let records = [
            createMockRecord(
                username: "User用户",
                merchant: "walmart沃尔玛",
                storeLocation: "Floor 1 一楼"
            )
        ]

        let fileURL = try exporter.export(records: records)
        let content = try String(contentsOf: fileURL, encoding: .utf8)

        // Verify multilingual content is correctly saved
        #expect(content.contains("User用户"))
        #expect(content.contains("walmart沃尔玛"))
        #expect(content.contains("Floor 1 一楼"))

        // Cleanup
        try? exporter.deleteFile(at: fileURL)
    }

    // MARK: - Large Dataset Tests

    @Test("大数据集处理 / Large dataset processing")
    func testLargeDataset() async throws {
        let exporter = CSVExporter.shared

        // Create 15000 records (exceeds threshold 10000)
        var records: [ScanRecord] = []
        for i in 0..<15000 {
            records.append(createMockRecord(
                username: "user\(i)",
                barcode: String(format: "%013d", i)
            ))
        }

        // Export
        let fileURL = try exporter.export(records: records)

        // Verify file exists
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        // Read and verify record count
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }

        // Header + 15000 records
        #expect(lines.count == 15001)

        // Cleanup
        try? exporter.deleteFile(at: fileURL)
    }

    @Test("带进度的导出 / Export with progress")
    func testExportWithProgress() async throws {
        let exporter = CSVExporter.shared

        // Create 1000 records
        var records: [ScanRecord] = []
        for i in 0..<1000 {
            records.append(createMockRecord(barcode: "\(i)"))
        }

        var progressUpdates: [(current: Int, total: Int)] = []

        // Export with progress tracking
        let fileURL = try exporter.export(records: records) { current, total in
            progressUpdates.append((current, total))
        }

        // Verify progress updates
        #expect(progressUpdates.count > 0)
        #expect(progressUpdates.last?.current == 1000)
        #expect(progressUpdates.last?.total == 1000)

        // Cleanup
        try? exporter.deleteFile(at: fileURL)
    }

    // MARK: - File Size Estimation Tests

    @Test("文件大小预估 / File size estimation")
    func testFileSizeEstimation() async throws {
        let exporter = CSVExporter.shared

        // Estimate for 100 records
        let estimatedSize = exporter.estimateFileSize(for: 100)

        // Should return reasonable size (~200 bytes per record)
        #expect(estimatedSize > 10000)
        #expect(estimatedSize < 50000)
    }

    @Test("文件大小预估 - 零记录 / File size estimation - zero records")
    func testFileSizeEstimationZero() async throws {
        let exporter = CSVExporter.shared

        // Estimate for 0 records
        let estimatedSize = exporter.estimateFileSize(for: 0)

        // Should only include header size
        #expect(estimatedSize > 0)
        #expect(estimatedSize < 200)
    }

    // MARK: - File Management Tests

    @Test("获取所有导出文件 / Get all exported files")
    func testGetAllExportedFiles() async throws {
        let exporter = CSVExporter.shared

        // Clean existing files
        try? exporter.deleteAllExportedFiles()

        // Create several export files
        let records = [createMockRecord()]
        let file1 = try exporter.export(records: records)
        let file2 = try exporter.export(records: records)

        // Get all files
        let files = try exporter.getAllExportedFiles()

        // Should have 2 files
        #expect(files.count == 2)
        #expect(files.contains(file1))
        #expect(files.contains(file2))

        // Cleanup
        try? exporter.deleteAllExportedFiles()
    }

    @Test("删除所有导出文件 / Delete all exported files")
    func testDeleteAllExportedFiles() async throws {
        let exporter = CSVExporter.shared

        // Create several export files
        let records = [createMockRecord()]
        _ = try exporter.export(records: records)
        _ = try exporter.export(records: records)

        // Delete all files
        try exporter.deleteAllExportedFiles()

        // Verify no files
        let files = try exporter.getAllExportedFiles()
        #expect(files.isEmpty)
    }

    @Test("删除指定文件 / Delete specific file")
    func testDeleteSpecificFile() async throws {
        let exporter = CSVExporter.shared

        // Create export file
        let records = [createMockRecord()]
        let fileURL = try exporter.export(records: records)

        // Verify file exists
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        // Delete file
        try exporter.deleteFile(at: fileURL)

        // Verify file deleted
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    // MARK: - Export Statistics Tests

    @Test("导出统计计算 / Export statistics calculation")
    func testExportStatisticsCalculation() async throws {

        // Create test records
        let date1 = Date(timeIntervalSince1970: 1000000)
        let date2 = Date(timeIntervalSince1970: 2000000)

        let record1 = ScanRecord(
            username: "user1",
            merchant: "walmart",
            barcode: "123",
            location: nil,
            storeLocation: nil,
            imageFilename: "test1.jpg"
        )
        var record1Modified = record1
        record1Modified.timestamp = date1

        let record2 = ScanRecord(
            username: "user2",
            merchant: "target",
            barcode: "456",
            location: nil,
            storeLocation: nil,
            imageFilename: "test2.jpg"
        )
        var record2Modified = record2
        record2Modified.timestamp = date2

        let records = [record1Modified, record2Modified]

        // Calculate statistics
        let stats = ExportStatistics.calculate(from: records)

        // Verify statistics
        #expect(stats.totalRecords == 2)
        #expect(stats.dateRange?.start == date1)
        #expect(stats.dateRange?.end == date2)
        #expect(stats.estimatedFileSize > 0)
    }

    @Test("导出统计 - 空记录 / Export statistics - empty records")
    func testExportStatisticsEmpty() async throws {
        let stats = ExportStatistics.calculate(from: [])

        #expect(stats.totalRecords == 0)
        #expect(stats.dateRange == nil)
        #expect(stats.estimatedFileSize > 0)
    }

    @Test("导出统计 - 格式化文件大小 / Export statistics - formatted file size")
    func testFormattedFileSize() async throws {
        let stats = ExportStatistics(
            totalRecords: 100,
            dateRange: nil,
            estimatedFileSize: 25000 // 25 KB
        )

        let formatted = stats.formattedFileSize

        // Should contain KB or MB
        #expect(formatted.contains("KB") || formatted.contains("MB"))
    }

    @Test("导出统计 - 格式化日期范围 / Export statistics - formatted date range")
    func testFormattedDateRange() async throws {
        let date1 = Date(timeIntervalSince1970: 1704067200) // 2024-01-01
        let date2 = Date(timeIntervalSince1970: 1735689600) // 2025-01-01

        let stats = ExportStatistics(
            totalRecords: 100,
            dateRange: (start: date1, end: date2),
            estimatedFileSize: 25000
        )

        let formatted = stats.formattedDateRange

        // Should contain dates
        #expect(formatted?.contains("2024") == true)
        #expect(formatted?.contains("2025") == true)
        #expect(formatted?.contains("~") == true)
    }

    // MARK: - GPS Coordinates Tests

    @Test("GPS 坐标导出 / GPS coordinates export")
    func testGPSCoordinatesExport() async throws {
        let exporter = CSVExporter.shared

        // Create record with GPS
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let record = ScanRecord(
            username: "testuser",
            merchant: "walmart",
            barcode: "123",
            location: location,
            storeLocation: nil,
            imageFilename: "test.jpg"
        )

        let fileURL = try exporter.export(records: [record])
        let content = try String(contentsOf: fileURL, encoding: .utf8)

        // Verify coordinate format (6 decimal places)
        #expect(content.contains("37.774900"))
        #expect(content.contains("-122.419400"))

        // Cleanup
        try? exporter.deleteFile(at: fileURL)
    }

    @Test("无 GPS 坐标导出 / Export without GPS coordinates")
    func testNoGPSCoordinatesExport() async throws {
        let exporter = CSVExporter.shared

        // Create record without GPS
        let record = createMockRecord()

        let fileURL = try exporter.export(records: [record])
        let content = try String(contentsOf: fileURL, encoding: .utf8)

        // Verify CSV format (GPS fields should be empty)
        let lines = content.components(separatedBy: "\n")
        let dataLine = lines[1]
        let fields = dataLine.components(separatedBy: ",")

        // Latitude and Longitude fields should be empty
        #expect(fields[5].isEmpty) // Latitude
        #expect(fields[6].isEmpty) // Longitude

        // Cleanup
        try? exporter.deleteFile(at: fileURL)
    }

    // MARK: - Helper Methods

    /// Create mock record
    private func createMockRecord(
        username: String = "testuser",
        merchant: String = "walmart",
        barcode: String = "1234567890",
        storeLocation: String? = nil
    ) -> ScanRecord {
        return ScanRecord(
            username: username,
            merchant: merchant,
            barcode: barcode,
            location: nil,
            storeLocation: storeLocation,
            imageFilename: "test.jpg"
        )
    }
}
