//
//  MessageView.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//

import SwiftUI

/// Message view for error, success, and warning messages
struct MessageView: View {
    // MARK: - Properties

    /// Message text
    let message: String

    /// Message type
    var type: MessageType = .error

    /// Show dismiss button
    var showDismissButton: Bool = true

    /// Dismiss action
    var onDismiss: (() -> Void)?

    // MARK: - Message Type

    enum MessageType {
        case error
        case success
        case warning
        case info

        var iconName: String {
            switch self {
            case .error:
                return "xmark.circle.fill"
            case .success:
                return "checkmark.circle.fill"
            case .warning:
                return "exclamationmark.triangle.fill"
            case .info:
                return "info.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .error:
                return .red
            case .success:
                return .green
            case .warning:
                return .orange
            case .info:
                return .blue
            }
        }

        var backgroundColor: Color {
            switch self {
            case .error:
                return Color.red.opacity(0.1)
            case .success:
                return Color.green.opacity(0.1)
            case .warning:
                return Color.orange.opacity(0.1)
            case .info:
                return Color.blue.opacity(0.1)
            }
        }
    }

    // MARK: - Body

    var body: some View {
        HStack(alignment: .top, spacing: 12) {

            // Icon
            Image(systemName: type.iconName)
                .font(.title3)
                .foregroundColor(type.color)

            // Message text
            Text(message)
                .font(.subheadline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Dismiss button
            if showDismissButton {
                Button(action: {
                    onDismiss?()
                }) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Circle().fill(Color(.systemGray5)))
                }
                .accessibilityLabel(Strings.Common.dismiss)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(type.backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(type.color.opacity(0.3), lineWidth: 1)
        )
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .opacity
        ))
    }
}

// MARK: - Convenience Extensions

extension MessageView {

    /// Error message
    static func error(_ message: String, onDismiss: (() -> Void)? = nil) -> some View {
        MessageView(message: message, type: .error, onDismiss: onDismiss)
    }

    /// Success message
    static func success(_ message: String, onDismiss: (() -> Void)? = nil) -> some View {
        MessageView(message: message, type: .success, onDismiss: onDismiss)
    }

    /// Warning message
    static func warning(_ message: String, onDismiss: (() -> Void)? = nil) -> some View {
        MessageView(message: message, type: .warning, onDismiss: onDismiss)
    }

    /// Info message
    static func info(_ message: String, onDismiss: (() -> Void)? = nil) -> some View {
        MessageView(message: message, type: .info, onDismiss: onDismiss)
    }
}

// MARK: - Preview

#Preview("Message Types") {
    VStack(spacing: 20) {
        MessageView.error("Sign in failed. Please check your email and password") {
            print("Error dismissed")
        }

        MessageView.success("Sign up successful! Welcome to ShelfTagSnap") {
            print("Success dismissed")
        }

        MessageView.warning("Your password is weak. Consider using a stronger password") {
            print("Warning dismissed")
        }

        MessageView.info("Password reset email sent. Please check your inbox") {
            print("Info dismissed")
        }

        MessageView(
            message: "This is a message without a dismiss button",
            type: .info,
            showDismissButton: false
        )
    }
    .padding()
}
