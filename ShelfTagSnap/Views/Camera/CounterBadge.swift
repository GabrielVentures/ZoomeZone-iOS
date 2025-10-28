//
//  CounterBadge.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/27.
//

import SwiftUI

/// Floating counter badge showing session scan count
/// Positioned at bottom-right corner with smooth scale animation
struct CounterBadge: View {
    // MARK: - Properties

    let count: Int

    // MARK: - State

    @State private var scale: CGFloat = 1.0

    // MARK: - Body

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(.green)
                .accessibilityHidden(true)

            Text("\(count)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        )
        .scaleEffect(scale)
        .onChange(of: count) { oldValue, newValue in
            // Animate scale: 1.0 → 1.3 → 1.0
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                scale = 1.3
            }

            // Return to normal size
            withAnimation(.spring(response: 0.3).delay(0.15)) {
                scale = 1.0
            }

            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Strings.Camera.scanCounter)
        .accessibilityValue("\(count) scans")
    }
}

// MARK: - Preview

#Preview("Zero Count") {
    ZStack {
        Color.black
        VStack {
            Spacer()
            HStack {
                Spacer()
                CounterBadge(count: 0)
                    .padding(.trailing, 20)
                    .padding(.bottom, 100)
            }
        }
    }
}

#Preview("Single Digit") {
    ZStack {
        Color.black
        VStack {
            Spacer()
            HStack {
                Spacer()
                CounterBadge(count: 5)
                    .padding(.trailing, 20)
                    .padding(.bottom, 100)
            }
        }
    }
}

#Preview("Double Digit") {
    ZStack {
        Color.black
        VStack {
            Spacer()
            HStack {
                Spacer()
                CounterBadge(count: 42)
                    .padding(.trailing, 20)
                    .padding(.bottom, 100)
            }
        }
    }
}

#Preview("Triple Digit") {
    ZStack {
        Color.black
        VStack {
            Spacer()
            HStack {
                Spacer()
                CounterBadge(count: 128)
                    .padding(.trailing, 20)
                    .padding(.bottom, 100)
            }
        }
    }
}
