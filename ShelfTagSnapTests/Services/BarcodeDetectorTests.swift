//
//  BarcodeDetectorTests.swift
//  ShelfTagSnapTests
//
//  Created by kent.sun on 2025/10/23.
//

import Testing
import Foundation
import CoreGraphics
import Vision
@testable import ShelfTagSnap

/// Unit tests for BarcodeDetector
@Suite("BarcodeDetector Tests")
struct BarcodeDetectorTests {

    // MARK: - Distance Calculation Tests

    @Test("距离检测 - 太远 / Distance detection - too far")
    func testDistanceCalculationTooFar() async throws {

        let smallBox = CGRect(x: 0.4, y: 0.4, width: 0.1, height: 0.1) // 1% area

        // When
        let detector = BarcodeDetector()
        let distanceLevel = detector.calculateDistanceLevel(from: smallBox)

        // Then
        #expect(distanceLevel == .tooFar)
        #expect(distanceLevel.description.contains("靠近") || distanceLevel.description.contains("closer"))
    }

    @Test("距离检测 - 太近 / Distance detection - too close")
    func testDistanceCalculationTooClose() async throws {

        let largeBox = CGRect(x: 0.1, y: 0.1, width: 0.7, height: 0.8) // 56% area

        // When
        let detector = BarcodeDetector()
        let distanceLevel = detector.calculateDistanceLevel(from: largeBox)

        // Then
        #expect(distanceLevel == .tooClose)
        #expect(distanceLevel.description.contains("后退") || distanceLevel.description.contains("back"))
    }

    @Test("距离检测 - 最佳距离 / Distance detection - optimal")
    func testDistanceCalculationOptimal() async throws {

        let mediumBox = CGRect(x: 0.3, y: 0.3, width: 0.3, height: 0.3) // 9% area

        // When
        let detector = BarcodeDetector()
        let distanceLevel = detector.calculateDistanceLevel(from: mediumBox)

        // Then
        #expect(distanceLevel == .optimal)
        #expect(distanceLevel.description.contains("合适") || distanceLevel.description.contains("optimal"))
    }

    @Test("距离检测 - 边界值 (2%) / Distance detection - boundary 2%")
    func testDistanceCalculationBoundary2Percent() async throws {

        let boundaryBox = CGRect(x: 0, y: 0, width: 0.141421, height: 0.141421) // ≈2% area

        // When
        let detector = BarcodeDetector()
        let distanceLevel = detector.calculateDistanceLevel(from: boundaryBox)

        #expect(distanceLevel == .optimal)
    }

    @Test("距离检测 - 边界值 (50%) / Distance detection - boundary 50%")
    func testDistanceCalculationBoundary50Percent() async throws {

        let boundaryBox = CGRect(x: 0, y: 0, width: 0.707107, height: 0.707107) // ≈50% area

        // When
        let detector = BarcodeDetector()
        let distanceLevel = detector.calculateDistanceLevel(from: boundaryBox)

        #expect(distanceLevel == .optimal)
    }

    // MARK: - Debouncing Tests

    @Test("防抖机制 - 不同条形码不跳过 / Debouncing - different barcode")
    func testDebounceDifferentBarcode() async throws {
        // Given
        let detector = BarcodeDetector()
        var detectionCount = 0

        detector.onDetection = { _ in
            detectionCount += 1
        }

    }

    @Test("防抖机制 - 相同条形码短时间内跳过 / Debouncing - same barcode skip")
    func testDebounceSameBarcodeShortInterval() async throws {
        // Given
        let detector = BarcodeDetector()

        // When & Then

    }

    // MARK: - Reset Tests

    @Test("重置检测器 / Reset detector")
    func testReset() async throws {
        // Given
        let detector = BarcodeDetector()

        // When
        detector.reset()

        // Then

    }

    // MARK: - BarcodeDetectionResult Tests

