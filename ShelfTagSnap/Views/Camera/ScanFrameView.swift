//
//  ScanFrameView.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//

import SwiftUI

/// Scan frame view - minimalist (corners only)
struct ScanFrameView: View {
    // MARK: - Properties

    private let frameWidth: CGFloat = 280
    private let frameHeight: CGFloat = 180

    // MARK: - Animation State

    @State private var scanLineOffset: CGFloat = 0

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Scan frame - only corner decorations
            ZStack {

                // Corner decorations
                cornerDecorations

                // Scan line container (ensure within frame bounds)
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: frameWidth - 16, height: frameHeight - 16)
                    .overlay {
                        scanLine
                    }
                    .clipped()
            }
            .frame(width: frameWidth, height: frameHeight)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Strings.Camera.alignBarcode)

            Spacer()
        }
    }

    // MARK: - Corner Decorations

    private var cornerDecorations: some View {
        ZStack {

            CornerView(rotation: 0)
                .position(x: 0, y: 0)

            CornerView(rotation: 90)
                .position(x: frameWidth, y: 0)

            CornerView(rotation: 180)
                .position(x: frameWidth, y: frameHeight)

            CornerView(rotation: 270)
                .position(x: 0, y: frameHeight)
        }
    }

    // MARK: - Scan Line

    private var scanLine: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.green.opacity(0.0),
                            Color.green.opacity(0.95),
                            Color.green.opacity(0.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: geometry.size.width - 32, height: 3)
                .position(
                    x: geometry.size.width / 2,
                    y: scanLineOffset
                )
                .onAppear {

                    // Initial position: top (1px margin)
                    scanLineOffset = 1

                    // Animate to bottom and repeat
                    withAnimation(
                        Animation
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true)
                    ) {
                        scanLineOffset = geometry.size.height - 1
                    }
                }
        }
    }
}

// MARK: - Corner View

/// Corner decoration view
struct CornerView: View {
    let rotation: Double

    var body: some View {
        ZStack {

            Rectangle()
                .fill(Color.green)
                .frame(width: 24, height: 4)
                .offset(x: 12, y: 0)

            Rectangle()
                .fill(Color.green)
                .frame(width: 4, height: 24)
                .offset(x: 0, y: 12)
        }
        .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray
        ScanFrameView()
    }
}
