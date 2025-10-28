//
//  SwiftDataService.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/27.
//

import Foundation
import SwiftData

/// SwiftData service for managing the model container and context
@MainActor
class SwiftDataService {
    // MARK: - Singleton

    static let shared = SwiftDataService()

    // MARK: - Properties

    /// The model container
    nonisolated(unsafe) private(set) var container: ModelContainer

    /// Main context for UI operations
    var mainContext: ModelContext {
        return container.mainContext
    }

    // MARK: - Initialization

    private init() {
        do {
            // Define the schema
            let schema = Schema([
                ScanRecordEntity.self,
                BarcodeInfoEntity.self,
                StoreInfoEntity.self,
                PhotoInfoEntity.self
            ])

            // Configure the model
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )

            // Create the container
            self.container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )

            print("[SwiftData] ✅ ModelContainer initialized successfully")
        } catch {
            fatalError("[SwiftData] ❌ Failed to create ModelContainer: \(error)")
        }
    }

    // MARK: - Context Management

    /// Create a new background context for heavy operations
    nonisolated func newBackgroundContext() -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    /// Save main context
    func saveMainContext() throws {
        if mainContext.hasChanges {
            try mainContext.save()
            print("[SwiftData] ✅ Main context saved")
        }
    }

    /// Save context (generic)
    func save(_ context: ModelContext) throws {
        if context.hasChanges {
            try context.save()
            print("[SwiftData] ✅ Context saved")
        }
    }
}

// MARK: - CRUD Operations

extension SwiftDataService {
    /// Insert a new scan record
    func insertScanRecord(_ entity: ScanRecordEntity, context: ModelContext? = nil) throws {
        let ctx = context ?? mainContext
        ctx.insert(entity)
        try save(ctx)
    }

    /// Delete a scan record
    func deleteScanRecord(_ entity: ScanRecordEntity, context: ModelContext? = nil) throws {
        let ctx = context ?? mainContext
        ctx.delete(entity)
        try save(ctx)
    }

    /// Delete multiple scan records
    func deleteScanRecords(_ entities: [ScanRecordEntity], context: ModelContext? = nil) throws {
        let ctx = context ?? mainContext
        for entity in entities {
            ctx.delete(entity)
        }
        try save(ctx)
    }

    /// Fetch all scan records (use with caution for large datasets)
    func fetchAllScanRecords(context: ModelContext? = nil) throws -> [ScanRecordEntity] {
        let ctx = context ?? mainContext
        let descriptor = FetchDescriptor<ScanRecordEntity>(
            sortBy: [SortDescriptor(\ScanRecordEntity.timestamp, order: .reverse)]
        )
        return try ctx.fetch(descriptor)
    }

    /// Fetch scan records for a specific user
    func fetchScanRecords(
        forUsername username: String,
        limit: Int? = nil,
        offset: Int = 0,
        context: ModelContext? = nil
    ) throws -> [ScanRecordEntity] {
        let ctx = context ?? mainContext

        var descriptor = FetchDescriptor<ScanRecordEntity>(
            predicate: #Predicate { $0.username == username },
            sortBy: [SortDescriptor(\ScanRecordEntity.timestamp, order: .reverse)]
        )

        if let limit = limit {
            descriptor.fetchLimit = limit
            descriptor.fetchOffset = offset
        }

        return try ctx.fetch(descriptor)
    }

    /// Count scan records for a user
    func countScanRecords(forUsername username: String, context: ModelContext? = nil) throws -> Int {
        let ctx = context ?? mainContext
        let descriptor = FetchDescriptor<ScanRecordEntity>(
            predicate: #Predicate { $0.username == username }
        )
        return try ctx.fetchCount(descriptor)
    }
}
