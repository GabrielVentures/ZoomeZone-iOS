//
//  EmailVerificationView.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/24.

//

import SwiftUI
import Combine

struct EmailVerificationView: View {
    // MARK: - Environment

    @EnvironmentObject private var firebaseManager: FirebaseManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - State

    @State private var isCheckingVerification = false
    @State private var isResendingEmail = false
    @State private var showSuccessMessage = false
    @State private var errorMessage: String?
    @State private var verificationTimer: Timer?
    @State private var progress: Double = 0
    @State private var showCelebration = false

    // MARK: - Auto-check interval (increased for better UX)

    private let autoCheckInterval: TimeInterval = 5.0

    // MARK: - Computed Properties

    private var userEmail: String {
        firebaseManager.currentUser?.email ?? "your email"
    }

    private var canResend: Bool {
        !isResendingEmail && !firebaseManager.isEmailVerified
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 40)

                statusIconSection

                titleSection

                emailSection

                progressSection

                messageSection

                actionButtonsSection

                instructionsSection

                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .background(Color(.systemBackground))
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                signOutButton
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                refreshButton
            }
        }
        .onAppear {
            startAutoVerificationCheck()
        }
        .onDisappear {
            stopAutoVerificationCheck()
        }
        .onChange(of: firebaseManager.isEmailVerified) { verified in
            if verified {
                handleVerificationSuccess()
            }
        }
        .sheet(isPresented: $showCelebration) {
            SuccessCelebrationView()
                .presentationDetents([.fraction(0.4)])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Status Icon Section

    private var statusIconSection: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.2), .blue.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)

            if firebaseManager.isEmailVerified {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Image(systemName: "envelope.badge.shield.half.filled")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: firebaseManager.isEmailVerified)
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(spacing: 16) {
            Text(firebaseManager.isEmailVerified ? "Email Verified!" : "Check Your Email")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .animation(.easeInOut, value: firebaseManager.isEmailVerified)

            Text(firebaseManager.isEmailVerified ?
                 "Your email has been successfully verified" :
                 "We've sent a verification link to your email")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .animation(.easeInOut, value: firebaseManager.isEmailVerified)
        }
    }

    // MARK: - Email Section

    private var emailSection: some View {
        VStack(spacing: 8) {
            Text("Sent to:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(userEmail)
                .font(.headline)
                .foregroundColor(.blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                )
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "arrow.trianglehead.2.clockwise")
                    .font(.caption)
                    .foregroundColor(.blue)

                Text("Auto-checking verification status...")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }

            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .scaleEffect(y: 0.5)
        }
        .opacity(firebaseManager.isEmailVerified ? 0 : 1)
        .animation(.easeInOut, value: firebaseManager.isEmailVerified)
    }

    // MARK: - Message Section

    @ViewBuilder
    private var messageSection: some View {
        if let error = errorMessage {
            MessageView.error(error) {
                withAnimation {
                    errorMessage = nil
                }
            }
        }

        if showSuccessMessage {
            MessageView.success("Verification email sent! Please check your inbox.") {
                withAnimation {
                    showSuccessMessage = false
                }
            }
        }
    }

    // MARK: - Action Buttons Section

    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            if !firebaseManager.isEmailVerified {

                LoadingButton(
                    title: "I've Verified My Email",
                    isLoading: isCheckingVerification,
                    style: .primary,
                    iconName: "checkmark.circle.fill"
                ) {
                    await checkVerificationStatus()
                }

                LoadingButton(
                    title: "Resend Verification Email",
                    isLoading: isResendingEmail,
                    isDisabled: !canResend,
                    style: .secondary,
                    iconName: "envelope.arrow.triangle.branch"
                ) {
                    await resendVerificationEmail()
                }

            } else {

                Button("Continue to App") {
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Instructions Section

    private var instructionsSection: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 16) {
                Text("Verification Steps:")
                    .font(.headline)
                    .fontWeight(.semibold)

                VStack(spacing: 12) {
                    InstructionRow(
                        step: "1",
                        title: "Check your email inbox",
                        description: "Look for an email from ShelfTagSnap"
                    )

                    InstructionRow(
                        step: "2",
                        title: "Click the verification link",
                        description: "This will verify your email address"
                    )

                    InstructionRow(
                        step: "3",
                        title: "Return to the app",
                        description: "We'll automatically detect the verification"
                    )
                }
            }

            TroubleshootingTips()
        }
    }

    // MARK: - Toolbar Buttons

    private var signOutButton: some View {
        Button("Sign Out") {
            handleSignOut()
        }
        .foregroundColor(.red)
    }

    private var refreshButton: some View {
        Button {
            Task {
                await checkVerificationStatus()
            }
        } label: {
            Image(systemName: "arrow.clockwise")
                .foregroundColor(.blue)
        }
        .disabled(isCheckingVerification)
    }

    // MARK: - Actions

    private func checkVerificationStatus() async {
        isCheckingVerification = true
        errorMessage = nil

        let isVerified = await firebaseManager.checkEmailVerified()

        await MainActor.run {
            isCheckingVerification = false

            if !isVerified {
                errorMessage = "Email not verified yet. Please check your inbox and click the verification link."
            }
        }
    }

    private func resendVerificationEmail() async {
        isResendingEmail = true
        errorMessage = nil

        do {
            try await firebaseManager.sendEmailVerification()

            await MainActor.run {
                showSuccessMessage = true

                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation {
                        showSuccessMessage = false
                    }
                }
            }

        } catch {
            await MainActor.run {
                if let firebaseError = error as? FirebaseManager.FirebaseError {
                    errorMessage = firebaseError.localizedDescription
                } else {
                    errorMessage = "Failed to send verification email. Please try again."
                }
            }
        }

        await MainActor.run {
            isResendingEmail = false
        }
    }

    private func handleSignOut() {
        do {
            try firebaseManager.signOut()
        } catch {
            errorMessage = "Failed to sign out: \(error.localizedDescription)"
        }
    }

    private func handleVerificationSuccess() {

        stopAutoVerificationCheck()

        let haptic = UINotificationFeedbackGenerator()
        haptic.notificationOccurred(.success)

        showCelebration = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            dismiss()
        }
    }

    // MARK: - Auto Verification Check

    private func startAutoVerificationCheck() {
        guard !firebaseManager.isEmailVerified else { return }

        print("✅ [EmailVerificationView] 开始自动验证检查 (每\(autoCheckInterval)秒)")

        verificationTimer = Timer.scheduledTimer(withTimeInterval: autoCheckInterval, repeats: true) { _ in

            withAnimation(.linear(duration: autoCheckInterval)) {
                progress = 1.0
            }

            Task {
                let isVerified = await firebaseManager.checkEmailVerified()
                if isVerified {
                    await MainActor.run {
                        stopAutoVerificationCheck()
                        handleVerificationSuccess()
                    }
                } else {

                    await MainActor.run {
                        progress = 0
                    }
                }
            }
        }
    }

    private func stopAutoVerificationCheck() {
        verificationTimer?.invalidate()
        verificationTimer = nil
        progress = 0
        print("⏹️ [EmailVerificationView] 停止自动验证检查")
    }
}

