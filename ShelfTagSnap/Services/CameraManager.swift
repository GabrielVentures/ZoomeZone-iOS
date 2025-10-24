//
//  CameraManager.swift
//  ShelfTagSnap
//
//  Created by Claude on 2025/10/23.
//

import Foundation
import AVFoundation
import UIKit
import Combine

/// Camera manager for AVFoundation camera operations
@MainActor
class CameraManager: NSObject, ObservableObject {
    // MARK: - Published Properties

    /// Camera is running
    @Published var isRunning: Bool = false

    /// Current brightness level (0.0 - 1.0)
    @Published var brightnessLevel: Float = 0.5

    /// Is brightness too low
    @Published var isLowLight: Bool = false

    /// Error message
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let captureSession = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()

    private let sessionQueue = DispatchQueue(label: "com.shelftagsnap.camera.session")
    private var currentDevice: AVCaptureDevice?

    // Brightness detection
    private var brightnessCheckTimer: Timer?

    // Photo capture callback
    private var photoCaptureCompletion: ((Result<UIImage, Error>) -> Void)?

    // Barcode detection
    private nonisolated(unsafe) var barcodeDetector: BarcodeDetector?
    private nonisolated(unsafe) var shouldDetectBarcodes: Bool = false

    // MARK: - Camera Errors

    enum CameraError: LocalizedError {
        case setupFailed
        case deviceNotAvailable
        case inputCreationFailed
        case addInputFailed
        case addOutputFailed
        case capturePhotoFailed

        var errorDescription: String? {
            switch self {
            case .setupFailed:
                return "相机设置失败 / Camera setup failed"
            case .deviceNotAvailable:
                return "相机设备不可用 / Camera device not available"
            case .inputCreationFailed:
                return "创建相机输入失败 / Input creation failed"
            case .addInputFailed:
                return "添加相机输入失败 / Add input failed"
            case .addOutputFailed:
                return "添加输出失败 / Add output failed"
            case .capturePhotoFailed:
                return "拍照失败 / Capture photo failed"
            }
        }
    }

    // MARK: - Initialization

    init(barcodeDetector: BarcodeDetector? = nil) {
        self.barcodeDetector = barcodeDetector
        super.init()
    }

    // MARK: - Camera Setup

    /// Setup camera
    func setupCamera() async throws {
        #if targetEnvironment(simulator)
        print("⚠️ Running on Simulator - Camera may not work properly")
        #else
        print("📱 Running on Real Device")
        #endif

        print("🎯 [CAMERA_MANAGER] setupCamera() called")

        // Setup on background queue
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                guard let self = self else {
                    print("❌ Camera setup failed - self is nil")
                    continuation.resume(throwing: CameraError.setupFailed)
                    return
                }

                do {
                    print("📸 Starting camera setup...")

                    // Configure session
                    self.captureSession.beginConfiguration()
                    defer { self.captureSession.commitConfiguration() }

                    // Set session preset
                    if self.captureSession.canSetSessionPreset(.photo) {
                        self.captureSession.sessionPreset = .photo
                        print("✅ Camera session preset: .photo")
                    }

                    // Get back camera
                    guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                        print("❌ Back camera not available")
                        continuation.resume(throwing: CameraError.deviceNotAvailable)
                        return
                    }

                    print("✅ Got back camera device: \(videoDevice.localizedName)")
                    self.currentDevice = videoDevice

                    // Create input
                    let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
                    guard self.captureSession.canAddInput(videoDeviceInput) else {
                        print("❌ Cannot add video input to session")
                        continuation.resume(throwing: CameraError.addInputFailed)
                        return
                    }
                    self.captureSession.addInput(videoDeviceInput)
                    self.videoDeviceInput = videoDeviceInput
                    print("✅ Added video input to session")

                    // Add photo output
                    guard self.captureSession.canAddOutput(self.photoOutput) else {
                        print("❌ Cannot add photo output to session")
                        continuation.resume(throwing: CameraError.addOutputFailed)
                        return
                    }
                    self.captureSession.addOutput(self.photoOutput)
                    print("✅ Added photo output to session")

                    // Configure photo output
                    self.photoOutput.isHighResolutionCaptureEnabled = true
                    if let photoOutputConnection = self.photoOutput.connection(with: .video) {
                        photoOutputConnection.videoOrientation = .portrait
                        print("✅ Set photo output orientation to portrait")
                    }

                    // Add video data output (for real-time analysis)
                    self.videoDataOutput.setSampleBufferDelegate(self, queue: self.sessionQueue)
                    self.videoDataOutput.videoSettings = [
                        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                    ]

                    if self.captureSession.canAddOutput(self.videoDataOutput) {
                        self.captureSession.addOutput(self.videoDataOutput)
                        print("✅ Added video data output to session")
                    } else {
                        print("⚠️ Cannot add video data output (non-critical)")
                    }

                    // Configure device (autofocus, auto exposure)
                    try self.configureDevice(videoDevice)
                    print("✅ Configured camera device")

                    print("🎉 [CAMERA_MANAGER] Camera setup completed successfully!")
                    continuation.resume()

                } catch {
                    print("❌ Camera setup error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Configure camera device
    private func configureDevice(_ device: AVCaptureDevice) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        // Auto focus
        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }

        // Auto exposure
        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }

