//
//  EmailVerificationStatusCard.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/24.

//

import SwiftUI

/// Email verification status display card
struct EmailVerificationStatusCard: View {
    @EnvironmentObject private var firebaseManager: FirebaseManager
    @State private var showVerificationView = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Status header
            HStack {
                statusIcon

                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle)
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text(firebaseManager.currentUser?.email ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                statusBadge
            }

            // Status description and actions
            if !firebaseManager.isEmailVerified {
                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Unlock additional features:")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    FeatureStatusGrid()
                        .environmentObject(firebaseManager)

                    Button("Verify Email Now") {
                        showVerificationView = true
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor, lineWidth: 1)
                )
        )
        .sheet(isPresented: $showVerificationView) {
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

    // MARK: - Computed Properties

    private var isVerified: Bool {
        firebaseManager.isEmailVerified
    }

    private var statusTitle: String {
        isVerified ? "Email Verified" : "Email Verification Required"
    }

    private var statusIcon: some View {
        Image(systemName: isVerified ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
            .font(.title2)
            .foregroundColor(isVerified ? .green : .orange)
    }

    private var statusBadge: some View {
        Text(isVerified ? "Verified" : "Pending")
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isVerified ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
            )
            .foregroundColor(isVerified ? .green : .orange)
    }

    private var backgroundColor: Color {
        isVerified ? Color.green.opacity(0.05) : Color.orange.opacity(0.05)
    }

    private var borderColor: Color {
        isVerified ? Color.green.opacity(0.2) : Color.orange.opacity(0.2)
    }
}

/// Feature status grid
struct FeatureStatusGrid: View {
    @EnvironmentObject private var firebaseManager: FirebaseManager

    private let features = [
        ("shield.checkered", "Account Security"),
        ("key.fill", "Password Management")

        // Following features are hidden but reserved
        // ("icloud.and.arrow.up", "Cloud Backup"),
        // ("devices", "Multi-device Access")
    ]

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 8) {
            ForEach(Array(features.enumerated()), id: \.offset) { _, feature in
                FeatureStatusRow(
                    icon: feature.0,
                    text: feature.1,
                    available: firebaseManager.isEmailVerified
                )
            }
        }
    }
}

/// Feature status row
struct FeatureStatusRow: View {
    let icon: String
    let text: String
    let available: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.caption)
                .foregroundColor(available ? .green : .gray)

            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(.caption)
                    .foregroundColor(available ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(available ? Color.green.opacity(0.05) : Color.gray.opacity(0.05))
        )
    }
}
