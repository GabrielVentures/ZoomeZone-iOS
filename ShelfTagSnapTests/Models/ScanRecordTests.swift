//
//  ScanRecordTests.swift
//  ShelfTagSnapTests
//
//  Created by kent.sun on 2025/10/23.
//

import Testing
import CoreLocation
@testable import ShelfTagSnap

/// Unit tests for ScanRecord model
struct ScanRecordTests {

    // MARK: - Initialization Tests

    @Test("创建扫描记录 / Create scan record")
    func testScanRecordCreation() async throws {
        // Given
        let username = "testuser"
        let merchant = "Walmart"
        let barcode = "123456789012"
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let storeLocation = "San Francisco Store"
        let imageFilename = "scan_123.jpg"

        // When
        let record = ScanRecord(
            username: username,
            merchant: merchant,
            barcode: barcode,
            location: location,
            storeLocation: storeLocation,
            imageFilename: imageFilename
        )

        // Then
        #expect(record.username == username)
        #expect(record.merchant == merchant)
        #expect(record.barcode == barcode)
        #expect(record.latitude == 37.7749)
        #expect(record.longitude == -122.4194)
        #expect(record.storeLocation == storeLocation)
        #expect(record.imageFilename == imageFilename)
        #expect(record.isSynced == false)
        #expect(!record.id.isEmpty)
    }

    @Test("创建无位置信息的扫描记录 / Create scan record without location")
    func testScanRecordCreationWithoutLocation() async throws {
        // Given
        let username = "testuser"
        let merchant = "Target"
        let barcode = "987654321098"
        let imageFilename = "scan_456.jpg"

        // When
        let record = ScanRecord(
            username: username,
            merchant: merchant,
            barcode: barcode,
            location: nil,
            storeLocation: nil,
            imageFilename: imageFilename
        )

        // Then
        #expect(record.latitude == nil)
        #expect(record.longitude == nil)
        #expect(record.storeLocation == nil)
        #expect(record.hasLocation == false)
        #expect(record.coordinate == nil)
    }

    // MARK: - Computed Properties Tests

    @Test("格式化时间戳 / Format timestamp")
    func testFormattedTimestamp() async throws {
        // Given
        let record = ScanRecord(
            username: "testuser",
            merchant: "Costco",
            barcode: "111222333444",
            location: nil,
            storeLocation: nil,
            imageFilename: "test.jpg"
        )

        // When
        let formatted = record.formattedTimestamp

        // Then
        #expect(!formatted.isEmpty)
        #expect(formatted.contains("-")) // Should contain date separators
        #expect(formatted.contains(":")) // Should contain time separators
    }

    @Test("检查位置信息 / Check location availability")
    func testHasLocation() async throws {
        // Given - with location
        let locationRecord = ScanRecord(
            username: "user1",
            merchant: "Walmart",
            barcode: "123",
            location: CLLocation(latitude: 40.7128, longitude: -74.0060),
            storeLocation: "NYC Store",
            imageFilename: "scan1.jpg"
        )

        // Given - without location
        let noLocationRecord = ScanRecord(
            username: "user2",
            merchant: "Target",
            barcode: "456",
            location: nil,
            storeLocation: nil,
            imageFilename: "scan2.jpg"
        )

        // Then
        #expect(locationRecord.hasLocation == true)
        #expect(noLocationRecord.hasLocation == false)
    }

    @Test("获取 GPS 坐标 / Get GPS coordinate")
    func testCoordinate() async throws {
        // Given
        let latitude = 34.0522
        let longitude = -118.2437
        let location = CLLocation(latitude: latitude, longitude: longitude)

        let record = ScanRecord(
            username: "testuser",
            merchant: "Kroger",
            barcode: "789",
            location: location,
            storeLocation: "LA Store",
            imageFilename: "scan.jpg"
        )

        // When
        let coordinate = record.coordinate

        // Then
        #expect(coordinate != nil)
        #expect(coordinate?.latitude == latitude)
        #expect(coordinate?.longitude == longitude)
    }

    // MARK: - Codable Tests

    @Test("JSON 编码和解码 / JSON encoding and decoding")
    func testCodable() async throws {
        // Given
        let originalRecord = ScanRecord(
            username: "testuser",
            merchant: "Walmart",
            barcode: "123456789012",
            location: CLLocation(latitude: 37.7749, longitude: -122.4194),
            storeLocation: "SF Store",
            imageFilename: "scan_test.jpg"
        )

        // When - Encode
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(originalRecord)

        // When - Decode
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedRecord = try decoder.decode(ScanRecord.self, from: jsonData)

        // Then
        #expect(decodedRecord.id == originalRecord.id)
        #expect(decodedRecord.username == originalRecord.username)
        #expect(decodedRecord.merchant == originalRecord.merchant)
        #expect(decodedRecord.barcode == originalRecord.barcode)
        #expect(decodedRecord.latitude == originalRecord.latitude)
        #expect(decodedRecord.longitude == originalRecord.longitude)
        #expect(decodedRecord.imageFilename == originalRecord.imageFilename)
        #expect(decodedRecord.storeLocation == originalRecord.storeLocation)
    }

