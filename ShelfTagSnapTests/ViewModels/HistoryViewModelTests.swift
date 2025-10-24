//
//  HistoryViewModelTests.swift
//  ShelfTagSnapTests
//
//  Created by kent.sun on 2025/10/23.
//

import Testing
import Foundation
@testable import ShelfTagSnap

/// Unit tests for HistoryViewModel
@Suite("HistoryViewModel Tests")
struct HistoryViewModelTests {

    // MARK: - Initialization Tests

    @Test("ViewModel 初始化状态 / ViewModel initial state")
    @MainActor
    func testInitialState() async throws {
        let viewModel = HistoryViewModel()

        #expect(viewModel.loadState == .idle)
        #expect(viewModel.records.isEmpty)
        #expect(viewModel.filteredRecords.isEmpty)
        #expect(viewModel.searchQuery.isEmpty)
        #expect(viewModel.isRefreshing == false)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.totalCount == 0)
        #expect(viewModel.isEmpty == true)
    }

    // MARK: - LoadState Tests

    @Test("LoadState 相等性测试 / LoadState equality")
    func testLoadStateEquality() async throws {
        // idle
        #expect(HistoryViewModel.LoadState.idle == .idle)

        // loading
        #expect(HistoryViewModel.LoadState.loading == .loading)

        // loaded
        #expect(HistoryViewModel.LoadState.loaded == .loaded)

        // error
        #expect(HistoryViewModel.LoadState.error("test1") == .error("test1"))
        #expect(HistoryViewModel.LoadState.error("test1") != .error("test2"))

        // isLoading
        #expect(HistoryViewModel.LoadState.loading.isLoading == true)
        #expect(HistoryViewModel.LoadState.idle.isLoading == false)
        #expect(HistoryViewModel.LoadState.loaded.isLoading == false)
        #expect(HistoryViewModel.LoadState.error("test").isLoading == false)
    }

    // MARK: - Computed Properties Tests

    @Test("totalCount 计算 / totalCount calculation")
    @MainActor
    func testTotalCount() async throws {
        let viewModel = HistoryViewModel()

        #expect(viewModel.totalCount == 0)

        viewModel.filteredRecords = [
            createMockRecord(barcode: "111"),
            createMockRecord(barcode: "222"),
            createMockRecord(barcode: "333")
        ]

        #expect(viewModel.totalCount == 3)
    }

    @Test("isEmpty 计算 / isEmpty calculation")
    @MainActor
    func testIsEmpty() async throws {
        let viewModel = HistoryViewModel()

        #expect(viewModel.isEmpty == true)

        viewModel.filteredRecords = [createMockRecord()]

        #expect(viewModel.isEmpty == false)
    }

    // MARK: - Search Tests

    @Test("搜索过滤 - 条形码 / Search filter - barcode")
    @MainActor
    func testSearchFilterBarcode() async throws {
        let viewModel = HistoryViewModel()

        viewModel.records = [
            createMockRecord(barcode: "1234567890"),
            createMockRecord(barcode: "9876543210"),
            createMockRecord(barcode: "1111111111")
        ]
        viewModel.filteredRecords = viewModel.records

        viewModel.searchQuery = "123"

        try await Task.sleep(for: .milliseconds(400))

        #expect(viewModel.filteredRecords.count == 1)
        #expect(viewModel.filteredRecords.first?.barcode == "1234567890")
    }

    @Test("搜索过滤 - 商家 / Search filter - merchant")
    @MainActor
    func testSearchFilterMerchant() async throws {
        let viewModel = HistoryViewModel()

        viewModel.records = [
            createMockRecord(merchant: "walmart"),
            createMockRecord(merchant: "target"),
            createMockRecord(merchant: "costco")
        ]
        viewModel.filteredRecords = viewModel.records

        viewModel.searchQuery = "walmart"

        try await Task.sleep(for: .milliseconds(400))

        #expect(viewModel.filteredRecords.count == 1)
        #expect(viewModel.filteredRecords.first?.merchant == "walmart")
    }

    @Test("搜索过滤 - 门店位置 / Search filter - store location")
    @MainActor
    func testSearchFilterStoreLocation() async throws {
        let viewModel = HistoryViewModel()

        viewModel.records = [
            createMockRecord(storeLocation: "Floor 1"),
            createMockRecord(storeLocation: "Floor 2"),
            createMockRecord(storeLocation: nil)
        ]
        viewModel.filteredRecords = viewModel.records

        viewModel.searchQuery = "Floor 1"

        try await Task.sleep(for: .milliseconds(400))

        #expect(viewModel.filteredRecords.count == 1)
        #expect(viewModel.filteredRecords.first?.storeLocation == "Floor 1")
    }

    @Test("搜索过滤 - 空查询 / Search filter - empty query")
    @MainActor
    func testSearchFilterEmptyQuery() async throws {
        let viewModel = HistoryViewModel()

        viewModel.records = [
            createMockRecord(),
            createMockRecord(),
            createMockRecord()
        ]
        viewModel.filteredRecords = []

        viewModel.searchQuery = ""

        try await Task.sleep(for: .milliseconds(400))

        #expect(viewModel.filteredRecords.count == 3)
    }

    @Test("搜索过滤 - 大小写不敏感 / Search filter - case insensitive")
    @MainActor
    func testSearchFilterCaseInsensitive() async throws {
        let viewModel = HistoryViewModel()

        viewModel.records = [createMockRecord(merchant: "Walmart")]
        viewModel.filteredRecords = viewModel.records

        viewModel.searchQuery = "walmart"

        try await Task.sleep(for: .milliseconds(400))

        #expect(viewModel.filteredRecords.count == 1)
    }

    // MARK: - Error Handling Tests

    @Test("清除错误消息 / Clear error message")
    @MainActor
    func testClearError() async throws {
        let viewModel = HistoryViewModel()

        viewModel.errorMessage = "Test error"

        #expect(viewModel.errorMessage != nil)

        viewModel.clearError()

        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Helper Methods

    /// Create mock record
    private static func createMockRecord(
        username: String = "testuser",
        merchant: String = "walmart",
        barcode: String = "1234567890",
        storeLocation: String? = nil
    ) -> ScanRecord {
        return ScanRecord(
            username: username,
            merchant: merchant,
            barcode: barcode,
            location: nil,
            storeLocation: storeLocation,
            imageFilename: "test.jpg"
        )
    }
}

// MARK: - Private Extension

private extension HistoryViewModelTests {
    func createMockRecord(
        username: String = "testuser",
        merchant: String = "walmart",
        barcode: String = "1234567890",
        storeLocation: String? = nil
    ) -> ScanRecord {
        return ScanRecord(
            username: username,
            merchant: merchant,
            barcode: barcode,
            location: nil,
            storeLocation: storeLocation,
            imageFilename: "test.jpg"
        )
    }
}
