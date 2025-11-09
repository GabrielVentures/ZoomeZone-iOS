//
//  CloudSyncService.swift
//  ShelfTagSnap
//
//  Created by Claude on 2025-11-03.
//  Milestone 2: Cloud Sync Core Service
//

import Foundation
import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when upload batch completes (success or failure)
    static let cloudUploadCompleted = Notification.Name("CloudUploadCompleted")
}

// MARK: - Upload Network Mode

/// Upload network mode setting
enum UploadNetworkMode: String, Codable, CaseIterable {
    case anyNetwork = "any"     // Over Any Network (WiFi + Cellular)
    case wifiOnly = "wifi"       // Over Wi-Fi Only
    case manual = "manual"       // Manual Upload Only (no auto upload)

    var displayName: String {
        switch self {
        case .anyNetwork:
            return "Over Any Network"
        case .wifiOnly:
            return "Over Wi-Fi Only"
        case .manual:
            return "Manual Upload"
        }
    }

    var description: String {
        switch self {
        case .anyNetwork:
            return "Uploads will occur automatically over WiFi or cellular"
        case .wifiOnly:
            return "Uploads will only occur when connected to WiFi"
        case .manual:
            return "You must manually upload each record"
        }
    }

    var systemImage: String {
        switch self {
        case .anyNetwork:
            return "antenna.radiowaves.left.and.right"
        case .wifiOnly:
            return "wifi"
        case .manual:
            return "hand.tap"
        }
    }
}

/// Cloud synchronization service for uploading scan records to Firebase
/// Handles upload queue, network monitoring, and statistics tracking
@MainActor
class CloudSyncService: ObservableObject {
    // MARK: - Singleton

    static let shared = CloudSyncService()

    // MARK: - Published Properties

    /// Whether currently uploading
    @Published var isUploading: Bool = false

    /// Current upload progress (0.0 - 1.0)
    @Published var uploadProgress: Double = 0.0

    /// Upload statistics
    @Published var statistics: UploadStatistics = UploadStatistics()

    // MARK: - Configuration (AppStorage)

    /// Upload network mode (replaces autoUploadEnabled + cellularAllowed)
    @AppStorage("cloudSync.uploadMode")
    var uploadMode: UploadNetworkMode = .wifiOnly

    // MARK: - Dependencies

    private let auth = Auth.auth()
    private let firestore = Firestore.firestore()
    private let storage = Storage.storage()
    private let networkMonitor = NetworkMonitor.shared
    private let uploadCoordinator = UploadCoordinator.shared  // ✅ FIX P0-7: Actor-based coordination

    // MARK: - Private Properties

