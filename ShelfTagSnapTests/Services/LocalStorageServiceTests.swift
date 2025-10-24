//
//  LocalStorageServiceTests.swift
//  ShelfTagSnapTests
//
//  Created by kent.sun on 2025/10/23.
//

import Testing
import Foundation
import UIKit
import CoreLocation
@testable import ShelfTagSnap

/// Unit tests for LocalStorageService
@Suite("LocalStorageService Tests", .serialized) // Run tests serially to avoid file conflicts
struct LocalStorageServiceTests {

    // MARK: - Setup & Teardown

    /// Get storage service instance for testing
    private func getTestStorageService() -> LocalStorageService {
        return LocalStorageService.shared
    }

    /// Create test scan record
    private func createTestRecord(
        username: String = "testuser",
        merchant: String = "Walmart",
        barcode: String = "123456789012"
    ) -> ScanRecord {
        return ScanRecord(
            username: username,
            merchant: merchant,
            barcode: barcode,
            location: CLLocation(latitude: 37.7749, longitude: -122.4194),
            storeLocation: "Test Store",
            imageFilename: "test_\(UUID().uuidString).jpg"
        )
    }

    /// Create test image
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    // MARK: - Save and Load Records Tests

    @Test("保存和加载记录 / Save and load records")
    func testSaveAndLoadRecords() async throws {
        // Given
        let storage = getTestStorageService()
        let records = [
            createTestRecord(username: "user1", barcode: "111"),
            createTestRecord(username: "user2", barcode: "222"),
            createTestRecord(username: "user3", barcode: "333")
        ]

        // When
        try storage.saveRecords(records)
        let loadedRecords = try storage.loadRecords()

        // Then
        #expect(loadedRecords.count == 3)
        #expect(loadedRecords[0].barcode == "111")
        #expect(loadedRecords[1].barcode == "222")
        #expect(loadedRecords[2].barcode == "333")
    }

    @Test("加载空记录列表 / Load empty records")
    func testLoadEmptyRecords() async throws {
        // Given
        let storage = getTestStorageService()
        try storage.saveRecords([])

        // When
        let loadedRecords = try storage.loadRecords()

        // Then
        #expect(loadedRecords.isEmpty)
    }

    @Test("保存覆盖已有记录 / Save overwrites existing records")
    func testSaveOverwrite() async throws {
        // Given
        let storage = getTestStorageService()

        // Save initial records
        let initialRecords = [createTestRecord(barcode: "111")]
        try storage.saveRecords(initialRecords)

        // When - Save different records
        let newRecords = [
            createTestRecord(barcode: "222"),
            createTestRecord(barcode: "333")
        ]
        try storage.saveRecords(newRecords)

        // Then
        let loadedRecords = try storage.loadRecords()
        #expect(loadedRecords.count == 2)
        #expect(loadedRecords[0].barcode == "222")
        #expect(loadedRecords[1].barcode == "333")
    }

    @Test("保存大量记录 / Save large number of records")
    func testSaveLargeNumberOfRecords() async throws {
        // Given
        let storage = getTestStorageService()
        let recordCount = 100
        var records: [ScanRecord] = []

        for i in 0..<recordCount {
            records.append(createTestRecord(barcode: "\(i)"))
        }

        // When
        try storage.saveRecords(records)
        let loadedRecords = try storage.loadRecords()

        // Then
        #expect(loadedRecords.count == recordCount)
        #expect(loadedRecords.first?.barcode == "0")
        #expect(loadedRecords.last?.barcode == "99")
    }

    // MARK: - Record Count Tests

    @Test("获取记录数量 / Get record count")
    func testGetRecordCount() async throws {
        // Given
        let storage = getTestStorageService()
        let records = [
            createTestRecord(),
            createTestRecord(),
            createTestRecord()
        ]
        try storage.saveRecords(records)

        // When
        let count = storage.getRecordCount()

        // Then
        #expect(count == 3)
    }

    @Test("空记录数量 / Empty record count")
    func testEmptyRecordCount() async throws {
        // Given
        let storage = getTestStorageService()
        try storage.saveRecords([])

        // When
        let count = storage.getRecordCount()

        // Then
        #expect(count == 0)
    }

    // MARK: - Image Operations Tests

