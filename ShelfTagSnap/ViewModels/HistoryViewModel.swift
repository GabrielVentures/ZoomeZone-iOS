//
//  HistoryViewModel.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//

import Foundation
import SwiftUI
import Combine

/// ViewModel /// Scan history view model managing history records
@MainActor
class HistoryViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Load state
    @Published var loadState: LoadState = .idle

    /// Scan records list
    @Published var records: [ScanRecord] = []

    /// Filtered records
    @Published var filteredRecords: [ScanRecord] = []

    /// Search query
    @Published var searchQuery: String = ""

    /// Is refreshing
    @Published var isRefreshing: Bool = false

    /// Error message
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let storageService: LocalStorageService
    private let firebaseManager: FirebaseManager

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Load State

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)

        var isLoading: Bool {
            if case .loading = self {
                return true
            }
            return false
        }

        static func == (lhs: LoadState, rhs: LoadState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle),
                 (.loading, .loading),
                 (.loaded, .loaded):
                return true
            case (.error(let lhsMsg), .error(let rhsMsg)):
                return lhsMsg == rhsMsg
            default:
                return false
            }
        }
    }

    // MARK: - Computed Properties

    /// Total count of records
    var totalCount: Int {
        return filteredRecords.count
    }

    /// Is empty
    var isEmpty: Bool {
        return filteredRecords.isEmpty
    }

    // MARK: - Initialization

    init(
        storageService: LocalStorageService = .shared,
        firebaseManager: FirebaseManager = .shared
    ) {
        self.storageService = storageService
        self.firebaseManager = firebaseManager

        setupSearchObserver()
    }

    // MARK: - Setup

    /// Setup search observer
    private func setupSearchObserver() {
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] query in
                self?.filterRecords(query: query)
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Loading

    /// Load scan records
    func loadRecords() async {
        loadState = .loading

        do {
            // Load all records
            var allRecords = try storageService.loadRecords()

            // Filter by current user
            if let currentUser = firebaseManager.currentUser {
                allRecords = allRecords.filter { $0.username == currentUser.username }
            }

            // Sort by time descending
            allRecords.sort { $0.timestamp > $1.timestamp }

            records = allRecords
            filteredRecords = allRecords

            loadState = .loaded

        } catch {
            let errorMsg = "加载记录失败 / Failed to load records: \(error.localizedDescription)"
            errorMessage = errorMsg
            loadState = .error(errorMsg)
        }
    }

    /// Refresh records
    func refresh() async {
        isRefreshing = true
        await loadRecords()
        isRefreshing = false
    }

    // MARK: - Search and Filter

    /// Filter records
    private func filterRecords(query: String) {
        if query.isEmpty {
            filteredRecords = records
        } else {
            filteredRecords = records.filter { record in
                // Search in barcode, merchant, store location
                record.barcode.localizedCaseInsensitiveContains(query) ||
                record.merchant.localizedCaseInsensitiveContains(query) ||
                (record.storeLocation?.localizedCaseInsensitiveContains(query) ?? false)
            }
        }
    }

    // MARK: - Record Management

    /// Delete single record
    /// Delete a single record
    /// - Parameter record: The record to delete
    func deleteRecord(_ record: ScanRecord) async {
        do {
            // Remove from list
            records.removeAll { $0.id == record.id }
            filteredRecords.removeAll { $0.id == record.id }

            // Save updated list
            try storageService.saveRecords(records)

            // Delete associated image
            try? storageService.deleteImage(filename: record.imageFilename)

        } catch {
            errorMessage = "删除失败 / Delete failed: \(error.localizedDescription)"
        }
    }

    /// Batch delete records
    /// Delete multiple records
    /// - Parameter recordIds: Array of record IDs to delete
    func deleteRecords(_ recordIds: [String]) async {
        do {
            // Collect image filenames to delete
            let imagesToDelete = records.filter { recordIds.contains($0.id) }.map { $0.imageFilename }

            // Remove from list
            records.removeAll { recordIds.contains($0.id) }
            filteredRecords.removeAll { recordIds.contains($0.id) }

            // Save updated list
            try storageService.saveRecords(records)

            // Delete associated images
            for filename in imagesToDelete {
                try? storageService.deleteImage(filename: filename)
            }

        } catch {
            errorMessage = "批量删除失败 / Batch delete failed: \(error.localizedDescription)"
        }
    }

    /// Delete all records
    func deleteAllRecords() async {
        do {
            // Collect all image filenames
            let allImages = records.map { $0.imageFilename }

            // Clear lists
            records.removeAll()
            filteredRecords.removeAll()

            // Save empty list
            try storageService.saveRecords([])

            // Delete all images
            for filename in allImages {
                try? storageService.deleteImage(filename: filename)
            }

        } catch {
            errorMessage = "删除所有记录失败 / Delete all failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Helper Methods

    /// Get image for record
    /// Get image for a record
    /// - Parameter record: The record to get image for
    /// - Returns: UIImage or nil if not found
    func getImage(for record: ScanRecord) -> UIImage? {
        return try? storageService.loadImage(filename: record.imageFilename)
    }

    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
}
