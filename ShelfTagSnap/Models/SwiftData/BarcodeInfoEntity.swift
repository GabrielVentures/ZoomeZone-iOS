//
//  BarcodeInfoEntity.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/27.
//

import Foundation
import SwiftData

/// SwiftData entity for barcode information
@Model
final class BarcodeInfoEntity {
    // MARK: - Properties

    /// Barcode number/code
    var code: String

    /// Barcode type (e.g., "UPC-A", "EAN-13", "QR Code")
    var type: String

    /// Scan quality score (0.0-1.0)
    var scanQuality: Double?

    /// Whether barcode is valid
    var isValid: Bool

    /// Recognized product name (if available)
    var recognizedProduct: String?

    /// Additional metadata (JSON string)
    var metadata: String?

    // MARK: - Initialization

    init(
        code: String,
        type: String = "Unknown",
        scanQuality: Double? = nil,
        isValid: Bool = true,
        recognizedProduct: String? = nil,
        metadata: String? = nil
    ) {
        self.code = code
        self.type = type
        self.scanQuality = scanQuality
        self.isValid = isValid
        self.recognizedProduct = recognizedProduct
        self.metadata = metadata
    }

    // MARK: - Computed Properties

    /// Check if barcode type is standard retail format
    var isRetailBarcode: Bool {
        return ["UPC-A", "UPC-E", "EAN-13", "EAN-8"].contains(type)
    }

    /// Formatted barcode string with type
    var displayString: String {
        return "\(type): \(code)"
    }
}
