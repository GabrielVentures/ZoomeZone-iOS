//
//  CloudScanRecord.swift
//  ShelfTagSnap
//
//  Created by Claude on 2025-11-03.
//  Milestone 2: Cloud Firestore Data Model
//

import Foundation
import Firebase
import FirebaseFirestore

/// Cloud scan record model (from Firestore)
/// Represents a scan record stored in Firestore with AI processing results
struct CloudScanRecord: Identifiable, Codable {
    // MARK: - Properties

    /// Document ID (same as Scan_ID)
    @DocumentID var id: String?

    /// Username who created the scan
    var username: String

    /// Timestamp when scan was created (device time)
    @ServerTimestamp var timestamp: Timestamp?

    /// Timestamp when record was uploaded to cloud
    @ServerTimestamp var uploadTimestamp: Timestamp?

    /// Firebase user ID
    var userId: String

    /// Merchant name (e.g., "Walmart", "Target")
    var merchant: String

    /// Barcode value (legacy field)
    var barcode: String

    /// Shelf tag barcode (short 4-8 digit ID for display)
    var barcodeShelfTag: String?

    /// Full UPC barcode (long 12-13 digit barcode)
    var barcodeFull: String?

    /// GPS latitude
    var latitude: Double?

    /// GPS longitude
    var longitude: Double?

    /// Store location description
    var storeLocation: String?

    /// Image filename (original)
    var imageFilename: String

    /// Image URL in Firebase Storage
    var imageUrl: String

    /// Whether AI processing completed
    var aiProcessed: Bool

    /// AI processing error message (if any)
    var aiError: String?

    /// AI recognition result (nested object)
    var aiResult: AIResult?

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case id
        case username = "Username"
        case timestamp = "Timestamp"
        case uploadTimestamp = "Upload_Timestamp"
        case userId = "User_ID"
        case merchant = "Merchant"
        case barcode = "Barcode"
        case barcodeShelfTag = "Barcode_ShelfTag"  // Short shelf tag barcode (4-8 digits)
        case barcodeFull = "Barcode_Full"          // Full UPC barcode (12-13 digits)
        case latitude = "Latitude"
        case longitude = "Longitude"
        case storeLocation = "Store_Location"
        case imageFilename = "Image_Filename"
        case imageUrl = "Image_URL"
        case aiProcessed = "ai_processed"
        case aiError = "ai_processing_error_message"  // Fixed: match Cloud Function field
        case aiResult = "AI_Result"
    }

    // MARK: - Computed Properties

    /// Device timestamp as Date
    var deviceDate: Date {
        return timestamp?.dateValue() ?? Date()
    }

    /// Upload timestamp as Date
    var uploadDate: Date? {
        return uploadTimestamp?.dateValue()
    }

    /// Whether has GPS location
    var hasLocation: Bool {
        return latitude != nil && longitude != nil
    }

    /// Display barcode (prefers shelf tag over full barcode)
    var displayBarcode: String {
        return barcodeShelfTag ?? barcode
    }

    /// Whether AI processing is pending
    var aiPending: Bool {
        return !aiProcessed && aiError == nil
    }

    /// Whether AI processing failed
    var aiFailed: Bool {
        return !aiProcessed && aiError != nil
    }

    /// AI processing status
    var aiStatus: AIProcessingStatus {
        if aiProcessed && aiResult != nil {
            return .completed
        } else if aiFailed {
            return .failed
        } else {
            return .pending
        }
    }
}

// MARK: - AI Result Model

/// AI recognition result from GPT-4o
struct AIResult: Codable {
    /// Product title
    var title: String?

    /// Product price (total price)
    var price: String?

    /// Unit price (e.g., "$0.044/oz")
    var unitPrice: String?

    /// Package quantity (calculated from price/unit_price)
    var count: Int?

    /// Product size/weight per unit
    var size: String?

    /// Measurement unit (e.g., "oz", "ct", "PK")
    var unit: String?

    /// Product category
    var category: String?

    /// Product brand
    var brand: String?

    /// Tag print date (YYYY-MM-DD)
    var labelDate: String?

    /// Expiration date (YYYY-MM-DD)
    var expirationDate: String?

    /// Promotion text (e.g., "Buy 2 Get 1 Free")
    var promotion: String?

    /// Product description
    var description: String?

    /// Recognition confidence (can be "high", "medium", "low" or numeric)
    var confidence: String?

    /// Numeric confidence value (0.0 - 1.0)
    var confidenceValue: Double {
        // If confidence is a string, convert to numeric
        guard let conf = confidence else { return 0.0 }

        // Try to parse as double first
        if let numericValue = Double(conf) {
            return numericValue
        }

        // Convert string confidence to numeric
        switch conf.lowercased() {
        case "high":
            return 0.9
        case "medium":
            return 0.7
        case "low":
            return 0.3
        default:
            return 0.0
        }
    }

