//
//  CameraView.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//

import SwiftUI
import AVFoundation

/// Main camera scanning view
struct CameraView: View {
    // MARK: - Environment

    @EnvironmentObject private var permissionManager: PermissionManager
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - State Objects

    @StateObject private var viewModel = CameraViewModel()

    // MARK: - State

    @State private var showPermissionAlert: Bool = false

    // MARK: - Body

    var body: some View {
        ZStack {

            // Camera preview
            if permissionManager.cameraAuthorized {
                CameraPreviewView(session: viewModel.getCaptureSession())
                    .ignoresSafeArea()

                // Scan frame
                if viewModel.scanState == .scanning || viewModel.scanState == .idle {
                    ScanFrameView()
                }

                // Status overlay
                StatusOverlay(
                    message: viewModel.statusMessage,
                    scanState: viewModel.scanState,
                    isLowLight: viewModel.isLowLight,
                    distanceLevel: viewModel.currentDistanceLevel
                )

            } else {

                // Permission not granted placeholder
                permissionDeniedView
            }

            // Error message
            if let errorMessage = viewModel.errorMessage {
                VStack {
                    Spacer()
                    MessageView.error(errorMessage) {
                        viewModel.errorMessage = nil
                    }
                    .padding()
                    Spacer().frame(height: 100)
                }
            }
        }
        .sheet(isPresented: $viewModel.showMerchantPicker) {
            MerchantPickerView(
                selectedMerchant: $viewModel.selectedMerchant,
                onSelect: { merchant in
                    viewModel.selectMerchant(merchant)
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $viewModel.showResultConfirmation) {
            if let photo = viewModel.capturedPhoto,
               let barcode = viewModel.detectedBarcode,
               let merchant = viewModel.selectedMerchant {
                ScanResultView(
                    photo: photo,
                    barcode: barcode,
                    barcodeSymbology: viewModel.detectedSymbology,
                    merchant: merchant,
                    storeLocation: $viewModel.storeLocation,
                    onSave: {
                        Task {
                            await viewModel.saveScanRecord()
                        }
                    },
                    onCancel: {
                        viewModel.cancelSave()
                    }
                )
            }
        }
        .task {

            // Request permissions
            if !permissionManager.cameraAuthorized {
                let granted = await permissionManager.requestCameraPermission()
                if !granted {
                    showPermissionAlert = true
                    return
                }
            }

            // Request location permission (optional)
            if !permissionManager.locationAuthorized {
                permissionManager.requestLocationPermission()
            }

            // Initialize camera
            await viewModel.initializeCamera()
            viewModel.startScanning()
        }
        .onChange(of: scenePhase) { _, newPhase in

            // Handle app lifecycle
            switch newPhase {
            case .active:
                if permissionManager.cameraAuthorized && viewModel.scanState == .idle {
                    viewModel.startScanning()
                }
            case .inactive, .background:
                viewModel.stopScanning()
            @unknown default:
                break
            }
        }
        .onDisappear {
            viewModel.reset()
        }
        .alert("Camera Permission Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                permissionManager.openAppSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please allow camera access in Settings to use scanning feature.")
        }
    }

    // MARK: - Permission Denied View

    private var permissionDeniedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.fill")
                .font(.system(size: 80))
                .foregroundColor(.gray)
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text("Camera Permission Required")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Camera Permission Required")
                    .font(.title3)
                    .foregroundColor(.secondary)

                Text("Scanning barcodes requires camera access")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text("Scanning barcodes requires camera access")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Camera Permission Required")
            .accessibilityValue("Scanning barcodes requires camera access / Scanning barcodes requires camera access")

            LoadingButton(
                title: "Open Settings",
                style: .primary,
                iconName: "gear"
            ) {
                permissionManager.openAppSettings()
            }
            .frame(maxWidth: 300)
            .accessibilityLabel("Open Settings to grant camera permission")
            .accessibilityHint("Opens system settings page")
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    CameraView()
        .environmentObject(PermissionManager.shared)
}