    /// Combine cancellables for network monitoring
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        loadStatistics()
        setupNetworkListener()  // ✅ FIX P0-4: Add network listener
        print("☁️ [CloudSyncService] Initialized")
    }

    // MARK: - Public Methods

    /// Upload a single record to cloud
    /// - Parameter record: The scan record to upload
    /// - Returns: Result of upload operation
    func uploadRecord(_ record: ScanRecord) async throws {
        // ✅ FIX P0-7: Use actor for thread-safe upload state check
        guard await uploadCoordinator.startUploading(record.id) else {
            print("☁️ [CloudSyncService] Record \(record.id) already uploading, skipping")
            return
        }
        defer {
            Task {
                await uploadCoordinator.finishUploading(record.id)
            }
        }

        print("📤 [CloudSyncService] uploadRecord called for: \(record.id)")
        print("   - Merchant: \(record.merchant)")
        print("   - Barcode: \(record.barcode)")
        print("   - Image: \(record.imageFilename)")

        // Validate user authentication
        guard let user = auth.currentUser else {
            print("❌ [CloudSyncService] User not authenticated!")
            throw CloudSyncError.notAuthenticated
        }
        print("✅ [CloudSyncService] User authenticated: \(user.uid)")

        // Check network permission
        let canUpload = canUploadNow()
        print("🌐 [CloudSyncService] Network check - Can upload: \(canUpload)")
        print("   - Network connected: \(networkMonitor.isConnected)")
        print("   - Upload mode: \(uploadMode.displayName)")
        print("   - Using cellular: \(networkMonitor.isUsingCellular)")

        guard canUpload else {
            print("❌ [CloudSyncService] Cannot upload now - network unavailable or not allowed")
            throw CloudSyncError.networkUnavailable
        }

        isUploading = true
        defer { isUploading = false }

        // ✅ FIX P1-9: Track uploaded image URL for rollback
        var uploadedImageURL: String?
        var uploadedImagePath: String?

        do {
            print("☁️ [CloudSyncService] Starting upload for record: \(record.id)")

            // Step 1: Load and compress image
            uploadProgress = 0.1
            let imageData = try await loadAndCompressImage(filename: record.imageFilename)

            // Step 2: Upload image to Storage
            uploadProgress = 0.3
            let (imageURL, storagePath) = try await uploadImageToStorage(
                imageData: imageData,
                userId: user.uid,
                filename: record.imageFilename
            )
            // ✅ FIX P1-9: Track for potential rollback
            uploadedImageURL = imageURL
            uploadedImagePath = storagePath

            // Step 3: Upload record data to Firestore
            uploadProgress = 0.7
            try await uploadRecordToFirestore(
                record: record,
                imageURL: imageURL,
                userId: user.uid
            )

            // Step 4: Update local record status
            uploadProgress = 0.9
            try await RecordStorageService.shared.updateUploadStatus(
                recordId: record.id,
                isUploaded: true,
                uploadedAt: Date()
            )

            // Step 5: Update statistics
            await updateStatistics(success: true)
            uploadProgress = 1.0

            print("✅ [CloudSyncService] Successfully uploaded record: \(record.id)")

        } catch {
            print("❌ [CloudSyncService] Failed to upload record \(record.id): \(error)")

            // ✅ FIX P1-9: Rollback - delete orphaned image if Firestore/local update failed
            if let storagePath = uploadedImagePath {
                print("🔄 [CloudSyncService] Rolling back: deleting orphaned image at \(storagePath)")
                await cleanupOrphanedImage(storagePath: storagePath)
            }

            await updateStatistics(success: false)
            throw error
        }
    }

    /// Batch upload multiple records
    /// - Parameter records: Array of scan records to upload
    /// - Returns: Tuple of (success count, failed count)
    func batchUploadRecords(_ records: [ScanRecord]) async -> (success: Int, failed: Int) {
        print("☁️ [CloudSyncService] Starting batch upload of \(records.count) records")

        var successCount = 0
        var failedCount = 0

        for record in records {
            do {
                try await uploadRecord(record)
                successCount += 1
            } catch {
                print("❌ [CloudSyncService] Failed to upload record: \(error)")
                failedCount += 1
            }
        }

        print("✅ [CloudSyncService] Batch upload completed: \(successCount) success, \(failedCount) failed")

        // Post notification if any records were uploaded successfully
        if successCount > 0 {
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .cloudUploadCompleted,
                    object: nil,
                    userInfo: ["successCount": successCount, "failedCount": failedCount]
                )
            }
        }

        return (successCount, failedCount)
    }

    /// Add record to upload queue
    /// - Parameter record: The scan record to queue
    func addToQueue(_ record: ScanRecord) async {
        // ✅ FIX P0-7: Use actor for thread-safe queue operations
        guard await uploadCoordinator.enqueue(record.id) else {
            print("☁️ [CloudSyncService] Record already in queue: \(record.id)")
            return
        }

        let queueSize = await uploadCoordinator.queueSize()
        print("☁️ [CloudSyncService] Added record to queue: \(record.id). Queue size: \(queueSize)")

        // Process queue if auto-upload mode and network available
        // canUploadNow() already checks uploadMode != .manual
        if canUploadNow() {
            await processUploadQueue()
        }
    }

    /// Process upload queue
    func processUploadQueue() async {
        guard !isUploading else {
            print("☁️ [CloudSyncService] Already uploading, skipping queue processing")
            return
        }

        // ✅ FIX P0-7: Use actor for thread-safe queue check
        guard await !uploadCoordinator.isEmpty() else {
            print("☁️ [CloudSyncService] Upload queue is empty")
            return
        }

        let queueSize = await uploadCoordinator.queueSize()
        print("☁️ [CloudSyncService] Processing upload queue with \(queueSize) items")

        // Process queue one by one, only remove on success
        while await !uploadCoordinator.isEmpty() {
            guard let recordId = await uploadCoordinator.peekNext() else {
                break
            }

            // Fetch record from database
            guard let record = await fetchRecord(byId: recordId) else {
                print("⚠️ [CloudSyncService] Record not found: \(recordId), removing from queue")
                await uploadCoordinator.dequeue(recordId)
                continue
            }

            // Skip if already uploaded
            if record.uploadStatus.isSynced {
                print("✅ [CloudSyncService] Record already uploaded: \(recordId), removing from queue")
                await uploadCoordinator.dequeue(recordId)
                continue
            }

            // Try to upload
            do {
                try await uploadRecord(record)
                // ✅ Success - remove from queue
                await uploadCoordinator.dequeue(recordId)
                print("✅ [CloudSyncService] Successfully uploaded and removed from queue: \(recordId)")
            } catch {
                print("❌ [CloudSyncService] Upload failed for \(recordId): \(error)")
                // ⚠️ Keep in queue for retry
                break  // Stop processing to avoid rapid retries
            }
        }
    }

    /// Fetch record from database by ID
    private func fetchRecord(byId recordId: String) async -> ScanRecord? {
        do {
            let records = try await RecordStorageService.shared.getPendingUploadRecords()
            return records.first { $0.id == recordId }
        } catch {
            print("❌ [CloudSyncService] Failed to fetch record \(recordId): \(error)")
            return nil
        }
    }

    /// Retry failed records
    /// - Parameter records: Array of failed scan records
    /// - Returns: Tuple of (success count, failed count)
    func retryFailedRecords(_ records: [ScanRecord]) async -> (success: Int, failed: Int) {
        print("☁️ [CloudSyncService] Retrying \(records.count) failed records")
        return await batchUploadRecords(records)
    }

    /// Check if can upload now based on network status and settings
    /// - Returns: Whether upload is allowed
    func canUploadNow() -> Bool {
        // Manual mode never auto-uploads
        guard uploadMode != .manual else {
            #if DEBUG
            print("☁️ [CloudSyncService] Manual mode - no auto upload")
            #endif
            return false
        }

        // Check network permission based on mode
        let allowed: Bool
        switch uploadMode {
        case .anyNetwork:
            allowed = networkMonitor.canUpload(allowWiFi: true, allowCellular: true)
        case .wifiOnly:
            allowed = networkMonitor.canUpload(allowWiFi: true, allowCellular: false)
        case .manual:
            allowed = false  // Already handled above
        }

        #if DEBUG
        print("☁️ [CloudSyncService] Can upload now: \(allowed)")
        print("   Network connected: \(networkMonitor.isConnected)")
        print("   Upload mode: \(uploadMode.displayName)")
        #endif

        return allowed
    }

    // MARK: - Private Methods

    /// Load and compress image from local storage
    /// ✅ FIX P1-10: Validate image file exists before loading
    private func loadAndCompressImage(filename: String) async throws -> Data {
        print("📸 [CloudSyncService] Loading image: \(filename)")

        // ✅ FIX P1-10: Validate image file exists
        guard LocalStorageService.shared.imageExists(filename: filename) else {
            print("❌ [CloudSyncService] Image file not found: \(filename)")
            throw CloudSyncError.imageNotFound
        }

        // Load image from local storage
        let image = try LocalStorageService.shared.loadImage(filename: filename)

        // ✅ FIX P1-10: Validate image was loaded successfully
        guard let imageData = try? compressImage(image) else {
            print("❌ [CloudSyncService] Failed to compress image: \(filename)")
            throw CloudSyncError.imageCompressionFailed
        }

        print("📸 [CloudSyncService] Image loaded and compressed: \(filename), size: \(imageData.count / 1024)KB")
        return imageData
    }

    /// Compress image to reduce upload size
    private func compressImage(_ image: UIImage) throws -> Data {
        let maxSize = 1 * 1024 * 1024 // 1MB target

        // Try original size first
        if let originalData = image.jpegData(compressionQuality: 0.8),
           originalData.count <= maxSize {
            print("📸 [CloudSyncService] No compression needed: \(originalData.count / 1024)KB")
            return originalData
        }

        // Progressive compression
        var compressionQuality: CGFloat = 0.8
        var compressedData = image.jpegData(compressionQuality: compressionQuality)

        while let data = compressedData,
              data.count > maxSize && compressionQuality > 0.1 {
            compressionQuality -= 0.1
            compressedData = image.jpegData(compressionQuality: compressionQuality)
        }

        guard let finalData = compressedData else {
            throw CloudSyncError.imageCompressionFailed
        }

        print("📸 [CloudSyncService] Compressed to \(finalData.count / 1024)KB at quality \(compressionQuality)")
        return finalData
    }

    /// Upload image to Firebase Storage
    /// ✅ FIX P1-9: Returns both download URL and storage path for rollback
    private func uploadImageToStorage(
        imageData: Data,
        userId: String,
        filename: String
    ) async throws -> (downloadURL: String, storagePath: String) {
        print("📤 [CloudSyncService] Uploading image to Storage: \(filename)")

        // Storage path: users/{userId}/images/{filename}
        let storagePath = "users/\(userId)/images/\(filename)"
        let storageRef = storage.reference().child(storagePath)

        // Set metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        // Upload
        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)

        // Get download URL
        let downloadURL = try await storageRef.downloadURL()

        print("✅ [CloudSyncService] Image uploaded successfully")
        return (downloadURL.absoluteString, storagePath)
    }

    /// Cleanup orphaned image from Firebase Storage
    /// ✅ FIX P1-9: Delete image when transaction fails
    private func cleanupOrphanedImage(storagePath: String) async {
        do {
            let storageRef = storage.reference().child(storagePath)
            try await storageRef.delete()
            print("✅ [CloudSyncService] Deleted orphaned image: \(storagePath)")
        } catch {
            print("⚠️ [CloudSyncService] Failed to delete orphaned image \(storagePath): \(error)")
            // Don't throw - cleanup is best-effort
        }
    }

    /// Upload record data to Firestore
    private func uploadRecordToFirestore(
        record: ScanRecord,
        imageURL: String,
        userId: String
    ) async throws {
        print("📤 [CloudSyncService] Uploading record to Firestore: \(record.id)")

        // Prepare Firestore document data
        var docData: [String: Any] = [
            "Scan_ID": record.id,
            "Username": record.username,
            "Timestamp": Timestamp(date: record.timestamp),
            "Upload_Timestamp": Timestamp(date: Date()),
            "User_ID": userId,
            "Merchant": record.merchant,
            "Barcode": record.barcode,
            "Image_Filename": record.imageFilename,
            "Image_URL": imageURL,
            "ai_processed": false
        ]

        // Add optional fields if they exist
        if let latitude = record.latitude {
            docData["Latitude"] = latitude
        }
        if let longitude = record.longitude {
            docData["Longitude"] = longitude
        }
        if let storeLocation = record.storeLocation {
            docData["Store_Location"] = storeLocation
        }

        // Write to Firestore
        try await firestore
            .collection("scan_records")
            .document(record.id)
            .setData(docData)

        print("✅ [CloudSyncService] Record uploaded to Firestore successfully")
    }

    /// Update upload statistics
    private func updateStatistics(success: Bool) async {
        if success {
            statistics.totalUploaded += 1
        } else {
            statistics.totalFailed += 1
        }

        statistics.lastUploadDate = Date()
        statistics.successRate = statistics.totalUploaded > 0 ?
            Double(statistics.totalUploaded) / Double(statistics.totalUploaded + statistics.totalFailed) :
            0.0

        saveStatistics()
    }

    /// Load statistics from UserDefaults
    private func loadStatistics() {
        if let data = UserDefaults.standard.data(forKey: "cloudSync.statistics"),
           let stats = try? JSONDecoder().decode(UploadStatistics.self, from: data) {
            statistics = stats
            print("☁️ [CloudSyncService] Loaded statistics: \(stats.totalUploaded) uploaded, \(stats.totalFailed) failed")
        }
    }

    /// Save statistics to UserDefaults
    private func saveStatistics() {
        if let data = try? JSONEncoder().encode(statistics) {
            UserDefaults.standard.set(data, forKey: "cloudSync.statistics")
        }
    }

    // MARK: - Network Monitoring (Milestone 2 - Fix P0-4 & P0-7)

    /// Setup network state change listener
    /// Automatically processes upload queue when network becomes available
    private func setupNetworkListener() {
        networkMonitor.$isConnected
            .dropFirst()  // Skip initial value
            .sink { [weak self] isConnected in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }

                    if isConnected {
                        print("🌐 [CloudSyncService] Network connected, checking queue...")

                        // ✅ FIX P0-7: Use actor for thread-safe queue check
                        let hasQueuedItems = await !self.uploadCoordinator.isEmpty()

                        // Check if we can upload now
                        if self.canUploadNow() && hasQueuedItems {
                            print("☁️ [CloudSyncService] Auto-processing queue after network restore")
                            await self.processUploadQueue()
                        }
                    } else {
                        print("🌐 [CloudSyncService] Network disconnected")
                    }
                }
            }
            .store(in: &cancellables)

        print("✅ [CloudSyncService] Network listener configured")
    }
}

// MARK: - Upload Statistics

struct UploadStatistics: Codable {
    var totalUploaded: Int = 0
    var totalFailed: Int = 0
    var successRate: Double = 0.0
    var lastUploadDate: Date? = nil
}

// MARK: - Cloud Sync Error

enum CloudSyncError: LocalizedError {
    case notAuthenticated
    case networkUnavailable
    case imageNotFound
    case imageCompressionFailed
    case uploadFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated. Please login first."
        case .networkUnavailable:
            return "Network unavailable. Please check your connection."
        case .imageNotFound:
            return "Image file not found in local storage."
        case .imageCompressionFailed:
            return "Failed to compress image."
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        }
    }
}
