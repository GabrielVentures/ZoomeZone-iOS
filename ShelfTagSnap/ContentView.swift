//
//  ContentView.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/22.
//  Updated by kent.sun on 2025/10/23.
//

import SwiftUI

/// App state enum for managing authentication flow
enum AppState {
    case initializing  // Initializing
    case authenticated // Authenticated
    case unauthenticated // Unauthenticated
}

/// Main view - shows different screens based on authentication state
struct ContentView: View {
    // MARK: - Environment Objects

    @EnvironmentObject private var firebaseManager: FirebaseManager

    // MARK: - State

    /// Current app state
    @State private var appState: AppState = .initializing

    /// Controls whether main app is actually created (delayed to avoid overlapping and camera init issues)
    @State private var shouldShowMainApp: Bool = false

    // MARK: - Body

    var body: some View {
        ZStack {
            switch appState {
            case .initializing:
                // Initializing: Show splash screen
                SplashView()
                    .transition(.opacity)
                    .zIndex(3)

            case .authenticated:
                // ✅ Authenticated: Show main app directly, don't check email verification
                MainTabView()
                    .overlay(alignment: .top) {
                        // Show top banner for unverified users (gentle reminder)
                        if !firebaseManager.isEmailVerified {
                            EmailVerificationBanner()
                                .environmentObject(firebaseManager)
                                .transition(.move(edge: .top).combined(with: .opacity))
                                .zIndex(10)
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                    .onAppear {
                        print("✅ [ContentView] Showing main app - authenticated")
                    }

            case .unauthenticated:
                // Not authenticated: Show authentication view
                AuthenticationView()
                    .transition(.opacity)
                    .zIndex(2)
                    .onAppear {
                        print("ℹ️ [ContentView] Showing auth view - not authenticated")
                    }
            }
        }
        .task {
            // Initialization: Check authentication state
            await initializeApp()
        }
        .onChange(of: firebaseManager.isAuthenticated) { _, isAuthenticated in
            // Update app state when authentication changes
            Task {
                await updateAppState(isAuthenticated: isAuthenticated)
            }
        }
    }

    // MARK: - Methods

    /// Initialize the app
    private func initializeApp() async {
        print("🚀 [ContentView] Initializing app")
        print("🔍 [ContentView] Firebase initialized: \(firebaseManager.isInitialized)")
        print("🔍 [ContentView] Authentication state: isAuthenticated = \(firebaseManager.isAuthenticated)")

        // Show splash screen for at least 1 second (better UX)
        let minimumSplashDuration: UInt64 = 1_000_000_000 // 1 second

 // ✅ Firebase init         // Firebase initialization completed synchronously in init, no need to wait

        // Wait for minimum splash duration (user experience)
        try? await Task.sleep(nanoseconds: minimumSplashDuration)

        // Update app state based on authentication (already up-to-date)
        print("✅ [ContentView] Splash complete, updating UI state")
        await updateAppState(isAuthenticated: firebaseManager.isAuthenticated)
    }

    /// Update app state
    private func updateAppState(isAuthenticated: Bool) async {
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.4)) {
                if isAuthenticated {
                    appState = .authenticated
                    // Delay main app creation (avoid camera init issues)
                    Task {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        await MainActor.run {
                            shouldShowMainApp = true
                        }
                    }
                } else {
                    appState = .unauthenticated
                    shouldShowMainApp = false
                }
            }
        }
        print("📱 [ContentView] App state updated: \(appState)")
    }
}

/// Phase 3-5 /// Main tab view (placeholder, to be implemented in Phase 3-5)
struct MainTabView: View {
    // MARK: - Environment Objects

    @EnvironmentObject private var firebaseManager: FirebaseManager

    // MARK: - State

    @State private var selectedTab: Tab = .tasks

    // MARK: - Tab Enum (Milestone 2: 4 Tab Architecture)

