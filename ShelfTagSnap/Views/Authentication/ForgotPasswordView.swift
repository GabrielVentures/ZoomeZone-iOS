//
//  ForgotPasswordView.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//

import SwiftUI

/// Forgot password view
struct ForgotPasswordView: View {
    // MARK: - Environment

    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @FocusState private var isEmailFocused: Bool
    @State private var emailSent: Bool = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                headerSection

                // Email Sent Success or Input Form
                if emailSent {
                    successSection
                } else {
                    // Error/Success Message
                    messageSection

                    // Input Section
                    inputSection

                    // Send Button
                    sendButton

                    // Info Section
                    infoSection
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 40)
        }
        .background(Color(.systemBackground))
        .navigationTitle(Strings.Auth.resetPassword)
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
                isEmailFocused = true
            }
        }
        .onChange(of: authViewModel.successMessage) { _, newValue in
            if newValue != nil {

                // Show success state
                withAnimation {
                    emailSent = true
                }

                // Auto dismiss after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    authViewModel.clearForm()
                    dismiss()
                }
            }
        }
    }

    // MARK: - View Components

    /// Header section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: emailSent ? "checkmark.circle.fill" : "envelope.badge.shield.half.filled")
                .font(.system(size: 64))
                .foregroundStyle(emailSent ? .green : .blue)
                .padding(.bottom, 8)

            if !emailSent {
                // Title
                Text(Strings.Auth.forgotPasswordTitle)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                // Description
                Text(Strings.Auth.enterEmailForReset)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
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
    }

    /// Input section
    private var inputSection: some View {
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
        .focused($isEmailFocused)
        .submitLabel(.send)
        .onSubmit {
            Task {
                await authViewModel.sendPasswordReset()
            }
        }
    }

    /// Send button
    private var sendButton: some View {
        LoadingButton(
            title: Strings.Auth.sendResetLink,
            isLoading: authViewModel.isLoading,
            isDisabled: !authViewModel.isEmailValid,
            style: .primary,
            iconName: "paperplane.fill"
        ) {
            Task {
                await authViewModel.sendPasswordReset()
            }
        }
        .padding(.top, 8)
    }

    /// Info section
    private var infoSection: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.vertical, 8)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text(Strings.Auth.checkSpamFolder)
                        .font(.subheadline)
                    Spacer()
                }

                HStack(spacing: 12) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.orange)
                    Text(Strings.Auth.resetLinkValid24Hours)
                        .font(.subheadline)
                    Spacer()
                }

                HStack(spacing: 12) {
                    Image(systemName: "shield.fill")
                        .foregroundColor(.green)
                    Text(Strings.Auth.accountSecurityPriority)
                        .font(.subheadline)
                    Spacer()
                }
            }
            .foregroundColor(.secondary)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
    }

    /// Success section
    private var successSection: some View {
        VStack(spacing: 24) {
            Text(Strings.Auth.emailSent)
                .font(.title)
                .fontWeight(.bold)

            MessageView.success("\(Strings.Auth.passwordResetEmailSentTo) \(authViewModel.email). \(Strings.Auth.pleaseCheckInbox)") {
                // No dismiss action needed
            }
            .padding(.top)

            Text(Strings.Auth.pageWillClose)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 16)
        }
        .transition(.scale.combined(with: .opacity))
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
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ForgotPasswordView()
            .environmentObject(AuthViewModel())
    }
}