    @Test("验证 CodingKeys 映射 / Verify CodingKeys mapping")
    func testCodingKeys() async throws {
        // Given
        let record = ScanRecord(
            username: "test",
            merchant: "Target",
            barcode: "123",
            location: nil,
            storeLocation: "Store 1",
            imageFilename: "test.jpg"
        )

        // When
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(record)
        let jsonString = String(data: jsonData, encoding: .utf8)!

        // Then - Verify custom CodingKeys are used
        #expect(jsonString.contains("\"Scan_ID\""))
        #expect(jsonString.contains("\"Username\""))
        #expect(jsonString.contains("\"Timestamp\""))
        #expect(jsonString.contains("\"Merchant\""))
        #expect(jsonString.contains("\"Barcode\""))
        #expect(jsonString.contains("\"Image_Filename\""))
        #expect(jsonString.contains("\"Store_Location\""))
    }

    // MARK: - CSV Export Tests

    @Test("导出 CSV 行 / Export CSV row")
    func testToCSVRow() async throws {
        // Given
        let record = ScanRecord(
            username: "testuser",
            merchant: "Walmart",
            barcode: "123456789012",
            location: CLLocation(latitude: 37.774900, longitude: -122.419400),
            storeLocation: "SF Store",
            imageFilename: "scan_001.jpg"
        )

        // When
        let csvRow = record.toCSVRow()

        // Then
        #expect(csvRow.contains(record.id))
        #expect(csvRow.contains("testuser"))
        #expect(csvRow.contains("Walmart"))
        #expect(csvRow.contains("123456789012"))
        #expect(csvRow.contains("37.774900"))
        #expect(csvRow.contains("-122.419400"))
        #expect(csvRow.contains("scan_001.jpg"))
        #expect(csvRow.contains("SF Store"))
    }

    @Test("CSV 字段转义 - 包含逗号 / CSV field escaping - with comma")
    func testCSVEscapingWithComma() async throws {
        // Given
        let storeWithComma = "Store 1, Building A"
        let record = ScanRecord(
            username: "test",
            merchant: "Target",
            barcode: "123",
            location: nil,
            storeLocation: storeWithComma,
            imageFilename: "test.jpg"
        )

        // When
        let csvRow = record.toCSVRow()

        // Then - Should be wrapped in quotes
        #expect(csvRow.contains("\"Store 1, Building A\""))
    }

    @Test("CSV 字段转义 - 包含引号 / CSV field escaping - with quotes")
    func testCSVEscapingWithQuotes() async throws {
        // Given
        let merchantWithQuote = "Store \"Premium\""
        let record = ScanRecord(
            username: "test",
            merchant: merchantWithQuote,
            barcode: "456",
            location: nil,
            storeLocation: nil,
            imageFilename: "test.jpg"
        )

        // When
        let csvRow = record.toCSVRow()

        // Then - Quotes should be doubled and wrapped
        #expect(csvRow.contains("\"Store \"\"Premium\"\"\""))
    }

    @Test("CSV 空位置字段 / CSV empty location fields")
    func testCSVWithNullLocation() async throws {
        // Given
        let record = ScanRecord(
            username: "test",
            merchant: "Costco",
            barcode: "789",
            location: nil,
            storeLocation: nil,
            imageFilename: "test.jpg"
        )

        // When
        let csvRow = record.toCSVRow()
        let components = csvRow.components(separatedBy: ",")

        // Then - Latitude and Longitude fields should be empty
        #expect(components.count == 9) // Total 9 fields
        #expect(components[5].isEmpty) // Latitude
        #expect(components[6].isEmpty) // Longitude
        #expect(components[8].isEmpty) // Store_Location
    }

    // MARK: - Hashable and Identifiable Tests

    @Test("唯一 ID 生成 / Unique ID generation")
    func testUniqueIDGeneration() async throws {
        // Given & When
        let record1 = ScanRecord(
            username: "user1",
            merchant: "Walmart",
            barcode: "123",
            location: nil,
            storeLocation: nil,
            imageFilename: "test1.jpg"
        )

        let record2 = ScanRecord(
            username: "user1",
            merchant: "Walmart",
            barcode: "123",
            location: nil,
            storeLocation: nil,
            imageFilename: "test1.jpg"
        )

        // Then - IDs should be different even with same data
        #expect(record1.id != record2.id)
    }

    @Test("Hashable 一致性 / Hashable conformance")
    func testHashable() async throws {
        // Given
        let record1 = ScanRecord(
            username: "user",
            merchant: "Target",
            barcode: "123",
            location: nil,
            storeLocation: nil,
            imageFilename: "test.jpg"
        )

        let record2 = record1 // Same instance

        // Then
        #expect(record1.hashValue == record2.hashValue)

        // When - Create set with records
        let recordSet: Set = [record1, record2]

        // Then - Set should contain only 1 unique record
        #expect(recordSet.count == 1)
    }
}
