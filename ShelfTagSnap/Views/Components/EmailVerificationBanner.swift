//
//  EmailVerificationBanner.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/24.

//

import SwiftUI
import Foundation
import Combine

/// Email verification banner with gentle user guidance
struct EmailVerificationBanner: View {
    // MARK: - Environment

    @EnvironmentObject private var firebaseManager: FirebaseManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    // MARK: - State

    @StateObject private var notificationStrategy = NotificationStrategy()
    @State private var showVerificationView = false
    @State private var isAnimating = false
    @State private var messageIndex = 0
    @State private var isDismissed = false

    // MARK: - Timer

    @State private var messageRotationTimer: Timer?

    // MARK: - Computed Properties

    private var shouldShow: Bool {
        !isDismissed &&
        !firebaseManager.isEmailVerified &&
        notificationStrategy.shouldShowBanner()
    }

    private var currentMessage: String {
        BannerMessages.rotatingMessages[messageIndex % BannerMessages.rotatingMessages.count]
    }

    private var userEmail: String {
        firebaseManager.currentUser?.email ?? "your email"
    }

    // MARK: - Body

    var body: some View {
        if shouldShow {
            bannerContent
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
                .onAppear {
                    startAnimation()
                    startMessageRotation()
                }
                .onDisappear {
                    stopTimers()
                }
                .sheet(isPresented: $showVerificationView) {
                    verificationSheet
                }
        }
    }

    // MARK: - Banner Content

    private var bannerContent: some View {
        HStack(spacing: 12) {

            statusIcon

            VStack(alignment: .leading, spacing: 4) {
                messageText
                emailIndicator
            }

            Spacer()

            actionButtons
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(bannerBackground)
        .overlay(bannerBorder, alignment: .bottom)
        .clipShape(RoundedRectangle(cornerRadius: 0))
        .shadow(
            color: .black.opacity(0.1),
            radius: 4,
            x: 0,
            y: 2
        )
    }

    // MARK: - Status Icon

    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(VerificationColors.warning.opacity(0.2))
                .frame(width: 32, height: 32)

            Image(systemName: "envelope.badge.shield.half.filled")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(VerificationColors.warning)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
        }
        .accessibilityLabel("Verification required")
    }

    // MARK: - Message Text

    private var messageText: some View {
        Text(currentMessage)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(VerificationColors.textPrimary)
            .animation(.easeInOut(duration: 0.3), value: messageIndex)
            .accessibilityLabel("Verification message")
    }

    // MARK: - Email Indicator

    private var emailIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "envelope.fill")
                .font(.caption2)
                .foregroundColor(VerificationColors.textSecondary)

            Text(userEmail)
                .font(.caption)
                .foregroundColor(VerificationColors.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .accessibilityLabel("Email address: \(userEmail)")
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 8) {

            Button("Verify") {
                handleVerifyTap()
            }
            .buttonStyle(CompactButtonStyle(style: .primary))
            .accessibilityLabel("Verify email address")
            .accessibilityHint("Opens email verification screen")

            Button {
                handleDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(VerificationColors.textSecondary)
            }
            .accessibilityLabel("Dismiss")
            .accessibilityHint("Hide this banner temporarily")
        }
    }

    // MARK: - Background & Border

    private var bannerBackground: some View {
        Rectangle()
            .fill(.regularMaterial)
            .background(
                LinearGradient(
                    colors: [
                        VerificationColors.warningBg,
                        VerificationColors.warningBg.opacity(0.5)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }

    private var bannerBorder: some View {
        Rectangle()
            .fill(VerificationColors.warning.opacity(0.3))
            .frame(height: 2)
    }

    // MARK: - Actions

    private func handleVerifyTap() {

        let haptic = UIImpactFeedbackGenerator(style: .medium)
        haptic.impactOccurred()

        showVerificationView = true

        notificationStrategy.userEngaged()
    }

    private func handleDismiss() {

        let haptic = UIImpactFeedbackGenerator(style: .light)
        haptic.impactOccurred()

        withAnimation(BannerAnimations.slideOut) {
            isDismissed = true
        }

        notificationStrategy.userDismissedBanner()
    }

    // MARK: - Animation & Timers

    private func startAnimation() {
        withAnimation(.easeInOut(duration: 0.6).delay(0.2)) {
            isAnimating = true
        }
    }

    private func startMessageRotation() {
        messageRotationTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.4)) {
                messageIndex += 1
            }
        }
    }

    private func stopTimers() {
        messageRotationTimer?.invalidate()
        messageRotationTimer = nil
    }
}

