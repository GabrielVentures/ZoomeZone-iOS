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
    /// ✅ Optimized: Enable disk cache for better user experience
    private func configureKingfisher() {
        // Get shared cache
        let cache = KingfisherManager.shared.cache

        // Memory cache configuration
        // 50MB memory cache limit (sufficient for ~100-200 cloud images in current session)
        cache.memoryStorage.config.totalCostLimit = 50 * 1024 * 1024  // 50MB

        // Expire memory cache after 10 minutes of inactivity
        cache.memoryStorage.config.expiration = .seconds(600)

        // Disk cache configuration
        // Enable disk cache for persistent storage across app restarts
        cache.diskStorage.config.sizeLimit = 800 * 1024 * 1024  // 200MB disk cache

        // Expire disk cache after 7 days
        cache.diskStorage.config.expiration = .days(7)

        // Download timeout configuration
        KingfisherManager.shared.downloader.downloadTimeout = 30.0  // 30 seconds timeout

        print("✅ [App] Kingfisher configured: Memory=50MB (10min), Disk=200MB (7days), Timeout=30s")
    }
}
