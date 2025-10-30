//
//  HistoryListView.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//

import SwiftUI
import Combine

/// History layout mode

enum HistoryLayoutMode: String, CaseIterable, Identifiable {
    case compact      // Compact list
    case comfortable  // Comfortable list
    case gallery      // Gallery grid

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .compact:
            return "list.bullet"
        case .comfortable:
            return "list.bullet.rectangle.portrait"
        case .gallery:
            return "square.grid.2x2"
        }
    }

    var title: String {
        switch self {
        case .compact:
            return "Compact"
        case .comfortable:
            return "Comfortable"
        case .gallery:
            return "Gallery"
        }
    }
}

/// Scan history list view

struct HistoryListView: View {
    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - State Objects

    @StateObject private var viewModel = HistoryViewModel()

    // MARK: - State

    @State private var isSearching: Bool = false
    @State private var selectedRecord: ScanRecord?
    @State private var showDeleteAlert: Bool = false
    @State private var recordToDelete: ScanRecord?

    // Layout mode
    @AppStorage("historyLayoutMode") private var layoutModeRawValue: String = HistoryLayoutMode.compact.rawValue
    private var layoutMode: HistoryLayoutMode {
        get { HistoryLayoutMode(rawValue: layoutModeRawValue) ?? .compact }
        set { layoutModeRawValue = newValue.rawValue }
    }

    // Multi-select state
    @State private var isSelectionMode: Bool = false
    @State private var selectedRecords: Set<String> = []
    @State private var showDeleteSelectedAlert: Bool = false

    // Export-related state
    @State private var showExportPreview: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var exportedFileURL: URL?
    @State private var isExporting: Bool = false
    @State private var exportError: String?
    @State private var exportProgress: ExportProgress?

    // Date filter state
    @State private var isDateFilterExpanded: Bool = false

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