// MARK: - Supporting Views

struct InstructionRow: View {
    let step: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 24, height: 24)

                Text(step)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

struct TroubleshootingTips: View {
    @State private var showTips = false

    var body: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut) {
                    showTips.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundColor(.blue)

                    Text("Didn't receive the email?")
                        .font(.subheadline)
                        .foregroundColor(.blue)

                    Spacer()

                    Image(systemName: showTips ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }

            if showTips {
                VStack(alignment: .leading, spacing: 8) {
                    TipRow(
                        icon: "clock",
                        text: "Check your spam/junk folder"
                    )
                    TipRow(
                        icon: "hourglass",
                        text: "Wait a few minutes - emails can be delayed"
                    )
                    TipRow(
                        icon: "envelope.arrow.triangle.branch",
                        text: "Try resending the verification email"
                    )
                    TipRow(
                        icon: "at",
                        text: "Make sure your email address is correct"
                    )
                }
                .padding(.leading, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
}

struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
                .frame(width: 16)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct SuccessCelebrationView: View {
    @State private var isAnimating = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.green.opacity(0.3), .green.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
            }

            VStack(spacing: 8) {
                Text("🎉 Email Verified!")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("You can now access all features")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Awesome!") {
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(32)
        .onAppear {

            let haptic = UINotificationFeedbackGenerator()
            haptic.notificationOccurred(.success)

            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EmailVerificationView()
            .environmentObject(FirebaseManager.shared)
    }
}
