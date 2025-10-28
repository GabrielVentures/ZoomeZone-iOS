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

    // MARK: - State

    @State private var animationScale: CGFloat = 1.0
    @State private var checkmarkRotation: Double = -90
    @State private var savedTextOpacity: Double = 0
    @State private var savedTextScale: CGFloat = 0.5

    // MARK: - Body

    var body: some View {
        ZStack {
            VStack(spacing: 0) {

                // Top status bar
                topStatusBar

                Spacer()

                // Bottom distance indicator removed per user request
                // Distance hints are now shown only in top status bar if needed
            }

            // Success animation (center) - "Echo/Wave Effect"
            if scanState == .completed {
                successAnimation
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

    // MARK: - Success Animation

    /// Success animation with "echo/wave effect" as requested by client
    /// Enhanced with rotation, staggered timing, and layered feedback
    private var successAnimation: some View {
        VStack(spacing: 20) {
            // Green wave circles (echo effect) - 3 layers
            ZStack {
                // Multiple expanding circles for wave effect
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(Color.green, lineWidth: 4)
                        .frame(width: 100, height: 100)
                        .scaleEffect(animationScale)
                        .opacity(2.0 - animationScale)
                        .animation(
                            Animation.easeOut(duration: 0.8)
                                .delay(Double(index) * 0.1),
                            value: animationScale
                        )
                }

                // Center checkmark icon with rotation
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                    .scaleEffect(animationScale > 1.3 ? 1.2 : animationScale)
                    .rotationEffect(.degrees(checkmarkRotation))
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: animationScale)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: checkmarkRotation)
            }

            // "✓ Saved" text with separate opacity and scale
            Text("✓ Saved")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.green)
                )
                .shadow(color: .green.opacity(0.5), radius: 10, x: 0, y: 5)
                .scaleEffect(savedTextScale)
                .opacity(savedTextOpacity)
                .animation(.spring(response: 0.35, dampingFraction: 0.65).delay(0.2), value: savedTextScale)
                .animation(.easeOut(duration: 0.3).delay(0.2), value: savedTextOpacity)
        }
        .onAppear {
            // Trigger animations with staggered timing
            // Layer 1: Wave circles expand immediately
            withAnimation {
                animationScale = 2.0
            }

            // Layer 2: Checkmark rotates in (slight delay)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.1)) {
                checkmarkRotation = 0
            }

            // Layer 3: "Saved" text appears (delayed)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.65).delay(0.2)) {
                savedTextScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.3).delay(0.2)) {
                savedTextOpacity = 1.0
            }
        }
        .onDisappear {
            // Reset animation states
            animationScale = 1.0
            checkmarkRotation = -90
            savedTextOpacity = 0
            savedTextScale = 0.5
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Scan saved successfully")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - Preview

#Preview("Scanning") {
    ZStack {
        Color.black
        StatusOverlay(
            message: "Align barcode",
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
            message: "Scanning...",
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
            message: "Move closer",
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
            message: "Move back",
            scanState: .scanning,
            isLowLight: false,
            distanceLevel: .tooClose
        )
    }
}
