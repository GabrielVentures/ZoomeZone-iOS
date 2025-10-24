//
//  EmptyHistoryView.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//

import SwiftUI

/// Empty history view
struct EmptyHistoryView: View {
    // MARK: - Properties

    var onStartScan: (() -> Void)?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 80))
                .foregroundStyle(.gray.gradient)
                .accessibilityHidden(true)

            // Message text
            VStack(spacing: 12) {
                Text(Strings.History.noScanRecordsYet)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text(Strings.History.startScanningToCreate)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Strings.History.noScanRecordsYet)
            .accessibilityValue(Strings.History.startScanningToCreate)

            // Start scan button (if callback provided)
            if let onStartScan = onStartScan {
                Button(action: onStartScan) {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.viewfinder")
                            .font(.body.weight(.semibold))
                            .accessibilityHidden(true)

                        Text(Strings.Camera.startScanning)
                            .font(.body)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: 280)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                    )
                    .foregroundColor(.white)
                }
                .padding(.top, 16)
                .accessibilityLabel(Strings.Camera.startScanning)
                .accessibilityHint(Strings.History.switchToScanTab)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Preview

#Preview("Without Button") {
    EmptyHistoryView()
}

#Preview("With Button") {
    EmptyHistoryView {
        print("Start scanning")
    }
}

#Preview("In Navigation") {
    NavigationStack {
        EmptyHistoryView {
            print("Start scanning")
        }
        .navigationTitle(Strings.History.title)
    }
}
