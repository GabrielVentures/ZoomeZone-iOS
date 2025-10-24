//
//  StoreSelectionView.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//

import SwiftUI

/// Store selection view with autocomplete and validation
struct StoreSelectionView: View {
    // MARK: - Properties

    let task: TaskType

    // MARK: - Environment

    @EnvironmentObject private var permissionManager: PermissionManager
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var searchText: String = ""
    @State private var selectedStore: Store?
    @State private var showValidationError: Bool = false
    @State private var showCameraWithStore: Store?
    @FocusState private var isSearchFieldFocused: Bool

    // MARK: - Hot Stores

    private let hotStores: [Store] = [
        Store.allStores.first { $0.name == "99 Cents Only Stores" }!,
        Store.allStores.first { $0.name == "7-Eleven" }!,
        Store.allStores.first { $0.name == "Walmart" }!
    ]

    // MARK: - Computed Properties

    private var filteredStores: [Store] {
        Store.searchStores(query: searchText)
    }

    private var groupedFilteredStores: [String: [Store]] {
        Dictionary(grouping: filteredStores) { $0.category }
    }

    private var sortedCategories: [String] {
        let categories = Set(filteredStores.map { $0.category })
        return categories.sorted { category1, category2 in
            if category1 == "#" { return true }
            if category2 == "#" { return false }
            return category1 < category2
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Main content
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        HStack(spacing: 12) {
                            Image(systemName: "storefront")
                                .font(.system(size: 44))
                                .foregroundColor(.blue)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Current Store")
                                    .font(.title2)
                                    .fontWeight(.semibold)

                                Text("Please select the store you're currently in:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Store input field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("STORE")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)

                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 16))

                                TextField("Search store", text: $searchText)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .font(.body)
                                    .focused($isSearchFieldFocused)
                                    .onChange(of: searchText) { _, newValue in
                                        showValidationError = false
                                        if let store = Store.allStores.first(where: { $0.name == newValue }) {
                                            selectedStore = store
                                        } else {
                                            selectedStore = nil
                                        }
                                    }

                                if !searchText.isEmpty {
                                    Button(action: {
                                        searchText = ""
                                        selectedStore = nil
                                        showValidationError = false
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(12)
                            .background(Color(UIColor.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(showValidationError ? Color.red : Color(UIColor.separator), lineWidth: 1)
                            )

                            // Validation error message
                            if showValidationError {
                                Text("Store not found.")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.top, 4)
                            }
                        }

                        // Hot stores chips
                        if searchText.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("POPULAR STORES")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(hotStores) { store in
                                            Button(action: {
                                                searchText = store.name
                                                selectedStore = store
                                                isSearchFieldFocused = false
                                            }) {
                                                Text(store.name)
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.blue)
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 8)
                                                    .background(Color.blue.opacity(0.1))
                                                    .cornerRadius(16)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Store list
                        VStack(alignment: .leading, spacing: 0) {
                            if filteredStores.isEmpty {
                                // No matches state
                                VStack(spacing: 12) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 48))
                                        .foregroundColor(.secondary.opacity(0.5))

                                    Text("No matches for \"\(searchText)\"")
                                        .font(.headline)
                                        .foregroundColor(.secondary)

                                    Text("Please select from the available stores")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary.opacity(0.7))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 60)
                            } else {
                                // Alphabetically grouped list
                                ForEach(sortedCategories, id: \.self) { category in
                                    Section {
                                        VStack(spacing: 0) {
                                            ForEach(groupedFilteredStores[category] ?? []) { store in
                                                Button(action: {
                                                    searchText = store.name
                                                    selectedStore = store
                                                    showValidationError = false
                                                    isSearchFieldFocused = false
                                                }) {
                                                    HStack {
                                                        Text(store.name)
                                                            .font(.body)
                                                            .foregroundColor(.primary)
                                                            .frame(maxWidth: .infinity, alignment: .leading)

                                                        if selectedStore?.id == store.id {
                                                            Image(systemName: "checkmark")
                                                                .foregroundColor(.blue)
                                                                .font(.system(size: 16, weight: .semibold))
                                                        }
                                                    }
                                                    .padding(.vertical, 12)
                                                    .padding(.horizontal, 16)
                                                    .background(selectedStore?.id == store.id ? Color.blue.opacity(0.08) : Color.clear)
                                                    .contentShape(Rectangle())
                                                }
                                                .buttonStyle(PlainButtonStyle())

                                                if store.id != (groupedFilteredStores[category] ?? []).last?.id {
                                                    Divider()
                                                        .padding(.leading, 16)
                                                }
                                            }
                                        }
                                    } header: {
                                        HStack {
                                            Text(category)
                                                .font(.headline)
                                                .fontWeight(.bold)
                                                .foregroundColor(.secondary)
                                                .padding(.vertical, 8)
                                                .padding(.horizontal, 16)
                                            Spacer()
                                        }
                                        .background(Color(UIColor.systemGroupedBackground))
                                        .id(category)
                                    }
                                }
                            }
                        }
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(12)

                        Spacer(minLength: 40)
                    }
                    .padding(24)
                }
                .overlay(alignment: .trailing) {
                    // Letter index
                    if !filteredStores.isEmpty && searchText.isEmpty {
                        LetterIndexView(categories: sortedCategories) { category in
                            withAnimation {
                                proxy.scrollTo(category, anchor: .top)
                            }
                        }
                        .padding(.trailing, 8)
                    }
                }
            }

            // Select Store button (fixed at bottom)
            VStack(spacing: 0) {
                Divider()

                Button(action: validateAndProceed) {
                    Text("Select Store")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(selectedStore == nil ? Color.blue.opacity(0.5) : Color.blue)
                        .cornerRadius(12)
                }
                .disabled(selectedStore == nil)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .background(Color(UIColor.systemBackground))
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $showCameraWithStore) { store in
            CameraModalView(
                task: task,
                storeName: store.name,
                permissionManager: permissionManager
            )
        }
    }

    // MARK: - Methods

    private func validateAndProceed() {
        if let store = selectedStore {
            showCameraWithStore = store
        } else if !searchText.isEmpty {
            showValidationError = true
        }
    }
}

// MARK: - Letter Index View

struct LetterIndexView: View {
    let categories: [String]
    let onTap: (String) -> Void

    var body: some View {
        VStack(spacing: 2) {
            ForEach(categories, id: \.self) { category in
                Button(action: {
                    onTap(category)
                    HapticFeedbackManager.shared.light()
                }) {
                    Text(category)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .frame(width: 20, height: 16)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        StoreSelectionView(task: .shelfTagSnap)
            .environmentObject(PermissionManager.shared)
    }
}
