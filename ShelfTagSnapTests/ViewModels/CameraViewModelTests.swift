//
//  CameraViewModelTests.swift
//  ShelfTagSnapTests
//
//  Created by kent.sun on 2025/10/23.
//

import Testing
import Foundation
import AVFoundation
import CoreLocation
@testable import ShelfTagSnap

/// Unit tests for CameraViewModel
@Suite("CameraViewModel Tests")
struct CameraViewModelTests {

    // MARK: - Scan State Tests

    @Test("ScanState 描述文本 / ScanState descriptions")
    func testScanStateDescriptions() async throws {
        let idle = CameraViewModel.ScanState.idle
        let scanning = CameraViewModel.ScanState.scanning
        let detected = CameraViewModel.ScanState.detected("1234567890123")
        let capturing = CameraViewModel.ScanState.capturing
        let confirming = CameraViewModel.ScanState.confirming
        let saving = CameraViewModel.ScanState.saving
        let completed = CameraViewModel.ScanState.completed

        #expect(!idle.description.isEmpty)
        #expect(!scanning.description.isEmpty)
        #expect(!detected.description.isEmpty)
        #expect(!capturing.description.isEmpty)
        #expect(!confirming.description.isEmpty)
        #expect(!saving.description.isEmpty)
        #expect(!completed.description.isEmpty)

        #expect(idle.description.contains("准备") || idle.description.contains("Ready"))
        #expect(scanning.description.contains("扫描") || scanning.description.contains("Scanning"))
        #expect(detected.description.contains("1234567890123"))
        #expect(capturing.description.contains("拍照") || capturing.description.contains("Capturing"))
        #expect(confirming.description.contains("确认") || confirming.description.contains("confirm"))
        #expect(saving.description.contains("保存") || saving.description.contains("Saving"))
        #expect(completed.description.contains("成功") || completed.description.contains("success"))
    }

    // MARK: - Initialization Tests

    @Test("ViewModel 初始化状态 / ViewModel initial state")
    @MainActor
    func testInitialState() async throws {
        let viewModel = CameraViewModel()

        #expect(viewModel.scanState == .idle)
        #expect(viewModel.detectedBarcode == nil)
        #expect(viewModel.capturedPhoto == nil)
        #expect(viewModel.selectedMerchant == nil)
        #expect(viewModel.storeLocation == "")
        #expect(viewModel.showMerchantPicker == false)
        #expect(viewModel.showResultConfirmation == false)
    }

    // MARK: - Merchant Selection Tests

    @Test("选择商家流程 / Merchant selection")
    @MainActor
    func testSelectMerchant() async throws {
        let viewModel = CameraViewModel()

        viewModel.showMerchantPicker = true

        viewModel.selectMerchant(.walmart)

        // Then
        #expect(viewModel.selectedMerchant == .walmart)
        #expect(viewModel.showMerchantPicker == false)
        #expect(viewModel.showResultConfirmation == true)
    }

    @Test("选择不同商家 / Select different merchants")
    @MainActor
    func testSelectDifferentMerchants() async throws {
        let viewModel = CameraViewModel()

        // Test each merchant
        for merchant in Merchant.allCases {
            viewModel.selectMerchant(merchant)
            #expect(viewModel.selectedMerchant == merchant)
        }
    }

    // MARK: - Cancel Tests

    @Test("取消保存流程 / Cancel save flow")
    @MainActor
    func testCancelSave() async throws {
        let viewModel = CameraViewModel()

        viewModel.detectedBarcode = "1234567890123"
        viewModel.selectedMerchant = .walmart
        viewModel.showResultConfirmation = true

        viewModel.cancelSave()

        #expect(viewModel.showResultConfirmation == false)
        #expect(viewModel.detectedBarcode == nil)
        #expect(viewModel.selectedMerchant == nil)
    }

    // MARK: - Reset Tests

