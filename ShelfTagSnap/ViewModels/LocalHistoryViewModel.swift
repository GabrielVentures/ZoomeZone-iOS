//
//  LocalHistoryViewModel.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//  Enhanced for Milestone 2 - Cloud Sync
//

import Foundation
import SwiftUI
import Combine

/// Upload status filter option
enum UploadStatusFilter: String, CaseIterable {
    case all = "All"
    case pending = "Pending"
    case uploaded = "Uploaded"

    var systemImage: String {
        switch self {
        case .all:
            return "doc.on.doc"
        case .pending:
            return "clock"
        case .uploaded:
            return "checkmark.icloud"
        }
    }
}

/// Local history view model managing local scan records
@MainActor
class LocalHistoryViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Load state
    @Published var loadState: LoadState = .idle

    /// Scan records list
    @Published var records: [ScanRecord] = []

    /// Filtered records
    @Published var filteredRecords: [ScanRecord] = []

    /// Search query
    @Published var searchQuery: String = ""

    /// Upload status filter (Milestone 2)
    @Published var uploadStatusFilter: UploadStatusFilter = .all

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

    /// Is uploading a record (Milestone 2)
    @Published var isUploading: Bool = false

    /// Page size for pagination
    private let pageSize: Int = 30

    // MARK: - Dependencies

    private let storageService: LocalStorageService  // Keep for images
    private let recordStorageService: RecordStorageService  // New SwiftData service
    private let firebaseManager: FirebaseManager
    private let cloudSyncService: CloudSyncService  // Milestone 2

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
        firebaseManager: FirebaseManager = .shared,
        cloudSyncService: CloudSyncService = .shared
    ) {
        self.storageService = storageService
        self.recordStorageService = recordStorageService
        self.firebaseManager = firebaseManager
        self.cloudSyncService = cloudSyncService

        setupObservers()
    }

    // MARK: - Setup

    /// Setup observers
    private func setupObservers() {
        // Search query observer
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyAllFilters()
            }
            .store(in: &cancellables)

        // Upload status filter observer (Milestone 2)
        $uploadStatusFilter
            .sink { [weak self] _ in
                self?.applyAllFilters()
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

            // Apply filters and pagination
            applyAllFilters()

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

    // MARK: - Filtering (Milestone 2 Enhanced)

    /// Apply all filters (search + upload status)
    private func applyAllFilters() {
        var filtered = records

        // 1. Apply upload status filter
        switch uploadStatusFilter {
        case .all:
            break // No filtering
        case .pending:
            filtered = filtered.filter { $0.uploadStatus == .pending || $0.uploadStatus == .failed }
        case .uploaded:
            filtered = filtered.filter { $0.uploadStatus == .synced }
        }

        // 2. Apply search filter
        if !searchQuery.isEmpty {
            filtered = filtered.filter { record in
                record.barcode.localizedCaseInsensitiveContains(searchQuery) ||
                record.merchant.localizedCaseInsensitiveContains(searchQuery) ||
                (record.storeLocation?.localizedCaseInsensitiveContains(searchQuery) ?? false)
            }
        }

        // 3. Apply pagination
        currentPage = 0
        let endIndex = min(pageSize, filtered.count)
        filteredRecords = Array(filtered.prefix(endIndex))
        hasMoreRecords = endIndex < filtered.count

        updateGroupedRecords(from: filteredRecords)
    }

    /// Apply pagination to records
    private func applyPagination() {
        var filtered = records

        // Apply upload status filter
        switch uploadStatusFilter {
        case .all:
            break
        case .pending:
            filtered = filtered.filter { $0.uploadStatus == .pending || $0.uploadStatus == .failed }
        case .uploaded:
            filtered = filtered.filter { $0.uploadStatus == .synced }
        }

        // Apply search filter
        if !searchQuery.isEmpty {
            filtered = filtered.filter { record in
                record.barcode.localizedCaseInsensitiveContains(searchQuery) ||
                record.merchant.localizedCaseInsensitiveContains(searchQuery) ||
                (record.storeLocation?.localizedCaseInsensitiveContains(searchQuery) ?? false)
            }
        }

        let startIndex = 0
        let endIndex = min((currentPage + 1) * pageSize, filtered.count)

        filteredRecords = Array(filtered.prefix(endIndex))
        hasMoreRecords = endIndex < filtered.count

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

    // MARK: - Cloud Upload (Milestone 2)

    /// Manually upload a single record
    func uploadRecord(_ record: ScanRecord) async {
        guard !isUploading else {
            errorMessage = "Upload already in progress"
            return
        }

        guard record.uploadStatus != .synced else {
            errorMessage = "Record already uploaded"
            return
        }

        isUploading = true
        errorMessage = nil

        do {
            // Upload to cloud
            try await cloudSyncService.uploadRecord(record)

            // Reload records to reflect new status
            await loadRecords()

            // Show success message (optional)
            print("✅ [LocalHistoryVM] Successfully uploaded record: \(record.id)")

        } catch {
            errorMessage = "Upload failed: \(error.localizedDescription)"
            print("❌ [LocalHistoryVM] Upload failed: \(error)")
        }

        isUploading = false
    }

    // MARK: - Record Management

    /// Delete single record
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
            applyAllFilters()

        } catch {
            errorMessage = "Delete failed: \(error.localizedDescription)"
        }
    }

    /// Batch delete records
    func deleteRecords(_ recordIds: [String]) async {
        do {
            // Get records to delete
            let recordsToDelete = records.filter { recordIds.contains($0.id) }

            // Delete from SwiftData
            try await recordStorageService.deleteRecords(recordsToDelete)

            // Remove from local lists
            records.removeAll { recordIds.contains($0.id) }
            filteredRecords.removeAll { recordIds.contains($0.id) }

            // Recalculate
            calculateStatistics()
            calculateDailyStats()
            applyAllFilters()

        } catch {
            errorMessage = "Batch delete failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Image Management

    /// Get image for record
    func getImage(for record: ScanRecord) -> UIImage? {
        return recordStorageService.loadImage(for: record)
    }

    // MARK: - Group Management

    /// Toggle group expansion
    func toggleGroupExpansion(for groupId: String) {
        if let index = groupedRecords.firstIndex(where: { $0.id == groupId }) {
            groupedRecords[index].isExpanded.toggle()
        }
    }

    // MARK: - Statistics

    /// Calculate statistics
    private func calculateStatistics() {
        let calendar = Calendar.current
        let now = Date()

        // Today's count
        todayCount = records.filter { calendar.isDateInToday($0.timestamp) }.count

        // Week's count
        if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) {
            weekCount = records.filter { $0.timestamp >= weekAgo }.count
        }

        // Month's count
        if let monthAgo = calendar.date(byAdding: .day, value: -30, to: now) {
            monthCount = records.filter { $0.timestamp >= monthAgo }.count
        }

        // Top store
        let storeGroups = Dictionary(grouping: records) { $0.storeLocation ?? "Unknown" }
        if let topStoreEntry = storeGroups.max(by: { $0.value.count < $1.value.count }) {
            topStore = topStoreEntry.key
            topStoreCount = topStoreEntry.value.count
        }
    }

    /// Calculate daily statistics (last 14 days)
    /// Only includes dates that have at least one record
    private func calculateDailyStats() {
        let calendar = Calendar.current
        let now = Date()
        var stats: [DailyStats] = []

        for dayOffset in (0..<14).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { continue }

            let count = records.filter { $0.timestamp >= startOfDay && $0.timestamp < endOfDay }.count

            // ✅ FIX: Only append dates with at least one record
            if count > 0 {
                stats.append(DailyStats(date: startOfDay, count: count))
            }
        }

        dailyStats = stats
    }

    // MARK: - Error Handling

    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
}
