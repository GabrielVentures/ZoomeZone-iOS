//
//  SignUpView.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//

import SwiftUI

/// Sign up view
struct SignUpView: View {
    // MARK: - Environment

    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @FocusState private var focusedField: Field?

    // MARK: - Focus Field

    private enum Field {
        case email
        case password
        case confirmPassword
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                headerSection

                // Error/Success Message
                messageSection

                // Input Fields
                inputSection

                // Password Strength Indicator
                passwordStrengthSection

                // Sign Up Button
                signUpButton

                // Terms and Privacy
                termsSection
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 40)
        }
        .background(Color(.systemBackground))
        .navigationTitle(Strings.Auth.signUp)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(Strings.Common.cancel) {
                    authViewModel.clearForm()
                    dismiss()
                }
            }
        }
        .onAppear {

            // Auto focus on email field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = .email
            }
        }
    }

    // MARK: - View Components

    /// Header section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(.blue.gradient)
                .padding(.bottom, 8)

            // Title
            Text(Strings.Auth.createAccount)
                .font(.largeTitle)
                .fontWeight(.bold)

            // Subtitle
            Text(Strings.Auth.joinShelfTagSnap)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 16)
    }

    /// Message section
    @ViewBuilder
    private var messageSection: some View {
        if let errorMessage = authViewModel.errorMessage {
            MessageView.error(errorMessage) {
                withAnimation {
                    authViewModel.clearError()
                }
            }
        }

        if let successMessage = authViewModel.successMessage {
            MessageView.success(successMessage) {
                withAnimation {
                    authViewModel.clearSuccess()
                }
            }
        }
    }

    /// Input section
    private var inputSection: some View {
        VStack(spacing: 20) {
            // Email Field
            CustomTextField(
                title: Strings.Auth.email,
                placeholder: Strings.Auth.emailPlaceholder,
                text: $authViewModel.email,
                showPassword: .constant(false),
                keyboardType: .emailAddress,
                autocapitalization: .never,
                validationState: getEmailValidationState(),
                validationMessage: getEmailValidationMessage(),
                iconName: "envelope.fill"
            )
            .focused($focusedField, equals: .email)
            .submitLabel(.next)
            .onSubmit {
                focusedField = .password
            }

            // Password Field
            CustomTextField(
                title: Strings.Auth.password,
                placeholder: Strings.Auth.atLeast6Characters,
                text: $authViewModel.password,
                isSecure: true,
                showPassword: $authViewModel.showPassword,
                validationState: getPasswordValidationState(),
                validationMessage: getPasswordValidationMessage(),
                iconName: "lock.fill"
            )
            .focused($focusedField, equals: .password)
            .submitLabel(.next)
            .onSubmit {
                focusedField = .confirmPassword
            }

            // Confirm Password Field
            CustomTextField(
                title: Strings.Auth.confirmPassword,
                placeholder: Strings.Auth.reEnterPassword,
                text: $authViewModel.confirmPassword,
                isSecure: true,
                showPassword: $authViewModel.showConfirmPassword,
                validationState: getConfirmPasswordValidationState(),
                validationMessage: getConfirmPasswordValidationMessage(),
                iconName: "lock.fill"
            )
            .focused($focusedField, equals: .confirmPassword)
            .submitLabel(.go)
            .onSubmit {
                Task {
                    await authViewModel.signUp()
                }
            }
        }
    }

    /// Password strength indicator
    @ViewBuilder
    private var passwordStrengthSection: some View {
        if !authViewModel.password.isEmpty {
            let strength = ValidationHelper.getPasswordStrength(authViewModel.password)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(Strings.Auth.passwordStrength)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(strength.description)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(strength.color)
                }

                // Strength Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(strength.color)
                            .frame(width: geometry.size.width * getStrengthPercentage(strength), height: 6)
                            .animation(.easeInOut(duration: 0.3), value: strength.description)
                    }
                }
                .frame(height: 6)
            }
            .transition(.opacity)
        }
    }

    /// Sign up button
    private var signUpButton: some View {
        LoadingButton(
            title: Strings.Auth.signUp,
            isLoading: authViewModel.isLoading,
            isDisabled: !authViewModel.isSignUpFormValid,
            style: .primary,
            iconName: "checkmark.circle.fill"
        ) {
            Task {
                await authViewModel.signUp()
            }
        }
        .padding(.top, 8)
    }

    /// Terms and privacy section
    private var termsSection: some View {
        VStack(spacing: 8) {
            Text(Strings.Auth.bySigningUpYouAgree)
                .font(.caption)
                .foregroundColor(.secondary)
            +
            Text(Strings.Auth.termsOfService)
                .font(.caption)
                .foregroundColor(.blue)
            +
            Text(Strings.Auth.and)
                .font(.caption)
                .foregroundColor(.secondary)
            +
            Text(Strings.Auth.privacyPolicy)
                .font(.caption)
                .foregroundColor(.blue)
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Validation Helpers

    /// Get email validation state
    private func getEmailValidationState() -> CustomTextField.ValidationState {
        if authViewModel.email.isEmpty {
            return .none
        }
        return authViewModel.isEmailValid ? .valid : .invalid
    }

    /// Get email validation message
    private func getEmailValidationMessage() -> String? {
        if authViewModel.email.isEmpty {
            return nil
        }
        return authViewModel.isEmailValid ? nil : Strings.Auth.pleaseEnterValidEmail
    }

    /// Get password validation state
    private func getPasswordValidationState() -> CustomTextField.ValidationState {
        if authViewModel.password.isEmpty {
            return .none
        }
        return authViewModel.isPasswordValid ? .valid : .invalid
    }

    /// Get password validation message
    private func getPasswordValidationMessage() -> String? {
        if authViewModel.password.isEmpty {
            return nil
        }
        return authViewModel.isPasswordValid ? nil : Strings.Auth.passwordMustBeAtLeast6
    }

    /// Get confirm password validation state
    private func getConfirmPasswordValidationState() -> CustomTextField.ValidationState {
        if authViewModel.confirmPassword.isEmpty {
            return .none
        }
        return authViewModel.passwordsMatch ? .valid : .invalid
    }

    /// Get confirm password validation message
    private func getConfirmPasswordValidationMessage() -> String? {
        if authViewModel.confirmPassword.isEmpty {
            return nil
        }
        return authViewModel.passwordsMatch ? Strings.Auth.passwordsMatch : Strings.Auth.passwordsDoNotMatch
    }

    /// Get password strength percentage
    private func getStrengthPercentage(_ strength: ValidationHelper.PasswordStrength) -> CGFloat {
        switch strength {
        case .empty:
            return 0.0
        case .tooShort:
            return 0.25
        case .weak:
            return 0.5
        case .medium:
            return 0.75
        case .strong:
            return 1.0
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SignUpView()
            .environmentObject(AuthViewModel())
    }
}