    @Test("完全重置 / Complete reset")
    @MainActor
    func testReset() async throws {
        let viewModel = CameraViewModel()

        viewModel.detectedBarcode = "1234567890123"
        viewModel.selectedMerchant = .walmart
        viewModel.storeLocation = "Floor 1"
        viewModel.showMerchantPicker = true
        viewModel.showResultConfirmation = true
        viewModel.statusMessage = "Test message"
        viewModel.errorMessage = "Test error"

        viewModel.reset()

        #expect(viewModel.scanState == .idle)
        #expect(viewModel.detectedBarcode == nil)
        #expect(viewModel.capturedPhoto == nil)
        #expect(viewModel.selectedMerchant == nil)
        #expect(viewModel.storeLocation == "")
        #expect(viewModel.showMerchantPicker == false)
        #expect(viewModel.showResultConfirmation == false)
        #expect(viewModel.statusMessage == nil)
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Store Location Tests

    @Test("门店位置输入 / Store location input")
    @MainActor
    func testStoreLocationInput() async throws {
        let viewModel = CameraViewModel()

        viewModel.storeLocation = "一楼入口处"

        // Then
        #expect(viewModel.storeLocation == "一楼入口处")

        viewModel.storeLocation = ""

        // Then
        #expect(viewModel.storeLocation == "")
    }

    @Test("门店位置 - 特殊字符 / Store location - special characters")
    @MainActor
    func testStoreLocationSpecialCharacters() async throws {
        let viewModel = CameraViewModel()

        let specialLocations = [
            "Floor 1, Section A",
            "货架 #123",
            "走廊-左侧",
            "Aisle 5 (near entrance)"
        ]

        for location in specialLocations {
            viewModel.storeLocation = location
            #expect(viewModel.storeLocation == location)
        }
    }

    // MARK: - Edge Cases

    @Test("门店位置 - 超长文本 / Store location - very long text")
    @MainActor
    func testStoreLocationVeryLongText() async throws {
        let viewModel = CameraViewModel()

        let longLocation = String(repeating: "这是一个很长的门店位置描述 ", count: 10)

        // When
        viewModel.storeLocation = longLocation

        #expect(viewModel.storeLocation == longLocation)
        #expect(viewModel.storeLocation.count > 200)
    }

    @Test("连续选择商家 / Multiple merchant selections")
    @MainActor
    func testMultipleMerchantSelections() async throws {
        let viewModel = CameraViewModel()

        // Given
        viewModel.showMerchantPicker = true

        viewModel.selectMerchant(.walmart)
        #expect(viewModel.selectedMerchant == .walmart)

        viewModel.showMerchantPicker = true
        viewModel.selectMerchant(.target)
        #expect(viewModel.selectedMerchant == .target)

        viewModel.showMerchantPicker = true
        viewModel.selectMerchant(.costco)
        #expect(viewModel.selectedMerchant == .costco)
    }

    @Test("重置后状态 / State after reset")
    @MainActor
    func testStateAfterReset() async throws {
        let viewModel = CameraViewModel()

        viewModel.detectedBarcode = "1234567890123"
        viewModel.selectedMerchant = .walmart
        viewModel.storeLocation = "Floor 1"

        viewModel.reset()

        viewModel.detectedBarcode = "9876543210987"
        viewModel.selectMerchant(.target)
        viewModel.storeLocation = "Floor 2"

        #expect(viewModel.detectedBarcode == "9876543210987")
        #expect(viewModel.selectedMerchant == .target)
        #expect(viewModel.storeLocation == "Floor 2")
    }

    // MARK: - State Consistency Tests

    @Test("商家选择器和结果确认互斥 / Merchant picker and result confirmation are mutually exclusive")
    @MainActor
    func testMerchantPickerAndResultConfirmationMutuallyExclusive() async throws {
        let viewModel = CameraViewModel()

        viewModel.showMerchantPicker = true
        viewModel.showResultConfirmation = false

        viewModel.selectMerchant(.walmart)

        #expect(viewModel.showMerchantPicker == false)
        #expect(viewModel.showResultConfirmation == true)

        viewModel.cancelSave()

        #expect(viewModel.showMerchantPicker == false)
        #expect(viewModel.showResultConfirmation == false)
    }

    @Test("取消后可以重新扫描 / Can rescan after cancel")
    @MainActor
    func testCanRescanAfterCancel() async throws {
        let viewModel = CameraViewModel()

        viewModel.detectedBarcode = "1111111111111"
        viewModel.selectMerchant(.walmart)
        viewModel.storeLocation = "Floor 1"
        viewModel.showResultConfirmation = true

        viewModel.cancelSave()

        #expect(viewModel.detectedBarcode == nil)
        #expect(viewModel.selectedMerchant == nil)
        #expect(viewModel.storeLocation == "")
        #expect(viewModel.showResultConfirmation == false)

        viewModel.detectedBarcode = "2222222222222"
        viewModel.selectMerchant(.target)

        #expect(viewModel.detectedBarcode == "2222222222222")
        #expect(viewModel.selectedMerchant == .target)
    }

    // MARK: - Barcode Format Tests

    @Test("支持不同条形码格式 / Support different barcode formats")
    @MainActor
    func testDifferentBarcodeFormats() async throws {
        let viewModel = CameraViewModel()

        let testBarcodes = [
            "1234567890123",     // EAN13
            "12345678",          // EAN8
            "123456",            // UPCE
            "CODE128TEST",       // Code128
            "CODE39",            // Code39
            "QRCODE123"         // QR
        ]

        for barcode in testBarcodes {
            viewModel.detectedBarcode = barcode
            #expect(viewModel.detectedBarcode == barcode)
            viewModel.reset()
        }
    }

    @Test("空条形码检测 / Empty barcode detection")
    @MainActor
    func testEmptyBarcode() async throws {
        let viewModel = CameraViewModel()

        viewModel.detectedBarcode = ""

        #expect(viewModel.detectedBarcode == "")
    }

    @Test("超长条形码 / Very long barcode")
    @MainActor
    func testVeryLongBarcode() async throws {
        let viewModel = CameraViewModel()

        let longBarcode = String(repeating: "1234567890", count: 10)

        // When
        viewModel.detectedBarcode = longBarcode

        // Then
        #expect(viewModel.detectedBarcode == longBarcode)
        #expect(viewModel.detectedBarcode!.count == 100)
    }

    // MARK: - Multiple Reset Tests

    @Test("多次重置 / Multiple resets")
    @MainActor
    func testMultipleResets() async throws {
        let viewModel = CameraViewModel()

        for _ in 0..<5 {
            // Set some state
            viewModel.detectedBarcode = "1234567890123"
            viewModel.selectMerchant(.walmart)
            viewModel.storeLocation = "Test"

            // Reset
            viewModel.reset()

            // Verify clean state
            #expect(viewModel.scanState == .idle)
            #expect(viewModel.detectedBarcode == nil)
            #expect(viewModel.selectedMerchant == nil)
            #expect(viewModel.storeLocation == "")
        }
    }

    // MARK: - Published Properties Observation Tests

    @Test("Published 属性更新 / Published properties update")
    @MainActor
    func testPublishedPropertiesUpdate() async throws {
        let viewModel = CameraViewModel()

        // Test scanState
        viewModel.scanState = .scanning
        #expect(viewModel.scanState == .scanning)

        viewModel.scanState = .detected("123")
        #expect(viewModel.scanState == .detected("123"))

        // Test statusMessage
        viewModel.statusMessage = "测试消息"
        #expect(viewModel.statusMessage == "测试消息")

        viewModel.statusMessage = nil
        #expect(viewModel.statusMessage == nil)

        // Test errorMessage
        viewModel.errorMessage = "错误消息"
        #expect(viewModel.errorMessage == "错误消息")

        viewModel.errorMessage = nil
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Scan State Equality Tests

    @Test("ScanState 相等性 / ScanState equality")
    func testScanStateEquality() async throws {
        let idle1 = CameraViewModel.ScanState.idle
        let idle2 = CameraViewModel.ScanState.idle
        #expect(idle1 == idle2)

        let scanning1 = CameraViewModel.ScanState.scanning
        let scanning2 = CameraViewModel.ScanState.scanning
        #expect(scanning1 == scanning2)

        let detected1 = CameraViewModel.ScanState.detected("123")
        let detected2 = CameraViewModel.ScanState.detected("123")
        let detected3 = CameraViewModel.ScanState.detected("456")

        // #expect(detected1 == detected2)
        // #expect(detected1 != detected3)
    }
}

// MARK: - Mock Helpers

/// Mock CameraManager for testing

@MainActor
class MockCameraManager: CameraManager {
    var setupCalled = false
    var startRunningCalled = false
    var stopRunningCalled = false
    var capturePhotoCalled = false

    var shouldThrowSetupError = false
    var shouldThrowCaptureError = false
    var mockPhoto: UIImage?

    override func setupCamera() async throws {
        setupCalled = true
        if shouldThrowSetupError {
            throw NSError(domain: "MockError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock setup error"])
        }
    }

    override func startRunning() {
        startRunningCalled = true
        super.startRunning()
    }

    override func stopRunning() {
        stopRunningCalled = true
        super.stopRunning()
    }

    override func capturePhoto() async throws -> UIImage {
        capturePhotoCalled = true
        if shouldThrowCaptureError {
            throw NSError(domain: "MockError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Mock capture error"])
        }
        return mockPhoto ?? UIImage()
    }
}

// MARK: - Integration Tests with Mocks

@Suite("CameraViewModel Integration Tests")
struct CameraViewModelIntegrationTests {

}
