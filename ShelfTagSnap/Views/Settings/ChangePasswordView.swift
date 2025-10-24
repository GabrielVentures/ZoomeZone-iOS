//
//  ChangePasswordView.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/24.
//

import SwiftUI

/// Change password view using Firebase password reset
struct ChangePasswordView: View {
    // MARK: - Environment

    @EnvironmentObject private var firebaseManager: FirebaseManager
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var isSending: Bool = false
    @State private var showSuccess: Bool = false
    @State private var errorMessage: String?

    // MARK: - Computed Properties

    private var userEmail: String {
        firebaseManager.currentUser?.email ?? ""
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {

                Spacer()
                    .frame(height: 40)

                iconSection

                titleSection

                emailSection

                messageSection

                instructionSection

                sendButton

                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - View Components

    private var iconSection: some View {
        ZStack {
            Circle()
                .fill(Color.orange.opacity(0.1))
                .frame(width: 120, height: 120)

            Image(systemName: "key.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange.gradient)
        }
    }

    private var titleSection: some View {
        VStack(spacing: 12) {
            Text("Reset Your Password")
                .font(.title)
                .fontWeight(.bold)

            Text("We'll send you a password reset link")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var emailSection: some View {
        VStack(spacing: 8) {
            Text("Reset link will be sent to:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(userEmail)
                .font(.headline)
                .foregroundColor(.orange)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.1))
                )
        }
    }

    @ViewBuilder
    private var messageSection: some View {
        if let error = errorMessage {
            MessageView.error(error) {
                withAnimation {
                    errorMessage = nil
                }
            }
        }

        if showSuccess {
            VStack(spacing: 16) {
                MessageView.success("Password reset email sent!") {
                    withAnimation {
                        showSuccess = false
                    }
                }

                VStack(spacing: 8) {
                    Text("Next Steps:")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Text("1.")
                                .fontWeight(.semibold)
                            Text("Check your email inbox")
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Text("2.")
                                .fontWeight(.semibold)
                            Text("Click the password reset link")
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Text("3.")
                                .fontWeight(.semibold)
                            Text("Enter your new password")
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Text("4.")
                                .fontWeight(.semibold)
                            Text("Sign back in to the app")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(12)
            }
        }
    }

    private var instructionSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)

                Text("You'll be signed out after requesting password reset. You can sign back in with your new password.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(12)
        }
    }

    private var sendButton: some View {
        LoadingButton(
            title: showSuccess ? "Email Sent" : "Send Reset Email",
            isLoading: isSending,
            isDisabled: showSuccess,
            style: .primary,
            iconName: showSuccess ? "checkmark.circle.fill" : "envelope.fill"
        ) {
            await sendPasswordResetEmail()
        }
        .padding(.top, 16)
    }

    // MARK: - Actions

    private func sendPasswordResetEmail() async {
        isSending = true
        errorMessage = nil

        do {
            try await firebaseManager.sendPasswordReset(email: userEmail)

            await MainActor.run {
                showSuccess = true

                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    try? firebaseManager.signOut()
                    dismiss()
                }
            }

        } catch {
            await MainActor.run {
                errorMessage = "Failed to send reset email. Please try again."
            }
        }

        await MainActor.run {
            isSending = false
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ChangePasswordView()
            .environmentObject(FirebaseManager.shared)
    }
}