    @Test("BarcodeDetectionResult 初始化 / BarcodeDetectionResult initialization")
    func testBarcodeDetectionResultInit() async throws {
        // Given
        let barcode = "1234567890123"
        let symbology = VNBarcodeSymbology.EAN13
        let boundingBox = CGRect(x: 0.2, y: 0.3, width: 0.4, height: 0.3)
        let confidence: Float = 0.95
        let distanceLevel = BarcodeDetectionResult.DistanceLevel.optimal

        // When
        let result = BarcodeDetectionResult(
            barcodeValue: barcode,
            symbology: symbology,
            boundingBox: boundingBox,
            confidence: confidence,
            distanceLevel: distanceLevel
        )

        // Then
        #expect(result.barcodeValue == barcode)
        #expect(result.symbology == symbology)
        #expect(result.boundingBox == boundingBox)
        #expect(result.confidence == confidence)
        #expect(result.distanceLevel == distanceLevel)
    }

    @Test("DistanceLevel 描述 / DistanceLevel descriptions")
    func testDistanceLevelDescriptions() async throws {
        // Given & When & Then
        let tooFar = BarcodeDetectionResult.DistanceLevel.tooFar
        let optimal = BarcodeDetectionResult.DistanceLevel.optimal
        let tooClose = BarcodeDetectionResult.DistanceLevel.tooClose

        #expect(!tooFar.description.isEmpty)
        #expect(!optimal.description.isEmpty)
        #expect(!tooClose.description.isEmpty)

        #expect(tooFar.description.contains("靠近") || tooFar.description.contains("closer"))
        #expect(optimal.description.contains("合适") || optimal.description.contains("optimal"))
        #expect(tooClose.description.contains("后退") || tooClose.description.contains("back"))
    }

    // MARK: - Edge Cases

    @Test("边界框为零面积 / Bounding box zero area")
    func testZeroAreaBoundingBox() async throws {

        let zeroBox = CGRect(x: 0, y: 0, width: 0, height: 0)

        // When
        let detector = BarcodeDetector()
        let distanceLevel = detector.calculateDistanceLevel(from: zeroBox)

        #expect(distanceLevel == .tooFar)
    }

    @Test("边界框超出范围 / Bounding box out of bounds")
    func testOutOfBoundsBoundingBox() async throws {

        let outOfBoundsBox = CGRect(x: -0.1, y: -0.1, width: 1.2, height: 1.2)

        // When
        let detector = BarcodeDetector()
        let distanceLevel = detector.calculateDistanceLevel(from: outOfBoundsBox)

        #expect(distanceLevel == .tooClose)
    }

    @Test("边界框正方形 vs 长方形 / Square vs rectangle bounding box")
    func testSquareVsRectangleBoundingBox() async throws {
        // Given
        let detector = BarcodeDetector()

        let squareBox = CGRect(x: 0, y: 0, width: 0.3, height: 0.3)

        let rectangleBox = CGRect(x: 0, y: 0, width: 0.45, height: 0.2)

        // When
        let squareLevel = detector.calculateDistanceLevel(from: squareBox)
        let rectangleLevel = detector.calculateDistanceLevel(from: rectangleBox)

        #expect(squareLevel == rectangleLevel)
        #expect(squareLevel == .optimal)
    }

    @Test("超小边界框 / Extremely small bounding box")
    func testExtremelySmallBoundingBox() async throws {

        let tinyBox = CGRect(x: 0, y: 0, width: 0.01, height: 0.01) // 0.0001 area

        // When
        let detector = BarcodeDetector()
        let distanceLevel = detector.calculateDistanceLevel(from: tinyBox)

        // Then
        #expect(distanceLevel == .tooFar)
    }

    @Test("超大边界框 / Extremely large bounding box")
    func testExtremelyLargeBoundingBox() async throws {

        let hugeBox = CGRect(x: 0, y: 0, width: 1.0, height: 1.0)

        // When
        let detector = BarcodeDetector()
        let distanceLevel = detector.calculateDistanceLevel(from: hugeBox)

        // Then
        #expect(distanceLevel == .tooClose)
    }
}
