//
//  CustomTextField.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//

import SwiftUI
import Combine

/// Custom text field with validation and password toggle
struct CustomTextField: View {
    // MARK: - Properties

    /// Title
    let title: String

    /// Placeholder
    let placeholder: String

    /// Bound text value
    @Binding var text: String

    /// Is password field
    var isSecure: Bool = false

    /// Show password toggle
    @Binding var showPassword: Bool

    /// Keyboard type
    var keyboardType: UIKeyboardType = .default

    /// Auto capitalization type
    var autocapitalization: TextInputAutocapitalization = .never

    /// Validation state
    var validationState: ValidationState = .none

    /// Validation message
    var validationMessage: String?

    /// SF Symbol icon name
    var iconName: String?

    // MARK: - Validation State

    enum ValidationState {
        case none
        case valid
        case invalid
        case warning

        var color: Color {
            switch self {
            case .none:
                return .secondary
            case .valid:
                return .green
            case .invalid:
                return .red
            case .warning:
                return .orange
            }
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // Title
            if !title.isEmpty {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }

            // Input container
            HStack(spacing: 12) {

                // Leading icon
                if let iconName = iconName {
                    Image(systemName: iconName)
                        .foregroundColor(validationState.color)
                        .frame(width: 20)
                        .accessibilityHidden(true)
                }

                // Text input
                if isSecure && !showPassword {
                    SecureField(placeholder, text: $text)
                        .textInputAutocapitalization(autocapitalization)
                        .keyboardType(keyboardType)
                        .accessibilityLabel(title)
                } else {
                    TextField(placeholder, text: $text)
                        .textInputAutocapitalization(autocapitalization)
                        .keyboardType(keyboardType)
                        .accessibilityLabel(title)
                }

                // Password visibility toggle
                if isSecure {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showPassword.toggle()
                        }
                    }) {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .accessibilityLabel(showPassword ? Strings.Auth.hidePassword : Strings.Auth.showPassword)
                }

                // Validation state icon
                if validationState == .valid {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .frame(width: 20)
                        .accessibilityLabel(Strings.Common.inputValid)
                } else if validationState == .invalid {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .frame(width: 20)
                        .accessibilityLabel(Strings.Common.inputInvalid)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(validationState.color, lineWidth: validationState == .none ? 0 : 1.5)
            )

            // Validation message
            if let message = validationMessage, validationState != .none {
                HStack(spacing: 6) {
                    Image(systemName: validationState == .invalid ? "exclamationmark.circle.fill" : "info.circle.fill")
                        .font(.caption)
                        .accessibilityHidden(true)
                    Text(message)
                        .font(.caption)
                }
                .foregroundColor(validationState.color)
                .transition(.opacity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Strings.Common.validationMessage)
                .accessibilityValue(message)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: validationState)
    }
}

// MARK: - Preview

#Preview("Email Field") {
    VStack(spacing: 20) {
        CustomTextField(
            title: "Email",
            placeholder: "example@email.com",
            text: .constant("test@example.com"),
            showPassword: .constant(false),
            keyboardType: .emailAddress,
            validationState: .valid,
            iconName: "envelope.fill"
        )

        CustomTextField(
            title: "Email",
            placeholder: "example@email.com",
            text: .constant("invalid-email"),
            showPassword: .constant(false),
            keyboardType: .emailAddress,
            validationState: .invalid,
            validationMessage: "Please enter a valid email",
            iconName: "envelope.fill"
        )
    }
    .padding()
}

#Preview("Password Field") {
    VStack(spacing: 20) {
        CustomTextField(
            title: "Password",
            placeholder: "••••••",
            text: .constant("password123"),
            isSecure: true,
            showPassword: .constant(false),
            validationState: .valid,
            iconName: "lock.fill"
        )

        CustomTextField(
            title: "Password",
            placeholder: "••••••",
            text: .constant("123"),
            isSecure: true,
            showPassword: .constant(false),
            validationState: .invalid,
            validationMessage: "Password must be at least 6 characters",
            iconName: "lock.fill"
        )
    }
    .padding()
}
