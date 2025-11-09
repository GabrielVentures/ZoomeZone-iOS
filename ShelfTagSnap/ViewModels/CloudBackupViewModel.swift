//
//  CloudBackupViewModel.swift
//  ShelfTagSnap
//
//  Created by Claude on 2025-11-03.
//  Milestone 2: Cloud Backup ViewModel
//

import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine

/// Cloud backup view model for fetching and displaying cloud scan records
@MainActor
class CloudBackupViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Load state
    @Published var loadState: LoadState = .idle

    /// Cloud scan records
    @Published var records: [CloudScanRecord] = []

    /// Is refreshing
    @Published var isRefreshing: Bool = false

    /// Error message
    @Published var errorMessage: String?

    /// Pagination - Current page
    @Published var currentPage: Int = 0

    /// Pagination - Has more records to load
    @Published var hasMoreRecords: Bool = true

    /// Pagination - Is loading more records
    @Published var isLoadingMore: Bool = false

    // MARK: - Dependencies

    private let auth = Auth.auth()
    private let firestore = Firestore.firestore()

    // MARK: - Private Properties

    /// Last document snapshot (for pagination)
    private var lastDocumentSnapshot: DocumentSnapshot?

    /// Page size for pagination
    private let pageSize: Int = 20

    /// Cancellables
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        // Listen for upload completion notifications
        NotificationCenter.default.publisher(for: .cloudUploadCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self else { return }

                if let successCount = notification.userInfo?["successCount"] as? Int {
                    print("📱 [CloudBackupVM] Received upload completion: \(successCount) records uploaded")

                    // Auto-refresh Cloud page data
                    Task { @MainActor in
                        await self.refresh()
                    }
                }
            }
            .store(in: &cancellables)
    }

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
        return records.count
    }

    /// Is empty (no records at all)
    var isEmpty: Bool {
        return records.isEmpty
    }

    /// Grouped records by AI processing status
    var groupedByAIStatus: [(status: AIProcessingStatus, records: [CloudScanRecord])] {
        let groups = Dictionary(grouping: records) { $0.aiStatus }
        return groups.map { (status: $0.key, records: $0.value) }
            .sorted { group1, group2 in
                // Sort order: completed, pending, failed
                let order: [AIProcessingStatus] = [.completed, .pending, .failed]
                return order.firstIndex(of: group1.status)! < order.firstIndex(of: group2.status)!
            }
    }

    // MARK: - Data Loading

    /// Load initial records (first page)
    func loadRecords() async {
        loadState = .loading
        currentPage = 0
        hasMoreRecords = true
        lastDocumentSnapshot = nil

        do {
            guard let userId = auth.currentUser?.uid else {
                throw CloudBackupError.notAuthenticated
            }

            print("☁️ [CloudBackupVM] Loading first page for user: \(userId)")

            // Query Firestore
            let query = firestore
                .collection("scan_records")
                .whereField("User_ID", isEqualTo: userId)
                .order(by: "Upload_Timestamp", descending: true)
                .limit(to: pageSize)

            let snapshot = try await query.getDocuments()

            // Parse documents
            let cloudRecords = try parseDocuments(snapshot.documents)

            records = cloudRecords
            lastDocumentSnapshot = snapshot.documents.last
            hasMoreRecords = snapshot.documents.count >= pageSize

            loadState = .loaded

            print("✅ [CloudBackupVM] Loaded \(cloudRecords.count) records")

        } catch {
            let errorMsg = "Failed to load cloud records: \(error.localizedDescription)"
            errorMessage = errorMsg
            loadState = .error(errorMsg)
            print("❌ [CloudBackupVM] Load error: \(error)")
        }
    }

    /// Load more records (next page)
    func loadMoreRecords() async {
        guard !isLoadingMore && hasMoreRecords else { return }
        guard let lastSnapshot = lastDocumentSnapshot else { return }

        isLoadingMore = true

        do {
            guard let userId = auth.currentUser?.uid else {
                throw CloudBackupError.notAuthenticated
            }

            print("☁️ [CloudBackupVM] Loading more records (page \(currentPage + 1))")

            // Query Firestore with pagination
            let query = firestore
                .collection("scan_records")
                .whereField("User_ID", isEqualTo: userId)
                .order(by: "Upload_Timestamp", descending: true)
                .start(afterDocument: lastSnapshot)
                .limit(to: pageSize)

            let snapshot = try await query.getDocuments()

            // Parse documents
            let newRecords = try parseDocuments(snapshot.documents)

            records.append(contentsOf: newRecords)
            lastDocumentSnapshot = snapshot.documents.last
            hasMoreRecords = snapshot.documents.count >= pageSize
            currentPage += 1

            print("✅ [CloudBackupVM] Loaded \(newRecords.count) more records. Total: \(records.count)")

        } catch {
            errorMessage = "Failed to load more records: \(error.localizedDescription)"
            print("❌ [CloudBackupVM] Load more error: \(error)")
        }

        isLoadingMore = false
    }

    /// Refresh records
    func refresh() async {
        isRefreshing = true
        await loadRecords()
        isRefreshing = false
    }

    // MARK: - Helper Methods

    /// Parse Firestore documents into CloudScanRecord models
    private func parseDocuments(_ documents: [QueryDocumentSnapshot]) throws -> [CloudScanRecord] {
        return try documents.compactMap { doc in
            do {
                let record = try doc.data(as: CloudScanRecord.self)
                return record
            } catch {
                print("⚠️ [CloudBackupVM] Failed to decode document \(doc.documentID): \(error)")
                // Return nil for failed documents instead of throwing
                return nil
            }
        }
    }

    /// Clear error message
    func clearError() {
        errorMessage = nil
    }

    /// Delete a cloud record (admin function, use with caution)
    func deleteRecord(_ record: CloudScanRecord) async throws {
        guard let recordId = record.id else {
            throw CloudBackupError.invalidRecordId
        }

        print("☁️ [CloudBackupVM] Deleting cloud record: \(recordId)")

        // Delete from Firestore
        try await firestore
            .collection("scan_records")
            .document(recordId)
            .delete()

        // Remove from local list
        records.removeAll { $0.id == recordId }

        print("✅ [CloudBackupVM] Deleted cloud record: \(recordId)")
    }

    /// Retry AI processing for a record (trigger Cloud Function)
    func retryAIProcessing(_ record: CloudScanRecord) async throws {
        guard let recordId = record.id else {
            throw CloudBackupError.invalidRecordId
        }

        print("☁️ [CloudBackupVM] Retrying AI processing for record: \(recordId)")

        // Reset AI processing fields
        try await firestore
            .collection("scan_records")
            .document(recordId)
            .updateData([
                "ai_processed": false,
                "ai_error": FieldValue.delete(),
                "AI_Result": FieldValue.delete()
            ])

        // Refresh to get updated status
        await refresh()

        print("✅ [CloudBackupVM] Triggered AI retry for record: \(recordId)")
    }

    /// Filter records by AI status
    func filterByAIStatus(_ status: AIProcessingStatus) -> [CloudScanRecord] {
        return records.filter { $0.aiStatus == status }
    }

    /// Search records by keyword
    func search(keyword: String) -> [CloudScanRecord] {
        if keyword.isEmpty {
            return records
        }

        return records.filter { record in
            record.barcode.localizedCaseInsensitiveContains(keyword) ||
            record.merchant.localizedCaseInsensitiveContains(keyword) ||
            (record.storeLocation?.localizedCaseInsensitiveContains(keyword) ?? false) ||
            (record.aiResult?.title?.localizedCaseInsensitiveContains(keyword) ?? false)
        }
    }

    /// Get statistics
    func getStatistics() -> (total: Int, aiCompleted: Int, aiPending: Int, aiFailed: Int) {
        let completed = records.filter { $0.aiStatus == .completed }.count
        let pending = records.filter { $0.aiStatus == .pending }.count
        let failed = records.filter { $0.aiStatus == .failed }.count

        return (total: records.count, aiCompleted: completed, aiPending: pending, aiFailed: failed)
    }
}

// MARK: - Cloud Backup Error

enum CloudBackupError: LocalizedError {
    case notAuthenticated
    case invalidRecordId
    case firestoreError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated. Please login first."
        case .invalidRecordId:
            return "Invalid record ID."
        case .firestoreError(let message):
            return "Firestore error: \(message)"
        }
    }
}

// MARK: - Preview Helper

#if DEBUG
extension CloudBackupViewModel {
    /// Mock view model for preview
    static func mock() -> CloudBackupViewModel {
        let vm = CloudBackupViewModel()
        vm.records = [
            .sample,
            .samplePending,
            .sampleFailed
        ]
        vm.loadState = .loaded
        return vm
    }
}
#endif