    enum Tab {
        case tasks      // Task list (previously camera)
        case local      // Local history (previously history)
        case cloud      // ⭐ NEW: Cloud backup
        case settings   // Settings
    }

    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedTab) {
            // 1️⃣ Task list
            TaskListView()
                .tabItem {
                    Label(Strings.TabBar.tasks, systemImage: "list.bullet.clipboard")
                }
                .tag(Tab.tasks)

            // 2️⃣ Local history (Milestone 2: Renamed from HistoryListView)
            LocalHistoryView()
                .tabItem {
                    Label("Local", systemImage: "internaldrive")
                }
                .tag(Tab.local)

            // 3️⃣ Cloud backup (Milestone 2: NEW)
            CloudBackupView()
                .tabItem {
                    Label("Cloud", systemImage: "icloud")
                }
                .tag(Tab.cloud)

            // 4️⃣ Settings
            SettingsView()
                .tabItem {
                    Label(Strings.TabBar.settings, systemImage: "gearshape")
                }
                .tag(Tab.settings)
        }
        .tint(.blue)
    }
}

/// Settings view
struct SettingsView: View {
    // MARK: - Environment Objects

    @EnvironmentObject private var firebaseManager: FirebaseManager
    @EnvironmentObject private var permissionManager: PermissionManager

    // MARK: - State

    @State private var showLogoutAlert: Bool = false
    @State private var storageInfo: StorageInfo?
    @State private var showStorageDetails: Bool = false
    @State private var showClearDataAlert: Bool = false
    @State private var showExportSheet: Bool = false
    @State private var isLoadingStorage: Bool = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                // User info + Email verification status
                Section {
                    if let user = firebaseManager.currentUser {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.title)
                                .foregroundColor(.blue)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.username)
                                    .font(.headline)

