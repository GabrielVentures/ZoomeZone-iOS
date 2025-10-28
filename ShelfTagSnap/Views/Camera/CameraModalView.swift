//
//  CameraModalView.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//

import SwiftUI

/// Camera modal view (full-screen) for scanning
struct CameraModalView: View {
    // MARK: - Properties

    let task: TaskType
    let storeName: String
    let permissionManager: PermissionManager

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @StateObject private var viewModel: CameraViewModel
    @State private var showPermissionAlert: Bool = false
    @State private var isInitialized: Bool = false
    @State private var showLoadingAnimation: Bool = false

    // MARK: - Initialization

    init(task: TaskType, storeName: String, permissionManager: PermissionManager) {
        self.task = task
        self.storeName = storeName
        self.permissionManager = permissionManager

        // Initialize viewModel with preselected store name
        _viewModel = StateObject(wrappedValue: CameraViewModel(preselectedStoreName: storeName))
    }

    // MARK: - Body

    var body: some View {
        _ = print("🎬 [CAMERA_MODAL] ========================================")
        _ = print("🎬 [CAMERA_MODAL] body called at \(Date().timeIntervalSince1970)")
        _ = print("🎬 [CAMERA_MODAL] storeName: \(storeName)")
        _ = print("🎬 [CAMERA_MODAL] task: \(task.rawValue)")
        _ = print("🎬 [CAMERA_MODAL] isInitialized: \(isInitialized)")
        _ = print("🎬 [CAMERA_MODAL] permissionManager.cameraAuthorized: \(permissionManager.cameraAuthorized)")
        _ = print("🎬 [CAMERA_MODAL] ========================================")

        return ZStack {

            // Black background (bottom layer, always visible)
            Color.black
                .ignoresSafeArea()

            // Camera preview or loading state
            Group {
                if permissionManager.cameraAuthorized && isInitialized {

                    // Camera preview
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

                    VStack(spacing: 32) {

                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 3)
                                .frame(width: 80, height: 80)

                            Circle()
                                .trim(from: 0, to: 0.7)
                                .stroke(Color.blue, lineWidth: 3)
                                .frame(width: 80, height: 80)
                                .rotationEffect(Angle(degrees: showLoadingAnimation ? 360 : 0))
                                .animation(
                                    Animation.linear(duration: 1)
                                        .repeatForever(autoreverses: false),
                                    value: showLoadingAnimation
                                )

                            Image(systemName: "camera.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        }

                        VStack(spacing: 12) {
                            Text(Strings.Camera.initializingCamera)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)

                            Text(Strings.Camera.configuringCamera)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.top, 8)
                        }
                    }
                    .onAppear {

                        showLoadingAnimation = true
                    }
                }
            }

            // Top toolbar (overlay)
            VStack {
                HStack {

                    // Close button
                    Button(action: {
                        print("🔙 [CAMERA_MODAL] User tapped close")
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }

                    Spacer()
                }
                .padding()
                .padding(.top, 8)

                Spacer()
            }

            // Counter badge (bottom-right floating badge)
            if permissionManager.cameraAuthorized && isInitialized {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        CounterBadge(count: viewModel.sessionScanCount)
                            .padding(.trailing, 20)
                            .padding(.bottom, 100)
                    }
                }
                .ignoresSafeArea()
            }

            // Error message (if any)
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
        // Merchant picker and confirmation sheets removed - now auto-saves immediately
        .alert(Strings.Camera.cameraPermissionRequired, isPresented: $showPermissionAlert) {
            Button(Strings.Permissions.openSettings) {
                permissionManager.openAppSettings()
            }
            Button(Strings.Common.cancel, role: .cancel) {
                dismiss()
            }
        } message: {
            Text(Strings.Camera.allowCameraAccess)
        }
        .alert(Strings.Duplicate.title, isPresented: $viewModel.showDuplicateAlert) {
            Button(Strings.Duplicate.cancel, role: .cancel) {
                viewModel.cancelDuplicateScan()
            }
            Button(Strings.Duplicate.scanAgain) {
                viewModel.allowDuplicateScan()
            }
        } message: {
            if let info = viewModel.duplicateInfo {
                let message = String(format: Strings.Duplicate.message, info.merchant)
                let scannedAt = info.timestamp.formatted(date: .abbreviated, time: .shortened)
                let locationText = info.storeLocation.map { "\nLocation: \($0)" } ?? ""

                Text("\(message)\(locationText)\n\n\(Strings.Duplicate.scannedAt) \(scannedAt)")
            }
        }
        .task {
            print("⚡ [CAMERA_MODAL] .task triggered at \(Date().timeIntervalSince1970)")
            await initializeCamera()
        }
        .onDisappear {
            print("👋 [CAMERA_MODAL] View disappeared, cleaning up")
            viewModel.reset()
        }
        .statusBar(hidden: false)
    }

    // MARK: - Methods

    /// Initialize camera
    private func initializeCamera() async {
        print("📸 [CAMERA_MODAL] ========================================")
        print("📸 [CAMERA_MODAL] Starting camera initialization")
        print("📸 [CAMERA_MODAL] Timestamp: \(Date().timeIntervalSince1970)")
        print("📸 [CAMERA_MODAL] Store: \(storeName)")
        print("📸 [CAMERA_MODAL] Task: \(task.rawValue)")
        print("📸 [CAMERA_MODAL] ========================================")

        // Request camera permission (if needed)
        if !permissionManager.cameraAuthorized {
            print("📸 [CAMERA_MODAL] Camera not authorized, requesting permission")
            let granted = await permissionManager.requestCameraPermission()
            if !granted {
                print("❌ [CAMERA_MODAL] Camera permission denied")
                showPermissionAlert = true
                return
            }
            print("✅ [CAMERA_MODAL] Camera permission granted")
        } else {
            print("✅ [CAMERA_MODAL] Camera permission already granted")
        }

        // Request location permission (optional)
        if !permissionManager.locationAuthorized {
            print("📍 [CAMERA_MODAL] Requesting location permission")
            permissionManager.requestLocationPermission()
        }

        // Initialize camera manager (async, doesn't block UI)
        print("📸 [CAMERA_MODAL] Calling initializeCamera (nonisolated, non-blocking) at \(Date().timeIntervalSince1970)")
        await viewModel.initializeCamera()
        print("✅ [CAMERA_MODAL] initializeCamera completed at \(Date().timeIntervalSince1970)")

        // Mark as initialized (on MainActor)
        isInitialized = true
        print("✅ [CAMERA_MODAL] UI updated isInitialized = true at \(Date().timeIntervalSince1970)")

        // Start scanning (on MainActor)
        viewModel.startScanning()
        print("✅ [CAMERA_MODAL] Started scanning at \(Date().timeIntervalSince1970)")
        print("📸 [CAMERA_MODAL] ========================================")
    }
}

// MARK: - Preview

#Preview {
    CameraModalView(
        task: .shelfTagSnap,
        storeName: "7-Eleven",
        permissionManager: PermissionManager.shared
    )
}
