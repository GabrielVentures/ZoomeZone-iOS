//
//  HapticFeedbackManager.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/24.

//

import UIKit

/// Centralized haptic feedback manager for consistent user experience
final class HapticFeedbackManager {

    // MARK: - Singleton

    static let shared = HapticFeedbackManager()

    // MARK: - Private Generators

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()

    // MARK: - Initialization

    private init() {
        // Pre-prepare generators for better responsiveness
        prepareGenerators()
    }

    // MARK: - Public Methods

    /// Pre-prepare all generators (should be called on app launch)
    func prepareGenerators() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        selectionGenerator.prepare()
        notificationGenerator.prepare()
    }

    // MARK: - Impact Feedback

    /// Light impact - for small UI interactions
    func light() {
        impactLight.impactOccurred()
        impactLight.prepare() // Re-prepare for next use
    }

    /// Medium impact - for significant actions
    func medium() {
        impactMedium.impactOccurred()
        impactMedium.prepare()
    }

    /// Heavy impact - for critical events
    func heavy() {
        impactHeavy.impactOccurred()
        impactHeavy.prepare()
    }

    // MARK: - Selection Feedback

    /// Selection feedback - for pickers, toggles, etc.
    func selection() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    // MARK: - Notification Feedback

    /// Success notification feedback
    func success() {
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }

    /// Warning notification feedback
    func warning() {
        notificationGenerator.notificationOccurred(.warning)
        notificationGenerator.prepare()
    }

    /// Error notification feedback
    func error() {
        notificationGenerator.notificationOccurred(.error)
        notificationGenerator.prepare()
    }

    // MARK: - Barcode Scanning Specific Feedback

    /// Barcode scan success feedback
    func barcodeScanned() {
        // Use success notification with medium impact for satisfying feedback
        notificationGenerator.notificationOccurred(.success)

        // Add a slight delay and then a light impact for "capture" feeling
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.impactLight.impactOccurred()
            self?.prepareGenerators()
        }
    }

    /// Barcode scan failed/invalid feedback
    func barcodeScanFailed() {
        error()
    }

    /// Duplicate barcode detected feedback
    func duplicateBarcodeDetected() {
        warning()
    }
}

// MARK: - Haptic Feedback Protocol

/// Haptic feedback protocol - for dependency injection and testing
protocol HapticFeedbackProviding {
    func light()
    func medium()
    func heavy()
    func selection()
    func success()
    func warning()
    func error()
    func barcodeScanned()
    func barcodeScanFailed()
    func duplicateBarcodeDetected()
}

// MARK: - HapticFeedbackManager + Protocol Conformance

extension HapticFeedbackManager: HapticFeedbackProviding {}

// MARK: - Mock for Testing

/// Mock haptic feedback manager - for unit testing
final class MockHapticFeedbackManager: HapticFeedbackProviding {
    var lightCallCount = 0
    var mediumCallCount = 0
    var heavyCallCount = 0
    var selectionCallCount = 0
    var successCallCount = 0
    var warningCallCount = 0
    var errorCallCount = 0
    var barcodeScannedCallCount = 0
    var barcodeScanFailedCallCount = 0
    var duplicateBarcodeDetectedCallCount = 0

    func light() { lightCallCount += 1 }
    func medium() { mediumCallCount += 1 }
    func heavy() { heavyCallCount += 1 }
    func selection() { selectionCallCount += 1 }
    func success() { successCallCount += 1 }
    func warning() { warningCallCount += 1 }
    func error() { errorCallCount += 1 }
    func barcodeScanned() { barcodeScannedCallCount += 1 }
    func barcodeScanFailed() { barcodeScanFailedCallCount += 1 }
    func duplicateBarcodeDetected() { duplicateBarcodeDetectedCallCount += 1 }

    func reset() {
        lightCallCount = 0
        mediumCallCount = 0
        heavyCallCount = 0
        selectionCallCount = 0
        successCallCount = 0
        warningCallCount = 0
        errorCallCount = 0
        barcodeScannedCallCount = 0
        barcodeScanFailedCallCount = 0
        duplicateBarcodeDetectedCallCount = 0
    }
}
