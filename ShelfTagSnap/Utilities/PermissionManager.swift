//
//  PermissionManager.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//

import Foundation
import AVFoundation
import CoreLocation
import SwiftUI
import Combine

/// Permission manager for camera and location
@MainActor
class PermissionManager: NSObject, ObservableObject {
    // MARK: - Singleton

    static let shared = PermissionManager()

    // MARK: - Published Properties

    /// Camera permission authorized
    @Published var cameraAuthorized = false

    /// Location permission authorized
    @Published var locationAuthorized = false

    /// Current location
    @Published var currentLocation: CLLocation?

    /// Location error message
    @Published var locationError: String?

    // MARK: - Private Properties

    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    // MARK: - Initialization

    private override init() {
        super.init()
        locationManager.delegate = self
        checkAllPermissions()
        setupNotifications()
    }

    // MARK: - Setup

    /// Setup notification observers
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    /// Recheck permissions when app enters foreground
    @objc private func appWillEnterForeground() {
        Task { @MainActor in
            checkAllPermissions()
        }
    }

    // MARK: - Public Methods

    /// Check all permission statuses
    func checkAllPermissions() {
        checkCameraPermission()
        checkLocationPermission()
    }

    /// Check camera permission
    func checkCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        cameraAuthorized = (status == .authorized)
    }

    /// Request camera permission

    func requestCameraPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            cameraAuthorized = true
            return true

        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraAuthorized = granted
            return granted

        case .denied, .restricted:
            cameraAuthorized = false
            return false

        @unknown default:
            cameraAuthorized = false
            return false
        }
    }

    /// Check location permission
    func checkLocationPermission() {
        let status = locationManager.authorizationStatus
        locationAuthorized = (status == .authorizedWhenInUse || status == .authorizedAlways)
    }

    /// Request location permission
    func requestLocationPermission() {
        let status = locationManager.authorizationStatus

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationAuthorized = true

        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()

        case .denied, .restricted:
            locationAuthorized = false

        @unknown default:
            locationAuthorized = false
        }
    }

    /// Open app settings
    func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Location Services

    /// Get current location
    /// - Returns: CLLocation
    /// - Throws: LocationError
    func getCurrentLocation() async throws -> CLLocation {

        guard locationAuthorized else {
            throw LocationError.unauthorized
        }

        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation

            locationManager.startUpdatingLocation()

            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
                guard let self = self else { return }

                if self.locationContinuation != nil {
                    self.locationManager.stopUpdatingLocation()
                    self.locationContinuation?.resume(throwing: LocationError.timeout)
                    self.locationContinuation = nil
                }
            }
        }
    }

    /// Stop location updates
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }

    // MARK: - Location Errors

    enum LocationError: LocalizedError {
        case unauthorized
        case timeout
        case failed(Error)

        var errorDescription: String? {
            switch self {
            case .unauthorized:
                return "位置权限未授权 / Location permission not authorized"
            case .timeout:
                return "获取位置超时 / Location request timeout"
            case .failed(let error):
                return "获取位置失败 / Location failed: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension PermissionManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            checkLocationPermission()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else { return }

            currentLocation = location

            if let continuation = locationContinuation {
                locationContinuation = nil
                manager.stopUpdatingLocation()
                continuation.resume(returning: location)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locationError = error.localizedDescription

            if let continuation = locationContinuation {
                locationContinuation = nil
                manager.stopUpdatingLocation()
                continuation.resume(throwing: LocationError.failed(error))
            }
        }
    }
}
