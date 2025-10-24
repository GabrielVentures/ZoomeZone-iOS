//
//  ShelfTagSnapApp.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/22.
//  Updated by kent.sun on 2025/10/23.
//

import SwiftUI
import FirebaseCore

/// App /// App entry point
@main
struct ShelfTagSnapApp: App {
    // MARK: - State Objects

 /// Firebase     /// Firebase manager
    @StateObject private var firebaseManager = FirebaseManager.shared

    /// Permission manager
    @StateObject private var permissionManager = PermissionManager.shared

    // MARK: - Initialization

    init() {
        // Configure Firebase
        FirebaseManager.configure()

        // Configure appearance
        configureAppearance()
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(firebaseManager)
                .environmentObject(permissionManager)
                .preferredColorScheme(.light) // Force light mode for now
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
}
