//
//  ShelfTagSnapApp.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/22.
//  Updated by kent.sun on 2025/10/23.
//

import SwiftUI
import SwiftData
import FirebaseCore
import Kingfisher

/// App /// App entry point
@main
struct ShelfTagSnapApp: App {
    // MARK: - State Objects

    /// Firebase manager
    @StateObject private var firebaseManager = FirebaseManager.shared

    /// Permission manager
    @StateObject private var permissionManager = PermissionManager.shared

    /// SwiftData service
    private let swiftDataService = SwiftDataService.shared

    // MARK: - Initialization

    init() {
        // Configure Firebase
        FirebaseManager.configure()

        // Configure appearance
        configureAppearance()

        // ✅ Configure Kingfisher for image caching
        configureKingfisher()

        // Initialize SwiftData (already initialized in service)
        print("[App] ✅ SwiftData initialized")
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(firebaseManager)
                .environmentObject(permissionManager)
                .modelContainer(swiftDataService.container)
                .preferredColorScheme(.light) // Force light mode for now
                .task {
                    // ✅ FIX P0-8: Validate and fix inconsistent upload states on app start
                    await validateDataConsistency()
                }
        }
    }

    // MARK: - Startup Tasks

    /// Validate data consistency on app startup
    /// ✅ FIX P0-8: Check and fix any inconsistent upload states
    @MainActor
    private func validateDataConsistency() async {
        do {
            let result = try await RecordStorageService.shared.validateAndFixUploadStates()
            if result.fixed > 0 {
                print("⚠️ [App] Fixed \(result.fixed) inconsistent records: \(result.inconsistent)")
            } else {
                print("✅ [App] All upload states are consistent")
            }
        } catch {
            print("❌ [App] Failed to validate upload states: \(error)")
        }
    }

    // MARK: - Configuration

    /// Configure app appearance
    private func configureAppearance() {
 // Navigation Bar
        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.configureWithOpaqueBackground()
        navigationBarAppearance.backgroundColor = .systemBackground
        navigationBarAppearance.titleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]

        UINavigationBar.appearance().standardAppearance = navigationBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
        UINavigationBar.appearance().compactAppearance = navigationBarAppearance

 // Tab Bar
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = .systemBackground

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }

    /// Configure Kingfisher image caching
    /// ✅ FIX: Configure memory-only caching for Cloud images
    private func configureKingfisher() {
        // Get shared cache
        let cache = KingfisherManager.shared.cache

        // Memory cache configuration
        // 50MB memory cache limit (sufficient for ~100-200 cloud images)
        cache.memoryStorage.config.totalCostLimit = 50 * 1024 * 1024  // 50MB

        // Expire memory cache after 5 minutes of inactivity
        cache.memoryStorage.config.expiration = .seconds(300)

        // Disk cache configuration
        // Disable disk cache for cloud images (save storage space)
        // Individual views use .cacheMemoryOnly() modifier
        cache.diskStorage.config.sizeLimit = 0  // Disable disk cache globally

        // Download timeout configuration
        KingfisherManager.shared.downloader.downloadTimeout = 30.0  // 30 seconds timeout

        print("✅ [App] Kingfisher configured: Memory=50MB, Disk=Disabled, Timeout=30s")
    }
}
