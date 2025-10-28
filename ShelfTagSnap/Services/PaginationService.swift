//
//  PaginationService.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/27.
//

import Foundation
import SwiftData

/// Pagination service for fetching scan records in batches
@MainActor
class PaginationService {
    // MARK: - Properties

    /// Page size (number of records per page)
    private let pageSize: Int

    /// SwiftData service
    private let swiftDataService: SwiftDataService

    /// Current cursor (timestamp of last fetched record)
    private var currentCursor: Date?

    /// Whether there are more records to fetch
    private(set) var hasMore: Bool = true

    /// Current username filter
    private var username: String?

    /// Current date filter
    private var dateFilter: DateFilterType?

    // MARK: - Initialization

    init(
        pageSize: Int = 50,
        swiftDataService: SwiftDataService = .shared
    ) {
        self.pageSize = pageSize
        self.swiftDataService = swiftDataService
    }

    // MARK: - Configuration

    /// Configure filters
    func configure(username: String?, dateFilter: DateFilterType?) {
        self.username = username
        self.dateFilter = dateFilter
        reset()
    }

    /// Reset pagination state
    func reset() {
        currentCursor = nil
        hasMore = true
    }

    // MARK: - Fetching

    /// Fetch next page of records
    func fetchNextPage() async throws -> [ScanRecordEntity] {
        guard hasMore else {
            return []
        }

        guard let username = username else {
            return []
        }

        let context = swiftDataService.newBackgroundContext()
        let cursor = currentCursor
        let filter = dateFilter
        let limit = pageSize

        let records = try await Task.detached(priority: .userInitiated) {
            // Build predicate based on filters
            var predicate: Predicate<ScanRecordEntity>

            if let cursor = cursor, let filter = filter {
                // Has cursor AND date filter
                let range = filter.dateRange()
                let rangeStart = range.start
                let rangeEnd = range.end
                predicate = #Predicate<ScanRecordEntity> {
                    $0.username == username &&
                    $0.timestamp < cursor &&
                    $0.timestamp >= rangeStart &&
                    $0.timestamp < rangeEnd
                }
            } else if let cursor = cursor {
                // Has cursor only
                predicate = #Predicate<ScanRecordEntity> {
                    $0.username == username &&
                    $0.timestamp < cursor
                }
            } else if let filter = filter {
                // Has date filter only
                let range = filter.dateRange()
                let rangeStart = range.start
                let rangeEnd = range.end
                predicate = #Predicate<ScanRecordEntity> {
                    $0.username == username &&
                    $0.timestamp >= rangeStart &&
                    $0.timestamp < rangeEnd
                }
            } else {
                // No filters except username
                predicate = #Predicate<ScanRecordEntity> {
                    $0.username == username
                }
            }

            // Create descriptor
            var descriptor = FetchDescriptor<ScanRecordEntity>(
                predicate: predicate,
                sortBy: [SortDescriptor(\ScanRecordEntity.timestamp, order: .reverse)]
            )
            descriptor.fetchLimit = limit

            return try context.fetch(descriptor)
        }.value

        // Update cursor and hasMore
        if let lastRecord = records.last {
            currentCursor = lastRecord.timestamp
            hasMore = records.count == pageSize
        } else {
            hasMore = false
        }

        return records
    }

    /// Fetch records for a specific date range
    func fetchRecords(
        forUsername username: String,
        dateFilter: DateFilterType
    ) async throws -> [ScanRecordEntity] {
        configure(username: username, dateFilter: dateFilter)

        var allRecords: [ScanRecordEntity] = []

        // Fetch all pages for this date range
        while hasMore {
            let page = try await fetchNextPage()
            if page.isEmpty {
                break
            }
            allRecords.append(contentsOf: page)
        }

        return allRecords
    }

    /// Count total records matching filters
    func countRecords(
        forUsername username: String,
        dateFilter: DateFilterType?
    ) async throws -> Int {
        let context = swiftDataService.newBackgroundContext()

        return try await Task.detached(priority: .userInitiated) {
            var predicate: Predicate<ScanRecordEntity>

            if let filter = dateFilter {
                let range = filter.dateRange()
                let rangeStart = range.start
                let rangeEnd = range.end
                predicate = #Predicate<ScanRecordEntity> {
                    $0.username == username &&
                    $0.timestamp >= rangeStart &&
                    $0.timestamp < rangeEnd
                }
            } else {
                predicate = #Predicate<ScanRecordEntity> {
                    $0.username == username
                }
            }

            let descriptor = FetchDescriptor<ScanRecordEntity>(predicate: predicate)
            return try context.fetchCount(descriptor)
        }.value
    }
}

// MARK: - Batch Operations

extension PaginationService {
    /// Fetch all records in batches (for export)
    func fetchAllRecords(
        forUsername username: String,
        progressHandler: ((Int, Int) -> Void)? = nil
    ) async throws -> [ScanRecordEntity] {
        configure(username: username, dateFilter: nil)

        // Get total count
        let totalCount = try await countRecords(forUsername: username, dateFilter: nil)

        var allRecords: [ScanRecordEntity] = []
        var fetchedCount = 0

        while hasMore {
            let page = try await fetchNextPage()
            if page.isEmpty {
                break
            }

            allRecords.append(contentsOf: page)
            fetchedCount += page.count

            // Report progress
            await MainActor.run {
                progressHandler?(fetchedCount, totalCount)
            }
        }

        return allRecords
    }
}
