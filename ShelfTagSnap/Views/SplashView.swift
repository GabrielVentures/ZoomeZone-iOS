//
//  SplashView.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/24.
//

import SwiftUI

/// Splash screen shown during app initialization
struct SplashView: View {
    // MARK: - State

    @State private var isAnimating: Bool = false
    @State private var opacity: Double = 0

    // MARK: - Body

    var body: some View {
        ZStack {

            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.8),
                    Color.blue.opacity(0.6)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // App icon and name
                VStack(spacing: 20) {

                    // Animated icon
                    ZStack {

                        // Outer glow
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 140, height: 140)
                            .scaleEffect(isAnimating ? 1.1 : 1.0)
                            .opacity(isAnimating ? 0.5 : 0.8)

                        // Inner background
                        Circle()
                            .fill(Color.white)
                            .frame(width: 120, height: 120)
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)

                        // SF Symbol icon
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 56, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .accessibilityLabel(Strings.App.appName)

                    // App name
                    Text(Strings.App.appName)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(opacity)
                }

                Spacer()

                // Loading indicator
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)

                    Text(Strings.App.checkingAuthentication)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.bottom, 60)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Strings.App.loading)
            }
        }
        .onAppear {

            // Start animations
            withAnimation(.easeInOut(duration: 1.0)) {
                opacity = 1.0
            }

            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SplashView()
}