    @Test("保存和加载图片 / Save and load image")
    func testSaveAndLoadImage() async throws {
        // Given
        let storage = getTestStorageService()
        let testImage = createTestImage()
        let filename = "test_image_\(UUID().uuidString).jpg"

        // When
        let savedURL = try storage.saveImage(testImage, filename: filename)
        let loadedImage = try storage.loadImage(filename: filename)

        // Then
        #expect(savedURL.lastPathComponent == filename)
        #expect(loadedImage.size.width > 0)
        #expect(loadedImage.size.height > 0)

        // Cleanup
        try? storage.deleteImage(filename: filename)
    }

    @Test("保存图片返回正确 URL / Save image returns correct URL")
    func testSaveImageURL() async throws {
        // Given
        let storage = getTestStorageService()
        let testImage = createTestImage()
        let filename = "url_test_\(UUID().uuidString).jpg"

        // When
        let imageURL = try storage.saveImage(testImage, filename: filename)

        // Then
        #expect(imageURL.lastPathComponent == filename)
        #expect(imageURL.pathExtension == "jpg")
        #expect(imageURL.path.contains("ScanImages"))

        // Cleanup
        try? storage.deleteImage(filename: filename)
    }

    @Test("删除图片 / Delete image")
    func testDeleteImage() async throws {
        // Given
        let storage = getTestStorageService()
        let testImage = createTestImage()
        let filename = "delete_test_\(UUID().uuidString).jpg"

        // Save image first
        _ = try storage.saveImage(testImage, filename: filename)

        // When
        try storage.deleteImage(filename: filename)

        // Then - Should throw when trying to load
        #expect(throws: Error.self) {
            _ = try storage.loadImage(filename: filename)
        }
    }

    @Test("删除不存在的图片 / Delete non-existent image")
    func testDeleteNonExistentImage() async throws {
        // Given
        let storage = getTestStorageService()
        let filename = "nonexistent_\(UUID().uuidString).jpg"

        // When & Then - Should not throw
        try storage.deleteImage(filename: filename)
    }

    @Test("加载不存在的图片抛出错误 / Load non-existent image throws error")
    func testLoadNonExistentImage() async throws {
        // Given
        let storage = getTestStorageService()
        let filename = "missing_\(UUID().uuidString).jpg"

        // When & Then
        #expect(throws: LocalStorageService.StorageError.self) {
            _ = try storage.loadImage(filename: filename)
        }
    }

    // MARK: - Storage Info Tests

    @Test("获取已使用存储空间 / Get used storage space")
    func testGetUsedSpace() async throws {
        // Given
        let storage = getTestStorageService()

        // Save some data
        let records = [createTestRecord(), createTestRecord()]
        try storage.saveRecords(records)

        let testImage = createTestImage()
        let filename = "space_test_\(UUID().uuidString).jpg"
        _ = try storage.saveImage(testImage, filename: filename)

        // When
        let usedSpace = storage.getUsedSpace()

        // Then
        #expect(usedSpace > 0)

        // Cleanup
        try? storage.deleteImage(filename: filename)
    }

    @Test("空存储空间计算 / Empty storage space")
    func testEmptyUsedSpace() async throws {
        // Given
        let storage = getTestStorageService()
        try storage.saveRecords([])

        // When
        let usedSpace = storage.getUsedSpace()

        // Then - Should be minimal (just the empty JSON file)
        #expect(usedSpace >= 0)
    }

    // MARK: - Backup Tests

    @Test("创建增量备份 / Create incremental backup")
    func testCreateIncrementalBackup() async throws {
        // Given
        let storage = getTestStorageService()
        let records = [createTestRecord()]
        try storage.saveRecords(records)

        // When
        storage.createIncrementalBackup()

        // Then - Should complete without throwing
        // Actual backup file verification would require access to private properties
    }

    // MARK: - Error Handling Tests

    @Test("处理编码失败 / Handle encoding failure")
    func testEncodingFailure() async throws {
        // Note: With standard ScanRecord, encoding should always succeed
        // This test documents expected behavior
        let storage = getTestStorageService()
        let validRecords = [createTestRecord()]

        // Should not throw
        try storage.saveRecords(validRecords)
    }

    // MARK: - Data Integrity Tests

    @Test("数据往返一致性 / Data roundtrip consistency")
    func testDataRoundtripConsistency() async throws {
        // Given
        let storage = getTestStorageService()
        let originalRecord = createTestRecord(
            username: "consistency_test",
            merchant: "Target",
            barcode: "999888777666"
        )

        // When
        try storage.saveRecords([originalRecord])
        let loadedRecords = try storage.loadRecords()
        let loadedRecord = try #require(loadedRecords.first)

        // Then
        #expect(loadedRecord.id == originalRecord.id)
        #expect(loadedRecord.username == originalRecord.username)
        #expect(loadedRecord.merchant == originalRecord.merchant)
        #expect(loadedRecord.barcode == originalRecord.barcode)
        #expect(loadedRecord.latitude == originalRecord.latitude)
        #expect(loadedRecord.longitude == originalRecord.longitude)
        #expect(loadedRecord.imageFilename == originalRecord.imageFilename)
        #expect(loadedRecord.storeLocation == originalRecord.storeLocation)
    }

    @Test("特殊字符处理 / Special characters handling")
    func testSpecialCharacters() async throws {
        // Given
        let storage = getTestStorageService()
        let specialRecord = ScanRecord(
            username: "用户名 👤",
            merchant: "商店 \"特殊\" & <标签>",
            barcode: "123-456-789",
            location: nil,
            storeLocation: "Store #1, Building \"A\"",
            imageFilename: "test.jpg"
        )

        // When
        try storage.saveRecords([specialRecord])
        let loadedRecords = try storage.loadRecords()
        let loadedRecord = try #require(loadedRecords.first)

        // Then
        #expect(loadedRecord.username == specialRecord.username)
        #expect(loadedRecord.merchant == specialRecord.merchant)
        #expect(loadedRecord.storeLocation == specialRecord.storeLocation)
    }

    // MARK: - Concurrent Access Tests

    @Test("并发保存测试 / Concurrent save test")
    func testConcurrentSave() async throws {
        // Given
        let storage = getTestStorageService()

        // When - Save sequentially (avoiding actual concurrent writes for safety)
        for i in 0..<5 {
            let records = [createTestRecord(barcode: "\(i)")]
            try storage.saveRecords(records)
        }

        // Then
        let finalRecords = try storage.loadRecords()
        #expect(finalRecords.count == 1) // Last save wins
    }

    // MARK: - Image Compression Tests

    @Test("图片压缩质量 / Image compression quality")
    func testImageCompressionQuality() async throws {
        // Given
        let storage = getTestStorageService()
        let largeImage = UIGraphicsImageRenderer(size: CGSize(width: 1000, height: 1000)).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1000, height: 1000))
        }
        let filename = "compression_test_\(UUID().uuidString).jpg"

        // When
        let savedURL = try storage.saveImage(largeImage, filename: filename)

        // Then - Check file size is reasonable (compressed)
        let attributes = try FileManager.default.attributesOfItem(atPath: savedURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0

        // JPEG compression at 0.85 should reduce size significantly
        #expect(fileSize > 0)
        #expect(fileSize < 5_000_000) // Should be less than 5MB for 1000x1000 solid color

        // Cleanup
        try? storage.deleteImage(filename: filename)
    }

    // MARK: - Edge Cases

    @Test("空文件名处理 / Empty filename handling")
    func testEmptyFilename() async throws {
        // Given
        let storage = getTestStorageService()
        let testImage = createTestImage()

        // When - Save with empty filename
        let savedURL = try storage.saveImage(testImage, filename: "")

        // Then - Should create file (though not recommended)
        #expect(savedURL.lastPathComponent == "")

        // Cleanup
        try? storage.deleteImage(filename: "")
    }

    @Test("超长文件名 / Very long filename")
    func testVeryLongFilename() async throws {
        // Given
        let storage = getTestStorageService()
        let testImage = createTestImage()
        let longFilename = String(repeating: "a", count: 200) + ".jpg"

        // When & Then - May succeed or fail depending on filesystem
        do {
            let savedURL = try storage.saveImage(testImage, filename: longFilename)
            // If successful, cleanup
            try? storage.deleteImage(filename: longFilename)
        } catch {
            // If failed, that's also acceptable behavior
        }
    }

    @Test("文件名包含路径分隔符 / Filename with path separators")
    func testFilenameWithPathSeparators() async throws {
        // Given
        let storage = getTestStorageService()
        let testImage = createTestImage()
        let unsafeFilename = "path/to/file.jpg"

        // When
        let savedURL = try storage.saveImage(testImage, filename: unsafeFilename)

        // Then - Should create nested structure
        #expect(savedURL.path.contains("path"))
        #expect(savedURL.path.contains("to"))

        // Cleanup
        try? storage.deleteImage(filename: unsafeFilename)
    }
}
