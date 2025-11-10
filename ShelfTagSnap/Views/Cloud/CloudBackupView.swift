//
//  CloudBackupView.swift
//  ShelfTagSnap
//
//  Created by Claude on 2025-11-03.
//  Milestone 2: Cloud Backup Main View
//

import SwiftUI
import Kingfisher

/// Cloud backup main view (Cloud Tab)
struct CloudBackupView: View {
    // MARK: - State Objects

    @StateObject private var viewModel = CloudBackupViewModel()

    // MARK: - State

    @State private var selectedRecord: CloudScanRecord?
    @State private var searchText: String = ""

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Main content
                mainContent

                // Error message
                if let errorMessage = viewModel.errorMessage {
                    VStack {
                        Spacer()
                        MessageView.error(errorMessage) {
                            viewModel.clearError()
                        }
                        .padding()
                        Spacer().frame(height: 100)
                    }
                }
            }
            .navigationTitle("Cloud Backup")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search records...")
            .task {
                await viewModel.loadRecords()
            }
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(item: $selectedRecord) { record in
                CloudRecordDetailView(record: record)
            }
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        switch viewModel.loadState {
        case .idle, .loading:
            loadingView

        case .loaded:
            if viewModel.isEmpty {
                emptyView
            } else {
                recordsList
            }

        case .error(let message):
            errorView(message)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        CloudListSkeleton(itemCount: 8)
            .background(Color(.systemGroupedBackground))
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 24) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 80))
                .foregroundColor(.secondary.opacity(0.5))

            VStack(spacing: 12) {
                Text("No Cloud Records")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Scan items to upload them to the cloud")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Failed to Load")
                .font(.title2)
                .fontWeight(.bold)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                Task {
                    await viewModel.loadRecords()
                }
            } label: {
                Text("Retry")
                    .font(.body)
                    .fontWeight(.semibold)
                    .frame(width: 200, height: 44)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Records List

    private var recordsList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: []) {
                // Statistics card
                statisticsCard
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                // Records
                let filtered = searchText.isEmpty ? viewModel.records : viewModel.search(keyword: searchText)

                if filtered.isEmpty {
                    // No search results
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No results found")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ForEach(filtered) { record in
                        CloudRecordRow(record: record)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .onTapGesture {
                                selectedRecord = record
                            }
                    }

                    // Load more indicator
                    if viewModel.hasMoreRecords {
                        HStack {
                            Spacer()
                            if viewModel.isLoadingMore {
                                ProgressView()
                            } else {
                                Text("Load more")
                                    .foregroundColor(.blue)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        .onAppear {
                            Task {
                                await viewModel.loadMoreRecords()
                            }
                        }
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Statistics Card

    private var statisticsCard: some View {
        let stats = viewModel.getStatistics()

        return VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cloud Records")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("\(stats.total) total records")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "icloud.fill")
                    .font(.title)
                    .foregroundColor(.blue)
            }

            Divider()

            HStack(spacing: 20) {
                // AI Completed
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("\(stats.aiCompleted)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }

                    Text("Completed")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // AI Processing
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("\(stats.aiPending)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }

                    Text("Processing")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // AI Failed
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                        Text("\(stats.aiFailed)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }

                    Text("Failed")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Cloud Record Row

struct CloudRecordRow: View {
    let record: CloudScanRecord

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail - ✅ Using Kingfisher for image caching with disk cache
            KFImage(URL(string: record.imageUrl))
                .placeholder {
                    ProgressView()
                        .frame(width: 70, height: 70)
                }
                .onFailure { error in
                    print("❌ [Kingfisher] Failed to load image for record \(record.id): \(error)")
                }
                .retry(maxCount: 3, interval: .seconds(1))
                .fade(duration: 0.25)
                .resizable()
                .scaledToFill()
                .frame(width: 70, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            // Information
            VStack(alignment: .leading, spacing: 6) {
                // SKU and Store Location
                HStack(spacing: 8) {
                    // SKU (Shelf Tag ID)
                    HStack(spacing: 4) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.caption2)
                            .foregroundColor(.blue)

                        Text("SKU:")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text(record.displayBarcode)
                            .font(.caption)
                            .fontDesign(.monospaced)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }

                    // Store Location (only if not unknown/walmart)
                    if let storeLocation = record.storeLocation,
                       !storeLocation.isEmpty,
                       !storeLocation.lowercased().contains("unknown"),
                       !storeLocation.lowercased().contains("walmart") {
                        Text("|")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        HStack(spacing: 2) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Text(storeLocation)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                // AI Result preview (Product Title)
                if let aiResult = record.aiResult, let title = aiResult.title {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.purple)
                        .lineLimit(1)
                }

                // Upload time
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text(record.deviceDate, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // AI Status badge
            aiStatusBadge
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private var aiStatusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: record.aiStatus.icon)
                .font(.caption)

            if record.aiStatus == .completed, let confidence = record.aiResult?.confidence {
                Text(String(format: "%.0f%%", 1.1))
                    .font(.caption2)
                    .fontWeight(.medium)
            }
        }
        .foregroundColor(Color(record.aiStatus.color))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color(record.aiStatus.color).opacity(0.15))
        )
    }
}

// MARK: - Message View Helper

extension MessageView {
    static func error(_ message: String, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)

            Spacer()

            Button(action: action) {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.red)
        .cornerRadius(12)
        .shadow(radius: 5)
    }
}

// MARK: - Preview

#Preview("Empty State") {
    CloudBackupView()
}

#Preview("With Records") {
    let view = CloudBackupView()
    return view
}