// MARK: - Supporting Types

struct VerificationColors {
    static let warning = Color.orange
    static let warningBg = Color.orange.opacity(0.12)
    static let success = Color.green
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
}

struct BannerAnimations {
    static let slideIn = Animation.spring(response: 0.6, dampingFraction: 0.8)
    static let slideOut = Animation.easeInOut(duration: 0.3)
    static let pulseNotification = Animation.easeInOut(duration: 1.5).repeatCount(3)
}

struct BannerMessages {
    static let rotatingMessages = [
        "Verify your email to secure your account 🔒",
        "Quick email verification = Better experience ⚡",
        "Protect your scans with email verification 📱",
        "One click verification, unlimited features 🚀"
    ]

    static func contextualMessage(scanCount: Int) -> String {
        switch scanCount {
        case 0...5:
            return "Get started! Verify your email for full features 🎯"
        case 6...20:
            return "Great work! Secure your \(scanCount) scans with verification 📊"
        case 21...50:
            return "You're productive! Protect your \(scanCount) scans 🔐"
        default:
            return "Power user! \(scanCount) scans deserve cloud backup 🚀"
        }
    }
}

struct CompactButtonStyle: ButtonStyle {
    enum Style {
        case primary, secondary
    }

    let style: Style

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
            )
            .foregroundColor(foregroundColor)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return VerificationColors.warning
        case .secondary:
            return Color.gray.opacity(0.2)
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return .primary
        }
    }
}

class NotificationStrategy: ObservableObject {
    @Published var canShowBanner = true

    private let userDefaults = UserDefaults.standard
    private let lastShownKey = "emailBanner_lastShown"
    private let dismissCountKey = "emailBanner_dismissCount"
    private let engagementCountKey = "emailBanner_engagementCount"

    // MARK: - Smart Frequency Algorithm

    func shouldShowBanner() -> Bool {
        let lastShown = userDefaults.object(forKey: lastShownKey) as? Date ?? Date.distantPast
        let dismissCount = userDefaults.integer(forKey: dismissCountKey)
        let engagementCount = userDefaults.integer(forKey: engagementCountKey)

        let baseInterval = calculateBaseInterval(dismissCount: dismissCount)
        let adjustedInterval = adjustForEngagement(
            baseInterval: baseInterval,
            engagementCount: engagementCount
        )

        let timeSinceLastShown = Date().timeIntervalSince(lastShown)
        let shouldShow = timeSinceLastShown > adjustedInterval

        if shouldShow {
            userDefaults.set(Date(), forKey: lastShownKey)
        }

        return shouldShow
    }

    private func calculateBaseInterval(dismissCount: Int) -> TimeInterval {
        switch dismissCount {
        case 0: return 0
        case 1: return 3600
        case 2: return 3600 * 6
        case 3: return 3600 * 24
        case 4: return 3600 * 72
        default: return 3600 * 168
        }
    }

    private func adjustForEngagement(baseInterval: TimeInterval, engagementCount: Int) -> TimeInterval {

        let engagementFactor = max(0.3, 1.0 - Double(engagementCount) * 0.1)
        return baseInterval * engagementFactor
    }

    func userDismissedBanner() {
        let currentCount = userDefaults.integer(forKey: dismissCountKey)
        userDefaults.set(currentCount + 1, forKey: dismissCountKey)
    }

    func userEngaged() {
        let currentCount = userDefaults.integer(forKey: engagementCountKey)
        userDefaults.set(currentCount + 1, forKey: engagementCountKey)
    }

    // MARK: - Analytics Data

    var analyticsData: [String: Any] {
        return [
            "dismissCount": userDefaults.integer(forKey: dismissCountKey),
            "engagementCount": userDefaults.integer(forKey: engagementCountKey),
            "lastShown": userDefaults.object(forKey: lastShownKey) as? Date ?? Date.distantPast
        ]
    }
}

// MARK: - Sheet extension

extension EmailVerificationBanner {
    private var verificationSheet: some View {
        NavigationStack {
            EmailVerificationView()
                .environmentObject(firebaseManager)
                .navigationTitle("Verify Email")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showVerificationView = false
                        }
                    }
                }
        }
    }
}

// MARK: - Preview

#Preview {
    EmailVerificationBanner()
        .environmentObject(FirebaseManager.shared)
}