                // Export progress indicator
                if let progress = exportProgress {
                    ExportProgressView(progress: progress)
                }
            }
            .navigationTitle(isSelectionMode ? "\(selectedRecords.count) \(Strings.History.selected)" : Strings.History.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .task {
                await viewModel.loadRecords()
            }
            .refreshable {
                await viewModel.refresh()
            }
            .alert(Strings.History.deleteConfirmation, isPresented: $showDeleteAlert, presenting: recordToDelete) { record in
                Button(Strings.Common.cancel, role: .cancel) {}
                Button(Strings.Common.delete, role: .destructive) {
                    Task {
                        await viewModel.deleteRecord(record)
                    }
                }
            } message: { _ in
                Text(Strings.History.deleteMessage)
            }
            .alert(Strings.Export.deleteSelectedConfirmation, isPresented: $showDeleteSelectedAlert) {
                Button(Strings.Common.cancel, role: .cancel) {}
                Button(Strings.Common.delete, role: .destructive) {
                    Task {
                        await deleteSelectedRecords()
                    }
                }
            } message: {
                Text(String(format: Strings.Export.deleteSelectedMessage, selectedRecords.count))
            }
            .sheet(item: $selectedRecord) { record in
                ScanDetailView(record: record)
            }
            .sheet(isPresented: $showExportPreview) {
                exportPreviewSheet
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportedFileURL {
                    ShareSheet(items: [url])
                }
            }
            .alert(Strings.Export.exportError, isPresented: .constant(exportError != nil), presenting: exportError) { _ in
                Button(Strings.Common.ok) {
                    exportError = nil
                }
            } message: { error in
                Text(error)
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
                // No records at all - show empty state
                emptyView
            } else {
                // Has records - show list (even if filtered results are empty)
                recordsList
            }

        case .error(let message):
            errorView(message)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text(Strings.History.loadingRecords)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(Strings.History.loading)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        EmptyHistoryView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
                .accessibilityHidden(true)

            Text(Strings.History.failedToLoad)
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
                Text(Strings.History.retry)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Strings.History.failedToLoad)
        .accessibilityValue(message)
    }

    // MARK: - Records List

    private var recordsList: some View {
        ZStack(alignment: .bottom) {
            // Main content
            Group {
                switch layoutMode {
                case .compact, .comfortable:
                    listModeView
                case .gallery:
                    galleryModeView
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Reserve space for TabBar and floating toolbar in selection mode
                if isSelectionMode {
                    Color.clear.frame(height: 80)
                }
            }

            // Floating selection toolbar
            if isSelectionMode {
                SelectionToolbar(
                    selectedCount: selectedRecords.count,
                    totalCount: viewModel.filteredRecords.count,
                    onSelectAll: selectAll,
                    onDeselectAll: deselectAll,
                    onDelete: {
                        showDeleteSelectedAlert = true
                    },
                    onExport: {
                        showExportPreview = true
                    },
                    isExporting: isExporting
                )
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelectionMode)
    }

    // MARK: - List Mode View

    private var listModeView: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: []) {
                // Statistics card (fixed at top)
                StatisticsCardView(
                    dailyStats: viewModel.dailyStats,
                    totalCount: viewModel.dailyStats.reduce(0) { $0 + $1.count }
                )
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                // Content: records list grouped by date
                if viewModel.hasFilteredResults {
                    ForEach(viewModel.groupedRecords) { group in
                        VStack(spacing: 0) {
                            // Date section header
                            DateSectionHeader(dateGroup: group) {
                                viewModel.toggleGroupExpansion(for: group.id)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                            // Records in this date group (only show if expanded)
                            if group.isExpanded {
                                ForEach(group.records) { record in
                                    scrollRecordRow(for: record)
                                        .padding(.horizontal, 16)
                                        .padding(.top, 8)
                                }
                            }
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
                } else if !viewModel.searchQuery.isEmpty {
                    // No search results
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No results found for \"\(viewModel.searchQuery)\"")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Gallery Mode View

    private var galleryModeView: some View {
        ScrollView {
            LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
                // Statistics card (fixed at top)
                StatisticsCardView(
                    dailyStats: viewModel.dailyStats,
                    totalCount: viewModel.dailyStats.reduce(0) { $0 + $1.count }
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 4)

                // Content: pure waterfall grid (no day grouping)
                if viewModel.hasFilteredResults {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        ForEach(viewModel.filteredRecords) { record in
                            galleryGridItem(for: record)
                        }

                        // Load more indicator
                        if viewModel.hasMoreRecords {
                            Color.clear
                                .frame(height: 1)
                                .gridCellColumns(2)
                                .onAppear {
                                    Task {
                                        await viewModel.loadMoreRecords()
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 16)

                    // Loading more indicator
                    if viewModel.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.vertical, 16)
                    }
                } else if !viewModel.searchQuery.isEmpty {
                    // No search results
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No results found for \"\(viewModel.searchQuery)\"")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
        }
    }


    // MARK: - Date Grouped Records Section

    private var dateGroupedRecordsSection: some View {
        ForEach(viewModel.groupedRecords) { group in
            Section {
                // Date section header
                DateSectionHeader(dateGroup: group) {
                    viewModel.toggleGroupExpansion(for: group.id)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                // Records in this date group (only show if expanded)
                if group.isExpanded {
                    ForEach(group.records) { record in
                        recordRow(for: record)
                    }
                }
            }
        }
    }

    // MARK: - Record Row

    private func recordRow(for record: ScanRecord) -> some View {
        Group {
            if isSelectionMode {
                // Selection mode: Show checkbox
                Button {
                    toggleSelection(for: record)
                } label: {
                    HStack(spacing: 12) {
                        // Checkbox
                        Image(systemName: selectedRecords.contains(record.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedRecords.contains(record.id) ? .blue : .gray)
                            .font(.title3)
                            .accessibilityHidden(true)

                        HistoryRow(
                            record: record,
                            image: viewModel.getImage(for: record),
                            layoutMode: layoutMode
                        )
                    }
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // Normal mode: Tap to view details
                Button {
                    selectedRecord = record
                } label: {
                    HistoryRow(
                        record: record,
                        image: viewModel.getImage(for: record),
                        layoutMode: layoutMode
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        recordToDelete = record
                        showDeleteAlert = true
                    } label: {
                        Label(Strings.Common.delete, systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: - Scroll Record Row (for ScrollView layout)

    private func scrollRecordRow(for record: ScanRecord) -> some View {
        Group {
            if isSelectionMode {
                // Selection mode: Show checkbox
                Button {
                    toggleSelection(for: record)
                } label: {
                    HStack(spacing: 12) {
                        // Checkbox
                        Image(systemName: selectedRecords.contains(record.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedRecords.contains(record.id) ? .blue : .gray)
                            .font(.title3)
                            .accessibilityHidden(true)

                        HistoryRow(
                            record: record,
                            image: viewModel.getImage(for: record),
                            layoutMode: layoutMode
                        )
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // Normal mode: Tap to view details + context menu for delete
                Button {
                    selectedRecord = record
                } label: {
                    HistoryRow(
                        record: record,
                        image: viewModel.getImage(for: record),
                        layoutMode: layoutMode
                    )
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                .contextMenu {
                    Button(role: .destructive) {
                        recordToDelete = record
                        showDeleteAlert = true
                    } label: {
                        Label(Strings.Common.delete, systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: - Records Section (Old - Keep for reference)

    private var recordsSection: some View {
        Section {
            ForEach(viewModel.filteredRecords) { record in
                if isSelectionMode {

                    // Selection mode: Show checkbox
                    Button {
                        toggleSelection(for: record)
                    } label: {
                        HStack(spacing: 12) {

                            // Checkbox
                            Image(systemName: selectedRecords.contains(record.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedRecords.contains(record.id) ? .blue : .gray)
                                .font(.title3)
                                .accessibilityHidden(true)

                            HistoryRow(
                                record: record,
                                image: viewModel.getImage(for: record),
                                layoutMode: layoutMode
                            )
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {

                    // Normal mode: Tap to view details
                    Button {
                        selectedRecord = record
                    } label: {
                        HistoryRow(
                            record: record,
                            image: viewModel.getImage(for: record),
                            layoutMode: layoutMode
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            recordToDelete = record
                            showDeleteAlert = true
                        } label: {
                            Label(Strings.Common.delete, systemImage: "trash")
                        }
                    }
                }
            }
        } header: {
            if !viewModel.searchQuery.isEmpty {
                Text(Strings.History.searchResults)
            }
        }
    }

    // MARK: - Export Preview Sheet

    private var exportPreviewSheet: some View {
        let statistics = ExportStatistics.calculate(from: viewModel.filteredRecords)

        return ExportPreviewView(
            statistics: statistics,
            onConfirm: {
                Task {
                    await performExport()
                }
            },
            exportProgress: $exportProgress
        )
    }

    // MARK: - Gallery Grid Item

    /// Gallery grid item view

    private func galleryGridItem(for record: ScanRecord) -> some View {
        let isSelected = selectedRecords.contains(record.id)

        return Button {
            if isSelectionMode {
                toggleSelection(for: record)
            } else {
                selectedRecord = record
            }
        } label: {
            ZStack {
                // Main content
                ZStack(alignment: .bottom) {
                    // Image background

                    if let image = viewModel.getImage(for: record) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        // Placeholder

                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.title)
                                    .foregroundColor(.secondary)
                            )
                    }

                    // Barcode overlay

                    HStack(spacing: 4) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.caption2)
                        Text(record.barcode.prefix(10) + (record.barcode.count > 10 ? "..." : ""))
                            .font(.caption)
                            .fontDesign(.monospaced)
                            .lineLimit(1)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(8)
                }

                // Selection mode overlay
                if isSelectionMode {
                    // Semi-transparent overlay when selected
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.15))
                    }

                    // Checkmark in top-right corner
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isSelected ? .blue : .white)
                                .font(.title2)
                                .background(
                                    Circle()
                                        .fill(isSelected ? Color.white : Color.black.opacity(0.3))
                                        .frame(width: 24, height: 24)
                                )
                                .padding(8)
                        }
                        Spacer()
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected && isSelectionMode ? Color.blue : Color.clear, lineWidth: 3)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Scan record: \(record.barcode)")
    }

    // MARK: - Helper Methods

    /// Perform export

    private func performExport() async {
        isExporting = true
        exportError = nil

        // Get records to export (selected or all filtered)

        let recordsToExport: [ScanRecord]
        if isSelectionMode && !selectedRecords.isEmpty {
            recordsToExport = viewModel.filteredRecords.filter { selectedRecords.contains($0.id) }
        } else {
            recordsToExport = viewModel.filteredRecords
        }

        do {

            // Export as ZIP (with CSV and images)
            let exportManager = ExportManager.shared

            // Observe progress

            let progressTask = Task { @MainActor in
                for await _ in Timer.publish(every: 0.1, on: .main, in: .common).autoconnect().values {
                    exportProgress = exportManager.progress
                    if exportManager.progress == nil {
                        break
                    }
                }
            }

            let fileURL = try await exportManager.exportAsZIP(records: recordsToExport)
            exportedFileURL = fileURL

            // Cancel progress observation

            progressTask.cancel()
            exportProgress = nil

            // Exit selection mode if active

            if isSelectionMode {
                isSelectionMode = false
                selectedRecords.removeAll()
            }

            // Show share sheet (keep preview open until share sheet is ready)
            await MainActor.run {
                showShareSheet = true

                // Close preview after share sheet is shown
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showExportPreview = false
                }
            }
        } catch {
            exportProgress = nil
            await MainActor.run {
                showExportPreview = false
                exportError = error.localizedDescription
            }
        }

        isExporting = false
    }

    /// Toggle record selection
    private func toggleSelection(for record: ScanRecord) {
        if selectedRecords.contains(record.id) {
            selectedRecords.remove(record.id)
        } else {
            selectedRecords.insert(record.id)
        }
        HapticFeedbackManager.shared.light()
    }

    /// Select all
    private func selectAll() {
        selectedRecords = Set(viewModel.filteredRecords.map { $0.id })
        HapticFeedbackManager.shared.medium()
    }

    /// Deselect all
    private func deselectAll() {
        selectedRecords.removeAll()
        HapticFeedbackManager.shared.light()
    }

    /// Delete selected records
    private func deleteSelectedRecords() async {
        let recordsToDelete = viewModel.filteredRecords.filter { selectedRecords.contains($0.id) }
        for record in recordsToDelete {
            await viewModel.deleteRecord(record)
        }
        isSelectionMode = false
        selectedRecords.removeAll()
        HapticFeedbackManager.shared.success()
    }

    // MARK: - Toolbar

    private var toolbarContent: some ToolbarContent {
        Group {
            if isSelectionMode {

                // Selection mode toolbar
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(Strings.Common.cancel) {
                        isSelectionMode = false
                        selectedRecords.removeAll()
                    }
                }

                // Bottom toolbar removed - now using custom floating toolbar
            } else {
                // Normal mode toolbar

                // Layout switcher

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(HistoryLayoutMode.allCases) { mode in
                            Button {
                                layoutModeRawValue = mode.rawValue
                                HapticFeedbackManager.shared.light()
                            } label: {
                                Label(mode.title, systemImage: mode.icon)
                                if mode.rawValue == layoutModeRawValue {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    } label: {
                        Image(systemName: layoutMode.icon)
                    }
                    .accessibilityLabel("Change layout")
                }

                // Select button

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(Strings.History.select) {
                        isSelectionMode = true
                    }
                    .disabled(viewModel.isEmpty)
                }

                // Export button

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showExportPreview = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel(Strings.History.export)
                    .accessibilityHint(Strings.Export.exportWithImages)
                    .disabled(viewModel.isEmpty || isExporting)
                }
            }
        }
    }
}

// MARK: - Export Progress View

/// Export progress overlay

struct ExportProgressView: View {
    let progress: ExportProgress

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Progress circle

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 8)
                        .frame(width: 100, height: 100)

                    Circle()
                        .trim(from: 0, to: progress.percentage)
                        .stroke(Color.blue, lineWidth: 8)
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear, value: progress.percentage)

                    Text("\(Int(progress.percentage * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }

                VStack(spacing: 8) {
                    Text(progress.status)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("\(progress.currentItem) / \(progress.totalItems)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground).opacity(0.95))
            )
            .shadow(radius: 20)
        }
    }
}

// MARK: - Preview

#Preview("Empty") {
    HistoryListView()
        .environmentObject(FirebaseManager.shared)
}

#Preview("With Records") {
    let viewModel = HistoryViewModel()
    return HistoryListView()
        .environmentObject(FirebaseManager.shared)
}

#Preview("Loading") {
    HistoryListView()
        .environmentObject(FirebaseManager.shared)
}