    /// Processing timestamp
    @ServerTimestamp var processedAt: Timestamp?

    /// Additional metadata
    var metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case title = "product_name"
        case price = "price"
        case unitPrice = "unit_price"
        case count = "count"
        case size = "size"                    // Fixed: was "weight_or_count"
        case unit = "unit"
        case category = "category"
        case brand = "brand"
        case labelDate = "label_date"
        case expirationDate = "expiration_date"
        case promotion = "promotion"
        case description = "description"
        case confidence = "confidence"
        case processedAt = "processed_at"
        case metadata = "metadata"
    }

    // MARK: - Computed Properties

    /// Processed date
    var processedDate: Date? {
        return processedAt?.dateValue()
    }

    /// Whether has valid title
    var hasTitle: Bool {
        return !(title?.isEmpty ?? true)
    }

    /// Whether has valid price
    var hasPrice: Bool {
        return !(price?.isEmpty ?? true)
    }

    /// Confidence percentage
    var confidencePercent: Int {
        return Int(confidenceValue * 100)
    }

    /// Confidence level
    var confidenceLevel: ConfidenceLevel {
        let percent = confidencePercent
        if percent >= 80 {
            return .high
        } else if percent >= 50 {
            return .medium
        } else {
            return .low
        }
    }
}

// MARK: - AI Processing Status

enum AIProcessingStatus {
    case pending
    case completed
    case failed

    var icon: String {
        switch self {
        case .pending:
            return "clock"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .pending:
            return "orange"
        case .completed:
            return "green"
        case .failed:
            return "red"
        }
    }

    var description: String {
        switch self {
        case .pending:
            return "AI processing..."
        case .completed:
            return "AI completed"
        case .failed:
            return "AI failed"
        }
    }
}

// MARK: - Confidence Level

enum ConfidenceLevel {
    case high    // >= 80%
    case medium  // 50-79%
    case low     // < 50%

    var color: String {
        switch self {
        case .high:
            return "green"
        case .medium:
            return "orange"
        case .low:
            return "red"
        }
    }

    var description: String {
        switch self {
        case .high:
            return "High confidence"
        case .medium:
            return "Medium confidence"
        case .low:
            return "Low confidence"
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension CloudScanRecord {
    /// Sample cloud record for preview
    static var sample: CloudScanRecord {
        CloudScanRecord(
            id: "sample-123",
            username: "testuser",
            timestamp: Timestamp(date: Date()),
            uploadTimestamp: Timestamp(date: Date()),
            userId: "user-456",
            merchant: "Walmart",
            barcode: "012345678912",
            latitude: 37.7749,
            longitude: -122.4194,
            storeLocation: "San Francisco Store",
            imageFilename: "sample.jpg",
            imageUrl: "https://example.com/sample.jpg",
            aiProcessed: true,
            aiError: nil,
            aiResult: AIResult(
                title: "Organic Bananas",
                price: "$2.99",
                size: "3 lbs", category: "Fresh Produce",
                brand: "Great Value",
                description: "Fresh organic bananas from Ecuador",
                confidence: "0.92",
                processedAt: Timestamp(date: Date()),
                metadata: ["source": "gpt-4o"]
            )
        )
    }

    /// Sample cloud record with pending AI
    static var samplePending: CloudScanRecord {
        CloudScanRecord(
            id: "sample-pending",
            username: "testuser",
            timestamp: Timestamp(date: Date()),
            uploadTimestamp: Timestamp(date: Date()),
            userId: "user-456",
            merchant: "Target",
            barcode: "987654321098",
            latitude: nil,
            longitude: nil,
            storeLocation: nil,
            imageFilename: "pending.jpg",
            imageUrl: "https://example.com/pending.jpg",
            aiProcessed: false,
            aiError: nil,
            aiResult: nil
        )
    }

    /// Sample cloud record with AI failure
    static var sampleFailed: CloudScanRecord {
        CloudScanRecord(
            id: "sample-failed",
            username: "testuser",
            timestamp: Timestamp(date: Date()),
            uploadTimestamp: Timestamp(date: Date()),
            userId: "user-456",
            merchant: "Costco",
            barcode: "555666777888",
            latitude: nil,
            longitude: nil,
            storeLocation: nil,
            imageFilename: "failed.jpg",
            imageUrl: "https://example.com/failed.jpg",
            aiProcessed: false,
            aiError: "Image too blurry",
            aiResult: nil
        )
    }
}

extension AIResult {
    /// Sample AI result
    static var sample: AIResult {
        AIResult(
            title: "Organic Milk",
            price: "$4.99",
            size: "1 Gallon", category: "Dairy",
            brand: "Horizon Organic",
            description: "Organic whole milk",
            confidence: "0.88",
            processedAt: Timestamp(date: Date()),
            metadata: ["model": "gpt-4o", "version": "2024-11"]
        )
    }
}
#endif
