//
//  LoadingButton.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//

import SwiftUI

/// Button with loading state
struct LoadingButton: View {
    // MARK: - Properties

    /// Button title
    let title: String

    /// Is loading
    var isLoading: Bool = false

    /// Is disabled
    var isDisabled: Bool = false

    /// Button style
    var style: ButtonStyle = .primary

    /// Icon name (optional)
    var iconName: String?

    /// Action on tap (supports async)
    let action: () async -> Void

    // MARK: - Button Style

    enum ButtonStyle {
        case primary
        case secondary
        case destructive

        var backgroundColor: Color {
            switch self {
            case .primary:
                return Color.blue
            case .secondary:
                return Color(.systemGray5)
            case .destructive:
                return Color.red
            }
        }

        var foregroundColor: Color {
            switch self {
            case .primary, .destructive:
                return .white
            case .secondary:
                return .primary
            }
        }
    }

    // MARK: - Computed Properties

    private var isButtonDisabled: Bool {
        isLoading || isDisabled
    }

    // MARK: - Body

    var body: some View {
        Button(action: {
            if !isButtonDisabled {

                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()

                // Execute async operation
                Task {
                    await action()
                }
            }
        }) {
            HStack(spacing: 12) {

                // Loading indicator
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: style.foregroundColor))
                        .scaleEffect(0.9)
                        .accessibilityHidden(true)
                } else if let iconName = iconName {

                    // Icon
                    Image(systemName: iconName)
                        .font(.body.weight(.semibold))
                        .accessibilityHidden(true)
                }

                // Title
                Text(title)
                    .font(.body)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isButtonDisabled ? style.backgroundColor.opacity(0.5) : style.backgroundColor)
            )
            .foregroundColor(style.foregroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style == .secondary ? Color(.systemGray4) : Color.clear, lineWidth: 1)
            )
        }
        .disabled(isButtonDisabled)
        .accessibilityLabel(title)
        .accessibilityHint(isLoading ? Strings.Common.loadingPleaseWait : isDisabled ? Strings.Common.buttonIsDisabled : Strings.Common.doubleTapToPerformAction)
        .accessibilityAddTraits(.isButton)
        .accessibilityRemoveTraits(isButtonDisabled ? [] : .isButton)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

// MARK: - Preview

#Preview("Button States") {
    VStack(spacing: 20) {
        // Primary
        LoadingButton(
            title: "登录 / Sign In",
            style: .primary,
            iconName: "arrow.right.circle.fill"
        ) {
            print("Sign In tapped")
        }

        // Loading
        LoadingButton(
            title: "登录中... / Signing In...",
            isLoading: true,
            style: .primary
        ) {
            // Async empty action
        }

        // Disabled
        LoadingButton(
            title: "登录 / Sign In",
            isDisabled: true,
            style: .primary
        ) {
            // Async empty action
        }

        // Secondary
        LoadingButton(
            title: "取消 / Cancel",
            style: .secondary
        ) {
            print("Cancel tapped")
        }

        // Destructive
        LoadingButton(
            title: "删除账户 / Delete Account",
            style: .destructive,
            iconName: "trash.fill"
        ) {
            print("Delete tapped")
        }
    }
    .padding()
}
