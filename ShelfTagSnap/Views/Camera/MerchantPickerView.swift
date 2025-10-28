//
//  MerchantPickerView.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//

import SwiftUI

/// Merchant picker view
struct MerchantPickerView: View {
    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - Binding

    @Binding var selectedMerchant: Merchant?

    // MARK: - Properties

    let onSelect: (Merchant) -> Void

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // Title description
                    VStack(spacing: 8) {
                        Text("Select Merchant")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Select Merchant")
                            .font(.title3)
                            .foregroundColor(.secondary)

                        Text("Please select the merchant you scanned")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("Please select the merchant you scanned at")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 8)

                    // Merchant list
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(Merchant.allCases) { merchant in
                            MerchantCard(
                                merchant: merchant,
                                isSelected: selectedMerchant == merchant
                            ) {

                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()

                                selectedMerchant = merchant
                                onSelect(merchant)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Strings.Common.cancel) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Merchant Card

/// Merchant card
struct MerchantCard: View {
    let merchant: Merchant
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {

                // Icon
                Image(systemName: merchant.iconName)
                    .font(.system(size: 48))
                    .foregroundColor(isSelected ? .white : .blue)
                    .accessibilityHidden(true)

                // Merchant name
                Text(merchant.displayName)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue : Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .shadow(
                color: isSelected ? Color.blue.opacity(0.3) : Color.black.opacity(0.1),
                radius: isSelected ? 12 : 4,
                x: 0,
                y: isSelected ? 6 : 2
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .accessibilityLabel(merchant.displayName)
        .accessibilityValue(isSelected ? Strings.MerchantPicker.selected : Strings.MerchantPicker.notSelected)
        .accessibilityHint(Strings.MerchantPicker.selectHint)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Preview

#Preview {
    MerchantPickerView(
        selectedMerchant: .constant(.walmart),
        onSelect: { merchant in
            print("Selected: \(merchant.displayName)")
        }
    )
}
