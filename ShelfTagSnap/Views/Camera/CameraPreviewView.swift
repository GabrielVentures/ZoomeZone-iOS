//
//  CameraPreviewView.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//

import SwiftUI
import AVFoundation
import UIKit

/// Camera preview container view (uses AVCaptureVideoPreviewLayer as backing layer)
class CameraPreviewUIView: UIView {

    /// Override layerClass to use AVCaptureVideoPreviewLayer automatically
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    /// Type-safe preview layer access
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}

/// Camera preview view wrapping AVCaptureVideoPreviewLayer
struct CameraPreviewView: UIViewRepresentable {
    // MARK: - Properties

    /// AVCaptureSession (pass session directly, not layer)
    let session: AVCaptureSession

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> CameraPreviewUIView {
        print("📹 [PREVIEW] makeUIView - 创建预览视图 | Creating preview view")
        let view = CameraPreviewUIView()

        // Configure preview layer
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill

        print("📹 [PREVIEW] Session 已设置 | Session configured")
        print("📹 [PREVIEW] Session isRunning: \(session.isRunning)")

        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {

        // Session doesn't change, no updates needed

        // Only update if session actually changed (should never happen)
        if uiView.videoPreviewLayer.session !== session {
            print("⚠️ [PREVIEW] Session 变化（异常）| Session changed (unexpected)")
            uiView.videoPreviewLayer.session = session
        }
    }
}
