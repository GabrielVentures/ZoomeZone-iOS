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
        .alert("需要相机权限 / Camera Permission Required", isPresented: $showPermissionAlert) {
            Button("打开设置 / Open Settings") {
                permissionManager.openAppSettings()
            }
            Button("取消 / Cancel", role: .cancel) {}
        } message: {
            Text("请在设置中允许访问相机以使用扫描功能。\nPlease allow camera access in Settings to use scanning feature.")
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
                Text("需要相机权限")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Camera Permission Required")
                    .font(.title3)
                    .foregroundColor(.secondary)

                Text("扫描条形码需要访问相机")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text("Scanning barcodes requires camera access")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("需要相机权限 / Camera Permission Required")
            .accessibilityValue("扫描条形码需要访问相机 / Scanning barcodes requires camera access")

            LoadingButton(
                title: "打开设置 / Open Settings",
                style: .primary,
                iconName: "gear"
            ) {
                permissionManager.openAppSettings()
            }
            .frame(maxWidth: 300)
            .accessibilityLabel("打开设置以授予相机权限 / Open Settings to grant camera permission")
            .accessibilityHint("打开系统设置页面 / Opens system settings page")
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    CameraView()
        .environmentObject(PermissionManager.shared)
}
