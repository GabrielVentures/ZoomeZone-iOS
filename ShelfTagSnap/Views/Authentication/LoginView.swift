//
//  LoginView.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//

import SwiftUI

/// Login view
struct LoginView: View {
    // MARK: - Environment

    @EnvironmentObject private var authViewModel: AuthViewModel

    // MARK: - Properties

    /// Show sign up view
    @Binding var showSignUp: Bool

    /// Show forgot password view
    @Binding var showForgotPassword: Bool

    // MARK: - State

    @FocusState private var focusedField: Field?
    @State private var keyboardHeight: CGFloat = 0

    // MARK: - Focus Field

    private enum Field {
        case email
        case password
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

                // Forgot Password Link
                forgotPasswordSection

                // Sign In Button
                signInButton

                // Divider
                Divider()
                    .padding(.vertical, 8)

                // Sign Up Link
                signUpSection
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 40)
        }
        .safeAreaInset(edge: .bottom) {
            if keyboardHeight > 0 {
                Color.clear
                    .frame(height: keyboardHeight - 50)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = nil
        }
        .background(Color(.systemBackground))
        .onAppear {
            // Auto focus on email field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = .email
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                withAnimation(.easeOut(duration: 0.3)) {
                    keyboardHeight = keyboardFrame.height
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                keyboardHeight = 0
            }
        }
    }

    // MARK: - View Components

    /// Header section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // App Icon/Logo
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(.blue.gradient)
                .padding(.bottom, 8)

            // Title
            Text(Strings.Auth.welcomeBack)
                .font(.largeTitle)
                .fontWeight(.bold)
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
                placeholder: Strings.Auth.passwordPlaceholder,
                text: $authViewModel.password,
                isSecure: true,
                showPassword: $authViewModel.showPassword,
                validationState: getPasswordValidationState(),
                validationMessage: getPasswordValidationMessage(),
                iconName: "lock.fill"
            )
            .focused($focusedField, equals: .password)
            .submitLabel(.go)
            .onSubmit {
                Task {
                    await authViewModel.signIn()
                }
            }
        }
    }

    /// Forgot password section
    private var forgotPasswordSection: some View {
        HStack {
            Spacer()
            Button(action: {
                showForgotPassword = true
            }) {
                Text(Strings.Auth.forgotPasswordTitle)
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
    }

    /// Sign in button
    private var signInButton: some View {
        LoadingButton(
            title: Strings.Auth.signIn,
            isLoading: authViewModel.isLoading,
            isDisabled: !authViewModel.isLoginFormValid,
            style: .primary,
            iconName: "arrow.right.circle.fill"
        ) {
            focusedField = nil  // Dismiss keyboard
            Task {
                await authViewModel.signIn()
            }
        }
        .padding(.top, 8)
    }

    /// Sign up section
    private var signUpSection: some View {
        HStack(spacing: 4) {
            Text(Strings.Auth.dontHaveAccount)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button(action: {
                focusedField = nil  // Dismiss keyboard
                showSignUp = true
            }) {
                Text(Strings.Auth.signUp)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
        }
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
        return .none
    }

    /// Get password validation message
    private func getPasswordValidationMessage() -> String? {
        return nil
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LoginView(
            showSignUp: .constant(false),
            showForgotPassword: .constant(false)
        )
        .environmentObject(AuthViewModel())
    }
}