                                Text(user.email)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)

                        EmailVerificationStatusCard()
                            .environmentObject(firebaseManager)

                        // ✅ Change Password (requires email verification)
                        NavigationLink {
                            ChangePasswordView()
                                .environmentObject(firebaseManager)
                        } label: {
                            Label(Strings.Settings.changePassword, systemImage: "key.fill")
                        }
                        .disabled(!firebaseManager.isEmailVerified)
                        .opacity(firebaseManager.isEmailVerified ? 1.0 : 0.5)
                    }
                } header: {
                    Text(Strings.Settings.account)
                }

                // Storage management
                storageSection

                // Cloud sync settings (Milestone 2)
                Section {
                    NavigationLink {
                        CloudSyncSettingsView()
                    } label: {
                        Label("Cloud Sync", systemImage: "icloud.and.arrow.up")
                    }
                } header: {
                    Text("Cloud")
                }

                // App settings
                Section {
                    NavigationLink {
                        PermissionsView()
                            .environmentObject(permissionManager)
                    } label: {
                        Label(Strings.Settings.permissions, systemImage: "hand.raised.fill")
                    }
                } header: {
                    Text(Strings.Settings.appSettings)
                }

                // About
                Section {
                    HStack {
                        Text(Strings.Settings.version)
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text(Strings.Settings.about)
                }

                // Sign out
                Section {
                    Button(role: .destructive) {
                        showLogoutAlert = true
                    } label: {
                        Label(Strings.Settings.signOut, systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle(Strings.Settings.title)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                loadStorageInfo()
            }
            .refreshable {
                loadStorageInfo()
            }
            .alert(Strings.Settings.confirmSignOut, isPresented: $showLogoutAlert) {
                Button(Strings.Common.cancel, role: .cancel) {}
                Button(Strings.Settings.signOut, role: .destructive) {
                    try? firebaseManager.signOut()
                }
            } message: {
                Text(Strings.Settings.signOutMessage)
            }
            .alert(Strings.Settings.clearDataConfirmation, isPresented: $showClearDataAlert) {
                Button(Strings.Common.cancel, role: .cancel) {}
                Button(Strings.Common.clear, role: .destructive) {
                    Task {
                        await clearAllData()
                    }
                }
            } message: {
                Text(Strings.Settings.clearDataMessage)
            }
            .sheet(isPresented: $showStorageDetails) {
                StorageDetailsView(storageInfo: storageInfo)
            }
        }
    }

    // MARK: - Storage Section

    private var storageSection: some View {
        Section {
            // Storage info row
            if let info = storageInfo {
                NavigationLink {
                    StorageDetailsView(storageInfo: info)
                } label: {
                    HStack {
                        Image(systemName: "internaldrive")
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(Strings.Settings.storage)
                                .font(.body)

                            Text("\(info.formattedAppUsedSpace) / \(info.formattedTotalSpace)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // Status indicator
                        Image(systemName: info.status.icon)
                            .foregroundColor(Color(info.status.color))
                    }
                }
            } else if isLoadingStorage {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(Strings.Settings.loadingStorage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Clear data
            Button(role: .destructive) {
                showClearDataAlert = true
            } label: {
                Label(Strings.Settings.clearData, systemImage: "trash")
            }
        } header: {
            Text(Strings.Settings.storageManagement)
        } footer: {
            if let info = storageInfo {
                Text("\(Strings.Settings.recordsCount): \(info.recordsCount) | \(Strings.Settings.photosSize): \(info.formattedPhotosSize)")
                    .font(.caption)
            }
        }
    }

    // MARK: - Helper Methods

    private func loadStorageInfo() {
        isLoadingStorage = true
        Task {
            let info = StorageMonitor.shared.getStorageInfo()
            await MainActor.run {
                storageInfo = info
                isLoadingStorage = false
            }
        }
    }

    private func clearAllData() async {
        do {
            _ = try await StorageMonitor.shared.performCleanup(type: .deleteAllData)
            loadStorageInfo()
        } catch {
            print("Error clearing data: \(error)")
        }
    }
}

// MARK: - Storage Details View

struct StorageDetailsView: View {
    let storageInfo: StorageInfo?

    var body: some View {
        NavigationStack {
            List {
                if let info = storageInfo {
                    // Storage status
                    Section {
                        HStack {
                            Image(systemName: info.status.icon)
                                .foregroundColor(Color(info.status.color))
                                .font(.title2)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(info.status.title)
                                    .font(.headline)

                                Text(Strings.Settings.availableSpace)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text(info.formattedAvailableSpace)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        .padding(.vertical, 8)
                    }

                    // Device storage
                    Section {
                        HStack {
                            Text(Strings.Settings.total)
                            Spacer()
                            Text(info.formattedTotalSpace)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text(Strings.Settings.used)
                            Spacer()
                            Text(info.formattedUsedSpace)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text(Strings.Settings.available)
                            Spacer()
                            Text(info.formattedAvailableSpace)
                                .foregroundColor(.secondary)
                        }

                        // Progress bar
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(Strings.Settings.usage): \(Int(info.usedPercentage * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemGray5))
                                        .frame(height: 8)

                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.blue)
                                        .frame(width: geometry.size.width * info.usedPercentage, height: 8)
                                }
                            }
                            .frame(height: 8)
                        }
                    } header: {
                        Text(Strings.Settings.deviceStorage)
                    }

                    // App storage
                    Section {
                        HStack {
                            Text(Strings.Settings.appTotal)
                            Spacer()
                            Text(info.formattedAppUsedSpace)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text(Strings.Settings.photos)
                            Spacer()
                            Text(info.formattedPhotosSize)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text(Strings.Settings.records)
                            Spacer()
                            Text("\(info.recordsCount)")
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text(Strings.Settings.appStorage)
                    }

                    // Cleanup suggestions
                    if StorageMonitor.shared.shouldCleanup() {
                        let suggestions = StorageMonitor.shared.getCleanupSuggestions()

                        if !suggestions.isEmpty {
                            Section {
                                ForEach(suggestions.indices, id: \.self) { index in
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text(suggestions[index].title)
                                                .font(.body)
                                                .fontWeight(.medium)

                                            Spacer()

                                            Text("\(Strings.Settings.saveSpace) ~\(suggestions[index].formattedEstimatedSpace)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        Text(suggestions[index].description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                }
                            } header: {
                                Text(Strings.Settings.cleanupSuggestions)
                            }
                        }
                    }
                }
            }
            .navigationTitle(Strings.Settings.storageDetails)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Preview

#Preview("Not Authenticated") {
    ContentView()
        .environmentObject(FirebaseManager.shared)
        .environmentObject(PermissionManager.shared)
}

#Preview("Settings") {
    SettingsView()
        .environmentObject(FirebaseManager.shared)
}
