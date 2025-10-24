//
//  CameraViewModel.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//

import Foundation
import SwiftUI
import AVFoundation
import CoreLocation
import Combine

/// Camera view model managing scan flow
@MainActor
class CameraViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Scan state
    @Published var scanState: ScanState = .idle

    /// Currently detected barcode
    @Published var detectedBarcode: String?

    /// Currently captured photo
    @Published var capturedPhoto: UIImage?

    /// Selected merchant
    @Published var selectedMerchant: Merchant?

    /// Store location description (optional)
    @Published var storeLocation: String = ""

    /// Preselected store name (used when entering from Store page)
    private let preselectedStoreName: String?

    /// Status message
    @Published var statusMessage: String?

    /// Show merchant picker
    @Published var showMerchantPicker: Bool = false

    /// Show result confirmation
    @Published var showResultConfirmation: Bool = false

    /// Show duplicate barcode alert
    @Published var showDuplicateAlert: Bool = false

    /// Duplicate barcode information
    @Published var duplicateInfo: DuplicateInfo?

    /// Error message
    @Published var errorMessage: String?

    /// Current distance level
    @Published var currentDistanceLevel: BarcodeDetectionResult.DistanceLevel?

    // MARK: - Dependencies

    private let cameraManager: CameraManager
    private let barcodeDetector: BarcodeDetector
    private let permissionManager: PermissionManager
    private let storageService: LocalStorageService
    private let firebaseManager: FirebaseManager

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    /// Initialization state flag (prevent duplicate initialization)
    private var isInitialized: Bool = false

    /// Last detected barcode and timestamp (for duplicate prevention)
    private var lastDetectedBarcodeData: (barcode: String, time: Date)?

    /// Duplicate scan prevention interval (seconds)
    private let duplicatePreventionInterval: TimeInterval = 3.0

    /// Allow duplicate scan flag (temporarily allowed after user confirmation)
    private var allowDuplicateOverride: Bool = false

    // MARK: - Scan State

    enum ScanState: Equatable {
        case idle
        case scanning
        case detected(String)
        case capturing
        case confirming
        case saving
        case completed

        var description: String {
            switch self {
            case .idle:
                return "Ready to scan"
            case .scanning:
                return "Scanning..."
            case .detected(let barcode):
                return "Detected: \(barcode)"
            case .capturing:
                return "Capturing photo..."
            case .confirming:
                return "Please confirm"
            case .saving:
                return "Saving..."
            case .completed:
                return "Saved successfully"
            }
        }
    }

    // MARK: - Duplicate Info

    /// Duplicate barcode information
    struct DuplicateInfo {
        let barcode: String
        let merchant: String
        let storeLocation: String?
        let timestamp: Date
    }

    // MARK: - Initialization

    init(
        cameraManager: CameraManager? = nil,
        barcodeDetector: BarcodeDetector? = nil,
        permissionManager: PermissionManager = .shared,
        storageService: LocalStorageService = .shared,
        firebaseManager: FirebaseManager = .shared,
        preselectedStoreName: String? = nil
    ) {
        // Create or use provided barcodeDetector first
        let detector = barcodeDetector ?? BarcodeDetector()
        self.barcodeDetector = detector

        // Pass detector to cameraManager (if cameraManager not provided)
        self.cameraManager = cameraManager ?? CameraManager(barcodeDetector: detector)

        self.permissionManager = permissionManager
        self.storageService = storageService
        self.firebaseManager = firebaseManager
        self.preselectedStoreName = preselectedStoreName

        setupBarcodeDetection()
        setupCameraMonitoring()
    }

    // MARK: - Setup

    /// Setup barcode detection
    private func setupBarcodeDetection() {
        barcodeDetector.onDetection = { [weak self] result in
            Task { @MainActor in
                self?.handleBarcodeDetection(result)
            }
        }
    }

    /// Setup camera monitoring
    private func setupCameraMonitoring() {
        // Monitor brightness level
        cameraManager.$isLowLight
            .sink { [weak self] isLowLight in
                Task { @MainActor in
                    if isLowLight {
                        self?.statusMessage = Strings.Camera.lowLight
                    } else if self?.scanState == .scanning {
                        self?.statusMessage = Strings.Camera.alignBarcode
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Camera Control

    /// Initialize camera
    /// ⚠️ Run off MainActor to prevent blocking UI
    nonisolated func initializeCamera() async {
        // Prevent duplicate initialization
        let alreadyInitialized = await isInitialized
        guard !alreadyInitialized else {
            print("⚠️ [CAMERA_VM] Camera already initialized, skipping")
            return
        }

        do {
            print("🎬 [CAMERA_VM] Starting camera initialization (OFF MainActor)...")
            try await cameraManager.setupCamera()

            // Update state on MainActor
            await MainActor.run {
                print("✅ [CAMERA_VM] Updating isInitialized flag on MainActor")
                isInitialized = true
                print("✅ [CAMERA_VM] Camera initialization completed")
            }
        } catch {
            print("❌ [CAMERA_VM] Camera initialization failed: \(error.localizedDescription)")

            // Update error message on MainActor
            await MainActor.run {
                errorMessage = "Camera initialization failed: \(error.localizedDescription)"
            }
        }
    }

    /// Start scanning
    func startScanning() {
        guard permissionManager.cameraAuthorized else {
            errorMessage = "Camera permission required"
            return
        }

        cameraManager.enableBarcodeDetection()
        cameraManager.startRunning()
        scanState = .scanning
        statusMessage = Strings.Camera.alignBarcode
    }

    /// Stop scanning
    func stopScanning() {
        cameraManager.disableBarcodeDetection()
        cameraManager.stopRunning()
        scanState = .idle
        statusMessage = nil
    }

    /// Get capture session (for preview view)
    func getCaptureSession() -> AVCaptureSession {
        return cameraManager.getCaptureSession()
    }

    /// Get current brightness level
    var isLowLight: Bool {
        return cameraManager.isLowLight
    }

    // MARK: - Barcode Detection

    /// Handle barcode detection result
    private func handleBarcodeDetection(_ result: BarcodeDetectionResult) {
        // Update distance level
        currentDistanceLevel = result.distanceLevel

        // Check for duplicate scan (prevent repeated triggers in short time)
        if isDuplicateScan(barcode: result.barcodeValue) {
            return
        }

        // Check distance
        switch result.distanceLevel {
        case .tooFar:
            statusMessage = result.distanceLevel.description
            return

        case .tooClose:
            statusMessage = result.distanceLevel.description
            return

        case .optimal:
            // Distance is optimal, proceed
            break
        }

        // Check if barcode already exists in database (unless user allowed duplicate)
        if !allowDuplicateOverride, let existingRecord = checkDuplicateInDatabase(result.barcodeValue) {
            // Found duplicate record, pause detection and show alert
            cameraManager.disableBarcodeDetection()

            // Haptic feedback - error
            HapticFeedbackManager.shared.error()

            // Set duplicate info
            duplicateInfo = DuplicateInfo(
                barcode: existingRecord.barcode,
                merchant: existingRecord.merchant,
                storeLocation: existingRecord.storeLocation,
                timestamp: existingRecord.timestamp
            )
            showDuplicateAlert = true

            // Record detection time (prevent duplicate alerts)
            lastDetectedBarcodeData = (result.barcodeValue, Date())

            return
        }

        // Update state
        detectedBarcode = result.barcodeValue
        scanState = .detected(result.barcodeValue)
        statusMessage = "Barcode detected"

        // Haptic feedback - barcode scanned successfully
        HapticFeedbackManager.shared.barcodeScanned()

        // Record detection time (for duplicate prevention)
        lastDetectedBarcodeData = (result.barcodeValue, Date())

        // Auto capture photo
        Task {
            await capturePhotoAndProceed()
        }
    }

    /// Check if duplicate scan (repeated trigger in short time)
    private func isDuplicateScan(barcode: String) -> Bool {
        guard let lastData = lastDetectedBarcodeData else {
            return false
        }

        // Check if same barcode
        guard lastData.barcode == barcode else {
            return false
        }

        // Check time interval
        let timeSinceLastScan = Date().timeIntervalSince(lastData.time)
        return timeSinceLastScan < duplicatePreventionInterval
    }

    /// Check if barcode already exists in database
    private func checkDuplicateInDatabase(_ barcode: String) -> ScanRecord? {
        return storageService.getRecord(byBarcode: barcode)
    }

    /// Allow duplicate scan (user chose "Scan Again")
    func allowDuplicateScan() {
        showDuplicateAlert = false
        duplicateInfo = nil
        allowDuplicateOverride = true

        // Resume barcode detection, wait for user to scan again
        cameraManager.enableBarcodeDetection()
    }

    /// Cancel duplicate scan (user chose "Cancel")
    func cancelDuplicateScan() {
        showDuplicateAlert = false
        duplicateInfo = nil

        // Resume barcode detection
        cameraManager.enableBarcodeDetection()
    }

    // MARK: - Photo Capture

    /// Capture photo and proceed
    private func capturePhotoAndProceed() async {
        scanState = .capturing
        statusMessage = "Capturing photo..."

        do {
            let photo = try await cameraManager.capturePhoto()
            capturedPhoto = photo

            // Haptic feedback - photo captured
            HapticFeedbackManager.shared.medium()

            // Stop scanning
            stopScanning()

            // Check if there's a preselected store
            if let storeName = preselectedStoreName {
                // Preselected store: skip merchant selection, use preselected store name directly
                storeLocation = storeName

                // Set a default merchant (required by current architecture)
                selectedMerchant = .walmart  // TODO: store merchant

                // Show result confirmation directly
                scanState = .confirming
                statusMessage = "Confirm scan result"
                showResultConfirmation = true
            } else {
                // No preselected store: show merchant picker
                scanState = .confirming
                statusMessage = "Please select merchant"
                showMerchantPicker = true
            }

        } catch {
            // Haptic feedback - capture error
            HapticFeedbackManager.shared.error()

            errorMessage = "Photo capture failed: \(error.localizedDescription)"
            resetToScanning()
        }
    }

    // MARK: - Merchant Selection

    /// Select merchant
    func selectMerchant(_ merchant: Merchant) {
        selectedMerchant = merchant
        showMerchantPicker = false

        // Show result confirmation
        showResultConfirmation = true
    }

    // MARK: - Save Record

    /// Save scan record
    func saveScanRecord() async {
        guard let barcode = detectedBarcode,
              let photo = capturedPhoto,
              let merchant = selectedMerchant,
              let user = firebaseManager.currentUser else {
            errorMessage = "Missing required information"
            return
        }

        scanState = .saving
        statusMessage = "Saving record..."

        do {
            // Get GPS location (optional)
            var location: CLLocation?
            if permissionManager.locationAuthorized {
                do {
                    location = try await permissionManager.getCurrentLocation()
                } catch {
                    print("Failed to get location: \(error.localizedDescription)")
                    // Location failure doesn't prevent saving
                }
            }

            // Generate photo filename: {username}_{timestamp}_{storeName}.jpg
            let timestamp = Date().timeIntervalSince1970

            // Clean store name for filename (replace special characters)
            let storeName = storeLocation.isEmpty ? merchant.rawValue : storeLocation
            let cleanStoreName = storeName
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: " ", with: "_")
                .replacingOccurrences(of: ":", with: "-")
                .replacingOccurrences(of: "\\", with: "_")

            let imageFilename = "\(user.username)_\(Int(timestamp))_\(cleanStoreName).jpg"

            // Save photo
            _ = try storageService.saveImage(photo, filename: imageFilename)

            // Create scan record
            let record = ScanRecord(
                username: user.username,
                merchant: merchant.rawValue,
                barcode: barcode,
                location: location,
                storeLocation: storeLocation.isEmpty ? nil : storeLocation,
                imageFilename: imageFilename
            )

            // Save locally
            var records = (try? storageService.loadRecords()) ?? []
            records.append(record)
            try storageService.saveRecords(records)

            // TODO: Phase 4 - Sync to Firebase

            // Complete
            scanState = .completed
            statusMessage = "Saved successfully"

            // Haptic feedback - save success
            HapticFeedbackManager.shared.success()

            // Reset after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.resetToScanning()
            }

        } catch {
            // Haptic feedback - save error
            HapticFeedbackManager.shared.error()

            errorMessage = "Save failed: \(error.localizedDescription)"
            resetToScanning()
        }
    }

    /// Cancel save
    func cancelSave() {
        showResultConfirmation = false
        resetToScanning()
    }

    // MARK: - Reset

    /// Reset to scanning state
    private func resetToScanning() {
        detectedBarcode = nil
        capturedPhoto = nil
        selectedMerchant = nil
        storeLocation = ""
        showMerchantPicker = false
        showResultConfirmation = false
        showDuplicateAlert = false
        duplicateInfo = nil
        errorMessage = nil
        currentDistanceLevel = nil
        allowDuplicateOverride = false

        // Restart scanning
        startScanning()
    }

    /// Complete reset
    func reset() {
        stopScanning()
        detectedBarcode = nil
        capturedPhoto = nil
        selectedMerchant = nil
        storeLocation = ""
        showMerchantPicker = false
        showResultConfirmation = false
        showDuplicateAlert = false
        duplicateInfo = nil
        statusMessage = nil
        errorMessage = nil
        currentDistanceLevel = nil
        lastDetectedBarcodeData = nil
        allowDuplicateOverride = false
        barcodeDetector.reset()
    }
}