        // Auto white balance
        if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
            device.whiteBalanceMode = .continuousAutoWhiteBalance
        }

        // Low light boost
        if device.isLowLightBoostSupported {
            device.automaticallyEnablesLowLightBoostWhenAvailable = true
        }
    }

    // MARK: - Camera Control

    /// Start camera
    func startRunning() {
        print("📸 [CAMERA_MANAGER] Starting camera session...")
        sessionQueue.async { [weak self] in
            guard let self = self else {
                print("❌ [CAMERA_MANAGER] Cannot start camera - self is nil")
                return
            }

            print("🔍 [CAMERA_MANAGER] Checking session state...")
            print("🔍 [CAMERA_MANAGER] Session isRunning: \(self.captureSession.isRunning)")
            print("🔍 [CAMERA_MANAGER] Session inputs count: \(self.captureSession.inputs.count)")
            print("🔍 [CAMERA_MANAGER] Session outputs count: \(self.captureSession.outputs.count)")

            if !self.captureSession.isRunning {
                print("▶️ [CAMERA_MANAGER] Calling captureSession.startRunning()...")
                self.captureSession.startRunning()
                print("✅ [CAMERA_MANAGER] captureSession.startRunning() completed")
                print("✅ [CAMERA_MANAGER] Session isRunning: \(self.captureSession.isRunning)")

                Task { @MainActor in
                    self.isRunning = true
                    self.startBrightnessMonitoring()
                    print("✅ [CAMERA_MANAGER] UI state updated, brightness monitoring started")
                }
            } else {
                print("⚠️ [CAMERA_MANAGER] Camera session already running")
            }
        }
    }

    /// Enable barcode detection
    func enableBarcodeDetection() {
        shouldDetectBarcodes = true
        #if DEBUG
        print("✅ Barcode detection enabled")
        #endif
    }

    /// Disable barcode detection
    func disableBarcodeDetection() {
        shouldDetectBarcodes = false
        #if DEBUG
        print("⏸️ Barcode detection disabled")
        #endif
    }

    /// Stop camera
    func stopRunning() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            if self.captureSession.isRunning {
                self.captureSession.stopRunning()

                Task { @MainActor in
                    self.isRunning = false
                    self.stopBrightnessMonitoring()
                }
            }
        }
    }

    /// Get capture session (for preview view)
    func getCaptureSession() -> AVCaptureSession {
        return captureSession
    }

    // MARK: - Photo Capture

    /// Capture photo
    func capturePhoto() async throws -> UIImage {
        return try await withCheckedThrowingContinuation { continuation in
            // Save continuation
            photoCaptureCompletion = { result in
                continuation.resume(with: result)
            }

            // Create photo settings
            let photoSettings = AVCapturePhotoSettings()
            photoSettings.flashMode = .auto
            photoSettings.isHighResolutionPhotoEnabled = true

            // Capture photo
            photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }

    // MARK: - Brightness Monitoring

    /// Start brightness monitoring
    private func startBrightnessMonitoring() {
        stopBrightnessMonitoring() // Stop existing one first

        brightnessCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateBrightnessLevel()
            }
        }
    }

    /// Stop brightness monitoring
    nonisolated private func stopBrightnessMonitoring() {
        MainActor.assumeIsolated {
            brightnessCheckTimer?.invalidate()
            brightnessCheckTimer = nil
        }
    }

    /// Update brightness level
    private func updateBrightnessLevel() {
        guard let device = currentDevice else {
            // Assume normal light when no device
            brightnessLevel = 0.5
            isLowLight = false
            return
        }

        // Get ISO and exposure duration
        let iso = device.iso
        let exposureDuration = device.exposureDuration.seconds

        // Debug log
        #if DEBUG
        // Only print every 5 seconds to avoid log spam
        if Int(Date().timeIntervalSince1970) % 5 == 0 {
            print("📸 Camera Brightness - ISO: \(iso), Exposure: \(exposureDuration)s")
        }
        #endif

        // Check if values are valid (avoid abnormal values from simulator or initialization)
        guard iso > 0 && exposureDuration > 0 else {
            // Assume normal light when values are invalid
            brightnessLevel = 0.6
            isLowLight = false
            return
        }

        // Estimate brightness (higher ISO, longer exposure = darker environment)
        let maxISO: Float = 1000.0
        let maxExposure: Float = 0.1

        let isoNormalized = min(iso / maxISO, 1.0)
        let exposureNormalized = min(Float(exposureDuration) / maxExposure, 1.0)

        // Invert: higher ISO/exposure means lower brightness
        brightnessLevel = 1.0 - max(isoNormalized, exposureNormalized)

        // Check if low light (lowered threshold to 0.2 for more tolerance)
        isLowLight = brightnessLevel < 0.2

        #if DEBUG
        if Int(Date().timeIntervalSince1970) % 5 == 0 {
            print("📸 Brightness Level: \(brightnessLevel), Low Light: \(isLowLight)")
        }
        #endif
    }

    // MARK: - Focus Control

    /// Set focus point
    func setFocus(at point: CGPoint) {
        guard let device = currentDevice else { return }

        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }

                // Set focus point
                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = point
                    device.focusMode = .autoFocus
                }

                // Set exposure point
                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .autoExpose
                }

            } catch {
                print("Focus error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Cleanup

    deinit {
        stopBrightnessMonitoring()
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        Task { @MainActor in
            if let error = error {
                photoCaptureCompletion?(.failure(error))
                photoCaptureCompletion = nil
                return
            }

            guard let imageData = photo.fileDataRepresentation(),
                  let image = UIImage(data: imageData) else {
                photoCaptureCompletion?(.failure(CameraError.capturePhotoFailed))
                photoCaptureCompletion = nil
                return
            }

            photoCaptureCompletion?(.success(image))
            photoCaptureCompletion = nil
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Real-time video analysis

        // Barcode detection
        guard shouldDetectBarcodes,
              let detector = barcodeDetector else {
            return
        }

        // Process barcode detection on background queue
        detector.detectBarcode(from: sampleBuffer)
    }
}
