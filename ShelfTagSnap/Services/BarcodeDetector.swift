//
//  BarcodeDetector.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//

import Foundation
import Vision
import AVFoundation
import CoreImage

/// Barcode detection result
struct BarcodeDetectionResult {

    /// Barcode data
    let barcodeValue: String

    /// Barcode symbology
    let symbology: VNBarcodeSymbology

    /// Bounding box (normalized coordinates)
    let boundingBox: CGRect

    /// Confidence
    let confidence: Float

    /// Estimated distance level
    let distanceLevel: DistanceLevel

    // MARK: - Distance Level

    enum DistanceLevel {
        case tooFar
        case optimal
        case tooClose

        var description: String {
            switch self {
            case .tooFar:
                return "Move closer to barcode"
            case .optimal:
                return "Distance optimal"
            case .tooClose:
                return "Move back a bit"
            }
        }
    }
}

/// Barcode detector using Vision framework
class BarcodeDetector {
    // MARK: - Properties

    /// Detection callback
    var onDetection: ((BarcodeDetectionResult) -> Void)?

    // MARK: - Private Properties

    private let detectionQueue = DispatchQueue(label: "com.shelftagsnap.barcode.detection")
    private var lastDetectionTime: Date?
    private var lastDetectedBarcode: String?

    private let debounceInterval: TimeInterval = 0.2  // Reduced from 0.5s for faster detection

    // MARK: - Detection

    /// Detect barcode from sample buffer
    /// - Parameter sampleBuffer: CMSampleBuffer from camera
    func detectBarcode(from sampleBuffer: CMSampleBuffer) {

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let request = VNDetectBarcodesRequest { [weak self] request, error in
            guard let self = self else { return }

            if let error = error {
                print("Barcode detection error: \(error.localizedDescription)")
                return
            }

            self.processDetectionResults(request.results)
        }

        // Supported barcode symbologies - Comprehensive support for all retail/industrial formats
        request.symbologies = [
            // EAN formats (International retail standard)
            // Note: EAN-13 also detects UPC-A (12-digit US barcodes are compatible with EAN-13)
            .ean13,             // EAN-13 (13 digits) - Also detects UPC-A (12 digits)
            .ean8,              // EAN-8 (8 digits) - Small item format

            // UPC formats (North America retail standard)
            .upce,              // UPC-E (8 digits) - Compressed UPC for small items

            // Code formats (Industrial/logistics)
            .code128,           // Code 128 - Logistics, shipping labels
            .code39,            // Code 39 - Industrial, government
            .code39Checksum,    // Code 39 with checksum
            .code39FullASCII,   // Code 39 Full ASCII
            .code93,            // Code 93 - Compact version of Code 39
            .code93i,           // Code 93i extension

            // Interleaved 2 of 5 formats
            .i2of5,             // Interleaved 2 of 5
            .i2of5Checksum,     // Interleaved 2 of 5 with checksum
            .itf14,             // ITF-14 (14 digits) - Carton/case codes

            // GS1 DataBar (Modern retail/pharmaceutical)
            .gs1DataBar,        // GS1 DataBar Omnidirectional
            .gs1DataBarExpanded,// GS1 DataBar Expanded
            .gs1DataBarLimited, // GS1 DataBar Limited

            // 2D barcodes
            .qr,                // QR Code
            .aztec,             // Aztec Code
            .pdf417,            // PDF417 - Government IDs, boarding passes
            .dataMatrix,        // Data Matrix - Small items, electronics
            .microQR,           // Micro QR Code
            .microPDF417        // Micro PDF417
        ]

        // Perform request
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        detectionQueue.async {
            do {
                try requestHandler.perform([request])
            } catch {
                print("Failed to perform barcode detection: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Result Processing

    /// Process detection results
    private func processDetectionResults(_ results: [Any]?) {
        guard let observations = results as? [VNBarcodeObservation],
              let observation = observations.first,
              let barcodeValue = observation.payloadStringValue else {
            return
        }

        // Debounce: skip if same barcode was recently detected
        if shouldSkipDetection(for: barcodeValue) {
            return
        }

        // Calculate distance level
        let distanceLevel = calculateDistanceLevel(from: observation.boundingBox)

        // Create result
        let result = BarcodeDetectionResult(
            barcodeValue: barcodeValue,
            symbology: observation.symbology,
            boundingBox: observation.boundingBox,
            confidence: observation.confidence,
            distanceLevel: distanceLevel
        )

        // Update detection record
        lastDetectionTime = Date()
        lastDetectedBarcode = barcodeValue

        // Callback
        DispatchQueue.main.async { [weak self] in
            self?.onDetection?(result)
        }
    }

    // MARK: - Distance Calculation

    /// Calculate distance level from bounding box size
    private func calculateDistanceLevel(from boundingBox: CGRect) -> BarcodeDetectionResult.DistanceLevel {
        // Use bounding box area as distance estimate
        let area = boundingBox.width * boundingBox.height

        // Adjusted thresholds for real-world shelf tags (much smaller barcodes)
        // Real shelf tag barcodes can be as small as 0.005-0.01 (0.5-1% of frame)
        let tooSmallThreshold: CGFloat = 0.005  // Lowered from 0.02 to support small shelf tags
        let tooLargeThreshold: CGFloat = 0.6    // Increased from 0.5 for more tolerance

        if area < tooSmallThreshold {
            return .tooFar
        } else if area > tooLargeThreshold {
            return .tooClose
        } else {
            return .optimal
        }
    }

    // MARK: - Debouncing

    /// Check if detection should be skipped (debouncing)
    private func shouldSkipDetection(for barcodeValue: String) -> Bool {

        // Don't skip if it's a different barcode
        if lastDetectedBarcode != barcodeValue {
            return false
        }

        // Don't skip if no previous detection time
        guard let lastTime = lastDetectionTime else {
            return false
        }

        // Skip if within debounce interval
        let timeSinceLastDetection = Date().timeIntervalSince(lastTime)
        return timeSinceLastDetection < debounceInterval
    }

    // MARK: - Reset

    /// Reset detector
    func reset() {
        lastDetectionTime = nil
        lastDetectedBarcode = nil
    }
}
