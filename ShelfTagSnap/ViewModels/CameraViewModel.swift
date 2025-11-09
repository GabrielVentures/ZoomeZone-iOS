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
import Vision

/// Camera view model managing scan flow
@MainActor
class CameraViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Scan state
    @Published var scanState: ScanState = .idle

    /// Currently detected barcode
    @Published var detectedBarcode: String?

    /// Detected barcode symbology (format type)
    @Published var detectedSymbology: VNBarcodeSymbology?

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

    /// Session scan counter (resets when camera closes)
    @Published var sessionScanCount: Int = 0

    /// Last detected barcode bounding box (for auto-crop)
    private var detectedBarcodeBoundingBox: CGRect?

    // MARK: - Dependencies

    private let cameraManager: CameraManager
    private let barcodeDetector: BarcodeDetector
    private let permissionManager: PermissionManager
    private let storageService: LocalStorageService  // Keep for backward compatibility
    private let recordStorageService: RecordStorageService  // New SwiftData service
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

    /// ✅ FIX: Track recently saved barcode to prevent immediate re-detection
    /// After saving a barcode, ignore it for a short period to prevent duplicate alerts
    private var recentlySavedBarcode: (code: String, time: Date)?
    private let recentlySavedIgnoreInterval: TimeInterval = 3.0

    /// ✅ BEST PRACTICE: Task reference for save operation (supports cancellation)
    /// Using Task reference instead of Bool flag follows Swift Concurrency best practices
    private var activeSaveTask: Task<Void, Never>?

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
        recordStorageService: RecordStorageService = .shared,
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
        self.recordStorageService = recordStorageService
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
        // ✅ EDGE CASE 3: Block new detections if save is in progress
        // Using scanState as single source of truth instead of separate flag
        guard scanState != .saving else {
            print("⚠️ [CameraVM] Save in progress (state: \(scanState)), ignoring new detection")
            return
        }

        // ✅ FIX ISSUE 2: Ignore recently saved barcode to prevent immediate re-detection
        if let recent = recentlySavedBarcode,
           recent.code == result.barcodeValue,
           Date().timeIntervalSince(recent.time) < recentlySavedIgnoreInterval {
            print("⚠️ [CameraVM] Ignoring recently saved barcode: \(result.barcodeValue)")
            return
        }

        // Update distance level
        currentDistanceLevel = result.distanceLevel

        // Check for duplicate scan (prevent repeated triggers in short time)
        if isDuplicateScan(barcode: result.barcodeValue) {
            return
        }

        // Check distance - relaxed for real-world shelf tags
        switch result.distanceLevel {
        case .tooFar:
            // Show hint but still allow detection for small shelf tags
            statusMessage = result.distanceLevel.description
            // Don't return - proceed with detection

        case .tooClose:
            // Only block if too close (blurry)
            statusMessage = result.distanceLevel.description
            return

        case .optimal:
            // Distance is optimal
            statusMessage = nil
        }

        // ✅ FIX ISSUE 1: Clear allowDuplicateOverride when detecting a different barcode
        if allowDuplicateOverride && result.barcodeValue != lastDetectedBarcodeData?.barcode {
            print("✅ [CameraVM] Detecting new barcode, clearing allowDuplicateOverride")
            allowDuplicateOverride = false
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
        detectedSymbology = result.symbology
        detectedBarcodeBoundingBox = result.boundingBox  // Save bounding box for auto-crop
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
        return recordStorageService.getRecord(byBarcode: barcode)
    }

    /// Allow duplicate scan (user chose "Scan Again")
    /// ✅ BEST PRACTICE: Using state machine + Task reference pattern
    /// This prevents race conditions from rapid clicks while supporting cancellation
    func allowDuplicateScan() {
        // ✅ EDGE CASE 2: Prevent duplicate saves if already saving (check state machine)
        guard scanState != .saving else {
            print("⚠️ [CameraVM] Already saving (state: \(scanState)), ignoring duplicate click")
            return
        }

        // ✅ EDGE CASE 2: Cancel any previous save task if it exists
        // This handles the case where user clicks rapidly before Task starts
        if let existingTask = activeSaveTask {
            print("⚠️ [CameraVM] Cancelling previous save task")
            existingTask.cancel()
        }

        showDuplicateAlert = false
        duplicateInfo = nil

        // ✅ Set override flag to prevent duplicate detection after this save
        allowDuplicateOverride = true

        // ✅ BEST PRACTICE: Store Task reference for cancellation support
        activeSaveTask = Task { @MainActor in
            await saveScanRecordAutomatically()

            // ✅ EDGE CASE 4: Only reset if task wasn't cancelled
            guard !Task.isCancelled else {
                print("⚠️ [CameraVM] Save task was cancelled, skipping reset")
                return
            }

            // Clean up: reset flags and task reference
            allowDuplicateOverride = false
            activeSaveTask = nil
            print("✅ [CameraVM] Duplicate save completed, flags reset")
        }
    }

    /// Cancel duplicate scan (user chose "Cancel")
    func cancelDuplicateScan() {
        // ✅ EDGE CASE 5: Cancel any pending save task when user cancels
        if let task = activeSaveTask {
            print("⚠️ [CameraVM] User cancelled, cancelling save task")
            task.cancel()
            activeSaveTask = nil
        }

        showDuplicateAlert = false
        duplicateInfo = nil
        allowDuplicateOverride = false  // ✅ EDGE CASE 5: Reset override flag

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

            // Auto-crop photo around barcode (if bounding box available)
            let processedPhoto: UIImage
            if let boundingBox = detectedBarcodeBoundingBox {
                print("📸 [CAMERA_VM] Auto-cropping photo around barcode...")
                processedPhoto = ImageCropper.cropAroundBarcode(
                    image: photo,
                    barcodeBoundingBox: boundingBox
                )
                print("✅ [CAMERA_VM] Photo cropped successfully")
            } else {
                print("⚠️ [CAMERA_VM] No bounding box available, using original photo")
                processedPhoto = photo
            }

            capturedPhoto = processedPhoto

            // Haptic feedback - photo captured
            HapticFeedbackManager.shared.success()

            // Auto-save immediately (no confirmation screen)
            await saveScanRecordAutomatically()

        } catch {
            // Haptic feedback - capture error
            HapticFeedbackManager.shared.error()

            errorMessage = "Photo capture failed: \(error.localizedDescription)"
            resetToScanning()
        }
    }

    /// Save scan record automatically without confirmation
    private func saveScanRecordAutomatically() async {
        // ✅ EDGE CASE 4: Check if task was cancelled before starting
        guard !Task.isCancelled else {
            print("⚠️ [CameraVM] Save task cancelled before start")
            return
        }

        guard let barcode = detectedBarcode,
              let photo = capturedPhoto,
              let user = firebaseManager.currentUser else {
            errorMessage = "Missing required information"
            resetToScanning()
            return
        }

        // Use preselected store name or default
        let storeName = preselectedStoreName ?? "Unknown Store"
        let defaultMerchant = Merchant.walmart  // Default merchant

        // ✅ EDGE CASE 10: Set state to .saving (blocks new detections)
        scanState = .saving
        statusMessage = "Saving..."

        do {
            // ✅ EDGE CASE 4: Check cancellation after state change
            guard !Task.isCancelled else {
                print("⚠️ [CameraVM] Save task cancelled during setup")
                resetToScanning()
                return
            }

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

            // ✅ EDGE CASE 4: Check cancellation before expensive save operation
            guard !Task.isCancelled else {
                print("⚠️ [CameraVM] Save task cancelled before save")
                resetToScanning()
                return
            }

            // Save using RecordStorageService (SwiftData)
            let savedRecord = try await recordStorageService.saveScanRecord(
                username: user.username,
                merchant: defaultMerchant.rawValue,
                barcode: barcode,
                location: location,
                storeLocation: storeName,
                image: photo
            )

            // ✅ EDGE CASE 4: Check cancellation after save
            guard !Task.isCancelled else {
                print("⚠️ [CameraVM] Save task cancelled after save")
                resetToScanning()
                return
            }

            // Save successful - show immediately (don't wait for cloud upload)
            scanState = .completed
            statusMessage = "✓ Saved successfully"

            // ⭐ Milestone 2: Trigger cloud upload in background (don't block UI)
            if CloudSyncService.shared.uploadMode != .manual {
                Task.detached {
                    await CloudSyncService.shared.addToQueue(savedRecord)
                }
            }

            // Increment session counter
            sessionScanCount += 1

            // Haptic feedback - save success
            HapticFeedbackManager.shared.success()

            // ✅ FIX ISSUE 2: Record saved barcode to prevent immediate re-detection
            recentlySavedBarcode = (barcode, Date())
            print("✅ [CameraVM] Recorded recently saved barcode: \(barcode)")

            // ✅ FIX ISSUE 2: Extend delay to 1.5 seconds to avoid immediate re-detection
            // This gives user time to move camera away from the barcode
            try? await Task.sleep(nanoseconds: 1_500_000_000)  // 1.5 seconds

            // ✅ EDGE CASE 4 & 8: Check if cancelled during sleep
            guard !Task.isCancelled else {
                print("⚠️ [CameraVM] Save task cancelled during delay")
                return
            }

            resetToScanning()

        } catch {
            // ✅ EDGE CASE 4: Even on error, check if cancelled
            guard !Task.isCancelled else {
                print("⚠️ [CameraVM] Save task cancelled during error handling")
                resetToScanning()
                return
            }

            // Haptic feedback - save error
            HapticFeedbackManager.shared.error()

            errorMessage = "Save failed: \(error.localizedDescription)"
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
    /// ✅ FIX P2-36: Run save operation in background to avoid blocking camera
    func saveScanRecord() async {
        guard let barcode = detectedBarcode,
              let photo = capturedPhoto,
              let merchant = selectedMerchant,
              let user = firebaseManager.currentUser else {
            errorMessage = "Missing required information"
            return
        }

        // Capture values needed for background task
        let storeLocationValue = storeLocation
        let merchantValue = merchant.rawValue
        let username = user.username

        // Update UI state on main actor
        await MainActor.run {
            scanState = .saving
            statusMessage = "Saving record..."
        }

        // ✅ FIX P2-36: Perform heavy I/O operations in background
        do {
            // Get GPS location (optional) - background operation
            var location: CLLocation?
            if permissionManager.locationAuthorized {
                do {
                    location = try await permissionManager.getCurrentLocation()
                } catch {
                    print("Failed to get location: \(error.localizedDescription)")
                    // Location failure doesn't prevent saving
                }
            }

            // Determine store name
            let storeName = storeLocationValue.isEmpty ? merchantValue : storeLocationValue

            // ✅ FIX P2-36: Save in background (RecordStorageService already uses @MainActor internally for SwiftData)
            let savedRecord = try await recordStorageService.saveScanRecord(
                username: username,
                merchant: merchantValue,
                barcode: barcode,
                location: location,
                storeLocation: storeLocationValue.isEmpty ? nil : storeName,
                image: photo
            )

            // ⭐ Milestone 2: Trigger cloud upload if auto-upload enabled (not manual mode)
            if CloudSyncService.shared.uploadMode != .manual {
                Task.detached { [savedRecord] in
                    await CloudSyncService.shared.addToQueue(savedRecord)
                }
            }

            // Update UI state on main actor
            await MainActor.run {
                scanState = .completed
                statusMessage = "Saved successfully"
                HapticFeedbackManager.shared.success()
            }

            // Reset after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.resetToScanning()
            }

        } catch {
            // Haptic feedback - save error
            await MainActor.run {
                HapticFeedbackManager.shared.error()
            }

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
        // ✅ EDGE CASE 7: Cancel any active save task when resetting
        if let task = activeSaveTask {
            print("⚠️ [CameraVM] Resetting camera, cancelling active save task")
            task.cancel()
            activeSaveTask = nil
        }

        detectedBarcode = nil
        detectedSymbology = nil
        detectedBarcodeBoundingBox = nil  // Clear bounding box
        capturedPhoto = nil
        selectedMerchant = nil
        storeLocation = ""
        showMerchantPicker = false
        showResultConfirmation = false
        showDuplicateAlert = false
        duplicateInfo = nil
        errorMessage = nil
        currentDistanceLevel = nil
        // ✅ FIX ISSUE 1: Don't clear allowDuplicateOverride here
        // It will be cleared when a new different barcode is detected (see handleBarcodeDetection)

        // Restart scanning
        startScanning()
    }

    /// Complete reset
    func reset() {
        // ✅ EDGE CASE 7: Cancel any active save task on complete reset
        if let task = activeSaveTask {
            print("⚠️ [CameraVM] Complete reset, cancelling active save task")
            task.cancel()
            activeSaveTask = nil
        }

        stopScanning()
        detectedBarcode = nil
        detectedSymbology = nil
        detectedBarcodeBoundingBox = nil  // Clear bounding box
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
        recentlySavedBarcode = nil  // ✅ Clear recently saved barcode tracking
        sessionScanCount = 0
        barcodeDetector.reset()
    }
}
