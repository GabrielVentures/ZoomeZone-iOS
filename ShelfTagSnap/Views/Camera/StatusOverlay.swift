//
//  StatusOverlay.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//

import SwiftUI
import Combine

/// Status overlay showing scan state and messages
struct StatusOverlay: View {
    // MARK: - Properties

    let message: String?
    let scanState: CameraViewModel.ScanState
    let isLowLight: Bool
    let distanceLevel: BarcodeDetectionResult.DistanceLevel?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            // Top status bar
            topStatusBar

            Spacer()

            // Bottom distance indicator (if needed)
            if let distanceHint = getDistanceHint() {
                distanceIndicator(distanceHint)
                    .padding(.bottom, 120)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Top Status Bar

    private var topStatusBar: some View {
        VStack(spacing: 12) {

            // Brightness warning
            if isLowLight {
                brightnessWarning
            }

            // Status message (only show when no low light warning)
            if let message = message, !isLowLight {
                statusMessage(message)
            }
        }
        .padding(.top, 60)
    }

    // MARK: - Brightness Warning

    private var brightnessWarning: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
                .accessibilityHidden(true)

            Text(Strings.Camera.lowLight)
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.7))
        )
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Strings.Camera.lowLightWarning)
        .accessibilityValue(Strings.Camera.lowLight)
    }

    // MARK: - Status Message

    private func statusMessage(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.6))
            )
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            .transition(.opacity)
            .accessibilityLabel(Strings.Camera.statusMessage)
            .accessibilityValue(text)
    }

    // MARK: - Distance Indicator

    private func distanceIndicator(_ hint: DistanceHint) -> some View {
        VStack(spacing: 8) {
            Image(systemName: hint.iconName)
                .font(.system(size: 40))
                .foregroundColor(hint.color)
                .symbolEffect(.bounce, value: hint)
                .accessibilityHidden(true)

            Text(hint.message)
                .font(.headline)
                .foregroundColor(hint.color)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.7))
        )
        .transition(.scale.combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Strings.Camera.distanceIndicator)
        .accessibilityValue(hint.message)
        .accessibilityHint(hint.accessibilityHint)
    }

    // MARK: - Helper Methods

    private func getDistanceHint() -> DistanceHint? {

        // Return hints based on actual distance detection
        guard let distanceLevel = distanceLevel else {
            return nil
        }

        // Only show hints when distance is not optimal
        switch distanceLevel {
        case .tooFar:
            return .tooFar
        case .tooClose:
            return .tooClose
        case .optimal:
            return nil
        }
    }

    // MARK: - Distance Hint

    struct DistanceHint: Equatable {
        let iconName: String
        let message: String
        let color: Color
        let accessibilityHint: String

        static let tooFar = DistanceHint(
            iconName: "arrow.down.circle.fill",
            message: Strings.Camera.moveCloser,
            color: .orange,
            accessibilityHint: Strings.Camera.moveCloserHint
        )

        static let tooClose = DistanceHint(
            iconName: "arrow.up.circle.fill",
            message: Strings.Camera.moveBack,
            color: .orange,
            accessibilityHint: Strings.Camera.moveBackHint
        )

        static let optimal = DistanceHint(
            iconName: "checkmark.circle.fill",
            message: Strings.Camera.distanceOptimal,
            color: .green,
            accessibilityHint: Strings.Camera.distanceOptimalHint
        )
    }
}

// MARK: - Preview

#Preview("Scanning") {
    ZStack {
        Color.black
        StatusOverlay(
            message: "对准条形码 / Align barcode",
            scanState: .scanning,
            isLowLight: false,
            distanceLevel: nil
        )
    }
}

#Preview("Low Light") {
    ZStack {
        Color.black
        StatusOverlay(
            message: "扫描中 / Scanning...",
            scanState: .scanning,
            isLowLight: true,
            distanceLevel: nil
        )
    }
}

#Preview("Too Far") {
    ZStack {
        Color.black
        StatusOverlay(
            message: "请靠近 / Move closer",
            scanState: .scanning,
            isLowLight: false,
            distanceLevel: .tooFar
        )
    }
}

#Preview("Too Close") {
    ZStack {
        Color.black
        StatusOverlay(
            message: "请后退 / Move back",
            scanState: .scanning,
            isLowLight: false,
            distanceLevel: .tooClose
        )
    }
}
