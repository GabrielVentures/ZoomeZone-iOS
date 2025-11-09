//
//  UploadCoordinator.swift
//  ShelfTagSnap
//
//  Created by Claude Code on 2025-11-08.
//  Fix P0-7: Thread-safe upload coordination using Swift Actor
//

import Foundation

/// Thread-safe upload coordinator using Swift Actor
/// Prevents race conditions in concurrent upload operations
actor UploadCoordinator {
    // MARK: - Singleton

    static let shared = UploadCoordinator()

    // MARK: - Private Properties

    /// Set of record IDs currently being uploaded
    private var uploadingRecordIds: Set<String> = []

    /// Upload queue (record IDs only)
    private var uploadQueue: [String] = []

    /// UserDefaults key for upload queue
    private let queueKey = "cloudSync.uploadQueue"

    /// UserDefaults key for uploading record IDs
    private let uploadingIdsKey = "cloudSync.uploadingIds"

    // MARK: - Initialization

    private init() {
        loadPersistedQueue()
        loadUploadingIds()
        print("🎭 [UploadCoordinator] Initialized with \(uploadQueue.count) queued, \(uploadingRecordIds.count) uploading")
    }

    // MARK: - Upload State Management

    /// Check if a record is currently being uploaded
    /// - Parameter recordId: The record ID to check
    /// - Returns: Whether the record is currently uploading
    func isUploading(_ recordId: String) -> Bool {
        return uploadingRecordIds.contains(recordId)
    }

    /// Mark a record as started uploading
    /// - Parameter recordId: The record ID
    /// - Returns: Whether the operation succeeded (false if already uploading)
    func startUploading(_ recordId: String) -> Bool {
        guard !uploadingRecordIds.contains(recordId) else {
            print("⚠️ [UploadCoordinator] Record \(recordId) already uploading")
            return false
        }

        uploadingRecordIds.insert(recordId)
        saveUploadingIds()
        print("📤 [UploadCoordinator] Started uploading: \(recordId)")
        return true
    }

    /// Mark a record as finished uploading
    /// - Parameter recordId: The record ID
    func finishUploading(_ recordId: String) {
        uploadingRecordIds.remove(recordId)
        saveUploadingIds()
        print("✅ [UploadCoordinator] Finished uploading: \(recordId)")
    }

    /// Clear all uploading states (called on app restart)
    func clearUploadingStates() {
        if !uploadingRecordIds.isEmpty {
            print("⚠️ [UploadCoordinator] Clearing \(uploadingRecordIds.count) interrupted uploads")
            uploadingRecordIds.removeAll()
            saveUploadingIds()
        }
    }

    // MARK: - Queue Management

    /// Add a record to the upload queue
    /// - Parameter recordId: The record ID to queue
    /// - Returns: Whether the record was added (false if already in queue)
    func enqueue(_ recordId: String) -> Bool {
        guard !uploadQueue.contains(recordId) else {
            print("⚠️ [UploadCoordinator] Record \(recordId) already in queue")
            return false
        }

        uploadQueue.append(recordId)
        savePersistedQueue()
        print("📋 [UploadCoordinator] Enqueued: \(recordId). Queue size: \(uploadQueue.count)")
        return true
    }

    /// Remove a record from the queue
    /// - Parameter recordId: The record ID to remove
    func dequeue(_ recordId: String) {
        uploadQueue.removeAll { $0 == recordId }
        savePersistedQueue()
        print("🗑️ [UploadCoordinator] Dequeued: \(recordId). Queue size: \(uploadQueue.count)")
    }

    /// Get the next record from the queue without removing it
    /// - Returns: The next record ID, or nil if queue is empty
    func peekNext() -> String? {
        return uploadQueue.first
    }

    /// Get current queue size
    /// - Returns: Number of records in queue
    func queueSize() -> Int {
        return uploadQueue.count
    }

    /// Get all queued record IDs
    /// - Returns: Array of record IDs in queue
    func getAllQueued() -> [String] {
        return uploadQueue
    }

    /// Check if queue is empty
    /// - Returns: Whether the queue is empty
    func isEmpty() -> Bool {
        return uploadQueue.isEmpty
    }

    // MARK: - Batch Operations

    /// Remove multiple records from queue
    /// - Parameter recordIds: Array of record IDs to remove
    func dequeueBatch(_ recordIds: [String]) {
        uploadQueue.removeAll { recordIds.contains($0) }
        savePersistedQueue()
        print("🗑️ [UploadCoordinator] Dequeued batch: \(recordIds.count) records")
    }

    // MARK: - Persistence

    /// Load persisted upload queue from UserDefaults
    private func loadPersistedQueue() {
        if let data = UserDefaults.standard.data(forKey: queueKey),
           let queue = try? JSONDecoder().decode([String].self, from: data) {
            uploadQueue = queue
            print("💾 [UploadCoordinator] Loaded \(queue.count) records from persisted queue")
        } else {
            uploadQueue = []
        }
    }

    /// Save upload queue to UserDefaults
    private func savePersistedQueue() {
        if let data = try? JSONEncoder().encode(uploadQueue) {
            UserDefaults.standard.set(data, forKey: queueKey)
        }
    }

    /// Load uploading record IDs from UserDefaults
    private func loadUploadingIds() {
        if let data = UserDefaults.standard.data(forKey: uploadingIdsKey),
           let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            uploadingRecordIds = ids
            print("💾 [UploadCoordinator] Loaded \(ids.count) uploading IDs from persistence")

            // Clear uploading IDs on app restart (they were likely interrupted)
            clearUploadingStates()
        } else {
            uploadingRecordIds = []
        }
    }

    /// Save uploading record IDs to UserDefaults
    private func saveUploadingIds() {
        if let data = try? JSONEncoder().encode(uploadingRecordIds) {
            UserDefaults.standard.set(data, forKey: uploadingIdsKey)
        }
    }
}
