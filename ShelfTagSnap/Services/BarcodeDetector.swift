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
                return "请靠近条形码 / Move closer to barcode"
            case .optimal:
                return "距离合适 / Distance optimal"
            case .tooClose:
                return "请后退一些 / Move back a bit"
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

    private let debounceInterval: TimeInterval = 0.5

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

        // Supported barcode symbologies
        request.symbologies = [
            .EAN13,
            .EAN8,
            .UPCE,
            .Code128,
            .Code39,
            .Code93,
            .ITF14,
            .QR
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

        // Define thresholds (can be adjusted based on real-world testing)
        let tooSmallThreshold: CGFloat = 0.02
        let tooLargeThreshold: CGFloat = 0.5

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
