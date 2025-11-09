//
//  CloudSyncSettingsView.swift
//  ShelfTagSnap
//
//  Created by Claude on 2025-11-03.
//  Milestone 2: Cloud Sync Settings
//

import SwiftUI

/// Cloud sync settings view
struct CloudSyncSettingsView: View {
    // MARK: - State Objects

    @StateObject private var cloudSyncService = CloudSyncService.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared

    // MARK: - State

    @State private var uploadStats: (total: Int, uploaded: Int, pending: Int)?
    @State private var isLoadingStats: Bool = false
    @State private var showClearStatsAlert: Bool = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                // Network status section
                networkStatusSection

                // Sync settings section
                syncSettingsSection

                // Upload statistics section
                uploadStatisticsSection

                // Actions section
                actionsSection
            }
            .navigationTitle("Cloud Sync")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadStatistics()
            }
            .refreshable {
                await loadStatistics()
            }
            .alert("Clear Statistics", isPresented: $showClearStatsAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    clearStatistics()
                }
            } message: {
                Text("This will reset upload statistics. This action cannot be undone.")
            }
        }
    }

    // MARK: - Network Status Section

    private var networkStatusSection: some View {
        Section {
            HStack(spacing: 12) {
                // Network icon
                Image(systemName: networkStatusIcon)
                    .font(.title2)
                    .foregroundColor(networkStatusColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Network Status")
                        .font(.body)
                        .fontWeight(.medium)

                    Text(networkStatusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Status badge
                Text(networkBadgeText)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(networkStatusColor)
                    )
            }
            .padding(.vertical, 4)

            // Upload capability
            HStack {
                Image(systemName: "arrow.up.circle")
                    .foregroundColor(canUploadNow ? .green : .orange)

                Text("Can upload now")
                    .font(.subheadline)

                Spacer()

                if canUploadNow {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.orange)
                }
            }
        } header: {
            Text("Connection")
        } footer: {
            if !canUploadNow && networkMonitor.isConnected {
                if cloudSyncService.uploadMode == .wifiOnly && networkMonitor.isUsingCellular {
                    Text("Upload is disabled because you're on cellular and WiFi-only mode is enabled")
                        .font(.caption)
                } else if cloudSyncService.uploadMode == .manual {
                    Text("Manual upload mode: tap 'Upload Pending Records' to sync")
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Sync Settings Section

    private var syncSettingsSection: some View {
        Section {
            // Upload mode picker
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: cloudSyncService.uploadMode.systemImage)
                        .font(.title3)
                        .foregroundColor(.blue)
                        .frame(width: 32)

                    Text("Upload Mode")
                        .font(.body)
                }

                // Segmented Picker for 3 modes
                Picker("Upload Mode", selection: $cloudSyncService.uploadMode) {
                    ForEach(UploadNetworkMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                // Description text for current mode
                Text(cloudSyncService.uploadMode.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            .padding(.vertical, 8)
        } header: {
            Text("Upload Settings")
        } footer: {
            if cloudSyncService.uploadMode == .anyNetwork {
                Text("⚠️ Using cellular data may incur additional charges from your carrier")
                    .font(.caption)
            } else if cloudSyncService.uploadMode == .wifiOnly {
                Text("Uploads will only occur when connected to WiFi")
                    .font(.caption)
            } else {
                Text("Records will be stored locally. Tap 'Upload' to manually sync to cloud")
                    .font(.caption)
            }
        }
    }

    // MARK: - Upload Statistics Section

    private var uploadStatisticsSection: some View {
        Section {
            if isLoadingStats {
                HStack {
                    Spacer()
                    ProgressView()
                    Text("Loading statistics...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else if let stats = uploadStats {
                // Total records
                HStack {
                    Label("Total Records", systemImage: "doc.on.doc")
                    Spacer()
                    Text("\(stats.total)")
                        .foregroundColor(.secondary)
                        .fontWeight(.semibold)
                }

                // Uploaded count
                HStack {
                    Label("Uploaded", systemImage: "checkmark.icloud.fill")
                        .foregroundColor(.green)
                    Spacer()
                    Text("\(stats.uploaded)")
                        .foregroundColor(.secondary)
                        .fontWeight(.semibold)
                }

                // Pending count
                HStack {
                    Label("Pending", systemImage: "clock")
                        .foregroundColor(.orange)
                    Spacer()
                    Text("\(stats.pending)")
                        .foregroundColor(.secondary)
                        .fontWeight(.semibold)
                }

                // Success rate
                HStack {
                    Label("Success Rate", systemImage: "chart.line.uptrend.xyaxis")
                    Spacer()
                    Text(String(format: "%.1f%%", cloudSyncService.statistics.successRate * 100))
                        .foregroundColor(.secondary)
                        .fontWeight(.semibold)
                }

                // Last upload
                if let lastUpload = cloudSyncService.statistics.lastUploadDate {
                    HStack {
                        Label("Last Upload", systemImage: "clock.arrow.circlepath")
                        Spacer()
                        Text(lastUpload, style: .relative)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("No statistics available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Statistics")
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        Section {
            // Upload pending records now
            Button {
                Task {
                    await uploadPendingRecords()
                }
            } label: {
                HStack {
                    Image(systemName: "icloud.and.arrow.up")
                        .foregroundColor(.blue)
                    Text("Upload Pending Records")
                    Spacer()
                    if cloudSyncService.isUploading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .disabled(!canUploadNow || cloudSyncService.isUploading || (uploadStats?.pending ?? 0) == 0)

            // Clear statistics
            Button(role: .destructive) {
                showClearStatsAlert = true
            } label: {
                Label("Clear Statistics", systemImage: "trash")
            }
        } header: {
            Text("Actions")
        }
    }

    // MARK: - Computed Properties

    private var networkStatusIcon: String {
        if !networkMonitor.isConnected {
            return "wifi.slash"
        } else if networkMonitor.isUsingCellular {
            return "antenna.radiowaves.left.and.right"
        } else {
            return "wifi"
        }
    }

    private var networkStatusColor: Color {
        if !networkMonitor.isConnected {
            return .red
        } else if networkMonitor.isUsingCellular {
            return .orange
        } else {
            return .green
        }
    }

    private var networkStatusText: String {
        if !networkMonitor.isConnected {
            return "No internet connection"
        } else if networkMonitor.isUsingCellular {
            return "Connected via cellular"
        } else {
            return "Connected via WiFi"
        }
    }

    private var networkBadgeText: String {
        if !networkMonitor.isConnected {
            return "Offline"
        } else if networkMonitor.isUsingCellular {
            return "Cellular"
        } else {
            return "WiFi"
        }
    }

    private var canUploadNow: Bool {
        // In manual mode, check network connection (user can manually upload)
        // In auto modes, check if auto-upload is allowed
        if cloudSyncService.uploadMode == .manual {
            return networkMonitor.isConnected
        } else {
            return cloudSyncService.canUploadNow()
        }
    }

    // MARK: - Helper Methods

    private func loadStatistics() async {
        isLoadingStats = true
        do {
            let stats = try await RecordStorageService.shared.getUploadStatistics()
            await MainActor.run {
                uploadStats = stats
                isLoadingStats = false
            }
        } catch {
            print("❌ [CloudSyncSettings] Failed to load statistics: \(error)")
            await MainActor.run {
                isLoadingStats = false
            }
        }
    }

    private func uploadPendingRecords() async {
        do {
            let pendingRecords = try await RecordStorageService.shared.getPendingUploadRecords()
            guard !pendingRecords.isEmpty else { return }

            let result = await cloudSyncService.batchUploadRecords(pendingRecords)
            print("✅ [CloudSyncSettings] Batch upload completed: \(result.success) success, \(result.failed) failed")

            // Reload statistics
            await loadStatistics()
        } catch {
            print("❌ [CloudSyncSettings] Failed to get pending records: \(error)")
        }
    }

    private func clearStatistics() {
        // Reset statistics in CloudSyncService
        cloudSyncService.statistics = UploadStatistics()

        // Refresh display
        Task {
            await loadStatistics()
        }
    }
}

// MARK: - Preview

#Preview {
    CloudSyncSettingsView()
}
