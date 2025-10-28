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

    /// Statistics - Today's count
    @Published var todayCount: Int = 0

    /// Statistics - Week's count
    @Published var weekCount: Int = 0

    /// Statistics - Month's count
    @Published var monthCount: Int = 0

    /// Statistics - Top store name
    @Published var topStore: String = ""

    /// Statistics - Top store count
    @Published var topStoreCount: Int = 0

    /// Grouped records by date
    @Published var groupedRecords: [DateGroup] = []

    /// Daily statistics (last 14 days)
    @Published var dailyStats: [DailyStats] = []

    /// Pagination - Current page
    @Published var currentPage: Int = 0

    /// Pagination - Has more records to load
    @Published var hasMoreRecords: Bool = true

    /// Pagination - Is loading more records
    @Published var isLoadingMore: Bool = false

    /// Page size for pagination
    private let pageSize: Int = 30

    // MARK: - Dependencies

    private let storageService: LocalStorageService  // Keep for images
    private let recordStorageService: RecordStorageService  // New SwiftData service
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

    /// Is empty (no records at all, not filtered)
    var isEmpty: Bool {
        return records.isEmpty  // Check total records, not filtered
    }

    /// Has filtered results
    var hasFilteredResults: Bool {
        return !filteredRecords.isEmpty
    }

    // MARK: - Initialization

    init(
        storageService: LocalStorageService = .shared,
        recordStorageService: RecordStorageService = .shared,
        firebaseManager: FirebaseManager = .shared
    ) {
        self.storageService = storageService
        self.recordStorageService = recordStorageService
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

    /// Load initial records (first page)
    func loadRecords() async {
        loadState = .loading
        currentPage = 0
        hasMoreRecords = true

        do {
            guard let currentUser = firebaseManager.currentUser else {
                records = []
                filteredRecords = []
                loadState = .loaded
                return
            }

            // Load all records for statistics calculation
            let allRecords = try await recordStorageService.loadRecords(forUsername: currentUser.username)
            records = allRecords

            // Calculate statistics and daily stats
            calculateStatistics()
            calculateDailyStats()

            // Apply initial pagination (first 30 records)
            applyPagination()

            loadState = .loaded

        } catch {
            let errorMsg = "Failed to load records: \(error.localizedDescription)"
            errorMessage = errorMsg
            loadState = .error(errorMsg)
        }
    }

    /// Load more records (next page)
    func loadMoreRecords() async {
        guard !isLoadingMore && hasMoreRecords else { return }

        isLoadingMore = true
        currentPage += 1

        // Add delay to prevent UI jank
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

        applyPagination()

        isLoadingMore = false
    }

    /// Refresh records
    func refresh() async {
        isRefreshing = true
        await loadRecords()
        isRefreshing = false
    }

    // MARK: - Search and Pagination

    /// Filter records based on search query
    private func filterRecords(query: String) {
        if query.isEmpty {
            // No search - use all records
            applyPagination()
        } else {
            // Apply search filter
            filteredRecords = records.filter { record in
                record.barcode.localizedCaseInsensitiveContains(query) ||
                record.merchant.localizedCaseInsensitiveContains(query) ||
                (record.storeLocation?.localizedCaseInsensitiveContains(query) ?? false)
            }

            // Reset pagination when searching
            currentPage = 0
            hasMoreRecords = filteredRecords.count > pageSize

            // Update grouped records with search results
            updateGroupedRecords(from: Array(filteredRecords.prefix(pageSize)))
        }
    }

    /// Apply pagination to records
    private func applyPagination() {
        let startIndex = 0
        let endIndex = min((currentPage + 1) * pageSize, records.count)

        filteredRecords = Array(records.prefix(endIndex))
        hasMoreRecords = endIndex < records.count

        updateGroupedRecords(from: filteredRecords)
    }

    /// Update grouped records from filtered results
    private func updateGroupedRecords(from records: [ScanRecord]) {
        let calendar = Calendar.current

        let groupedDict = Dictionary(grouping: records) { record in
            calendar.startOfDay(for: record.timestamp)
        }

        groupedRecords = groupedDict
            .map { date, records in
                let isToday = calendar.isDateInToday(date)
                let isYesterday = calendar.isDateInYesterday(date)
                return DateGroup(
                    date: date,
                    records: records.sorted { $0.timestamp > $1.timestamp },
                    isExpanded: isToday || isYesterday
                )
            }
            .sorted { $0.date > $1.date }
    }

    // MARK: - Record Management

    /// Delete single record
    /// Delete a single record
    /// - Parameter record: The record to delete
    func deleteRecord(_ record: ScanRecord) async {
        do {
            // Delete from SwiftData (also deletes image)
            try await recordStorageService.deleteRecord(record)

            // Remove from local lists
            records.removeAll { $0.id == record.id }
            filteredRecords.removeAll { $0.id == record.id }

            // Recalculate statistics
            calculateStatistics()
            calculateDailyStats()
            applyPagination()

        } catch {
            errorMessage = "Delete failed: \(error.localizedDescription)"
        }
    }

    /// Batch delete records
    /// Delete multiple records
    /// - Parameter recordIds: Array of record IDs to delete
    func deleteRecords(_ recordIds: [String]) async {
        do {
            // Get records to delete
            let recordsToDelete = records.filter { recordIds.contains($0.id) }

            // Delete from SwiftData
            try await recordStorageService.deleteRecords(recordsToDelete)

            // Remove from local lists
            records.removeAll { recordIds.contains($0.id) }
            filteredRecords.removeAll { recordIds.contains($0.id) }

            // Recalculate statistics
            calculateStatistics()
            calculateDailyStats()
            applyPagination()

        } catch {
            errorMessage = "Batch delete failed: \(error.localizedDescription)"
        }
    }

    /// Delete all records
    func deleteAllRecords() async {
        do {
            guard let currentUser = firebaseManager.currentUser else {
                return
            }

            // Delete all from SwiftData
            try await recordStorageService.deleteAllRecords(forUsername: currentUser.username)

            // Clear lists
            records.removeAll()
            filteredRecords.removeAll()

            // Recalculate statistics
            calculateStatistics()
            calculateDailyStats()
            applyPagination()

        } catch {
            errorMessage = "Delete all failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Helper Methods

    /// Get image for record
    /// Get image for a record
    /// - Parameter record: The record to get image for
    /// - Returns: UIImage or nil if not found
    func getImage(for record: ScanRecord) -> UIImage? {
        return recordStorageService.loadImage(for: record)
    }

    /// Clear error message
    func clearError() {
        errorMessage = nil
    }

    // MARK: - Statistics

    /// Calculate statistics from records
    private func calculateStatistics() {
        let now = Date()
        let calendar = Calendar.current

        // Today's count
        todayCount = records.filter { calendar.isDateInToday($0.timestamp) }.count

        // Week's count (last 7 days)
        if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) {
            weekCount = records.filter { $0.timestamp >= weekAgo }.count
        } else {
            weekCount = 0
        }

        // Month's count (last 30 days)
        if let monthAgo = calendar.date(byAdding: .day, value: -30, to: now) {
            monthCount = records.filter { $0.timestamp >= monthAgo }.count
        } else {
            monthCount = 0
        }

        // Top store calculation
        let storeGroups = Dictionary(grouping: records) { record in
            record.storeLocation ?? "Unknown"
        }

        if let topStoreEntry = storeGroups.max(by: { $0.value.count < $1.value.count }) {
            topStore = topStoreEntry.key
            topStoreCount = topStoreEntry.value.count
        } else {
            topStore = ""
            topStoreCount = 0
        }
    }

    // MARK: - Daily Statistics

    /// Calculate daily statistics (only dates with scans)
    private func calculateDailyStats() {
        let calendar = Calendar.current

        // Group records by date
        let recordsByDate = Dictionary(grouping: records) { record in
            calendar.startOfDay(for: record.timestamp)
        }

        // Only include dates with scans (filter out 0 count)
        // Sort by date descending (most recent first)
        dailyStats = recordsByDate
            .map { date, records in
                DailyStats(date: date, count: records.count)
            }
            .sorted { $0.date > $1.date }
    }

    /// Toggle date group expansion
    func toggleGroupExpansion(for groupId: String) {
        if let index = groupedRecords.firstIndex(where: { $0.id == groupId }) {
            groupedRecords[index].isExpanded.toggle()
        }
    }
}
