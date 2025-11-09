//
//  NetworkMonitor.swift
//  ShelfTagSnap
//
//  Created by Claude on 2025-10-31.
//  Milestone 2: Cloud Sync Implementation
//

import Foundation
import Network
import Combine

/// Network status monitor
/// Monitors network connectivity and provides information about connection type
@MainActor
class NetworkMonitor: ObservableObject {
    // MARK: - Singleton

    static let shared = NetworkMonitor()

    // MARK: - Published Properties

    /// Whether connected to network
    @Published var isConnected: Bool = false

    /// Whether using WiFi connection
    @Published var isUsingWiFi: Bool = false

    /// Whether using cellular connection
    @Published var isUsingCellular: Bool = false

    /// Current connection type
    @Published var connectionType: ConnectionType = .none

    // MARK: - Connection Type

    enum ConnectionType {
        case none
        case wifi
        case cellular
        case ethernet
        case other

        var description: String {
            switch self {
            case .none: return "No Connection"
            case .wifi: return "WiFi"
            case .cellular: return "Cellular"
            case .ethernet: return "Ethernet"
            case .other: return "Other"
            }
        }

        var icon: String {
            switch self {
            case .none: return "wifi.slash"
            case .wifi: return "wifi"
            case .cellular: return "antenna.radiowaves.left.and.right"
            case .ethernet: return "cable.connector"
            case .other: return "network"
            }
        }
    }

    // MARK: - Private Properties

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.shelftag.NetworkMonitor")

    // MARK: - Initialization

    private init() {
        startMonitoring()
    }

    // MARK: - Public Methods

    /// Start monitoring network status
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                // Update connection status
                self.isConnected = path.status == .satisfied

                // Update connection type
                if path.usesInterfaceType(.wifi) {
                    self.connectionType = .wifi
                    self.isUsingWiFi = true
                    self.isUsingCellular = false
                } else if path.usesInterfaceType(.cellular) {
                    self.connectionType = .cellular
                    self.isUsingWiFi = false
                    self.isUsingCellular = true
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.connectionType = .ethernet
                    self.isUsingWiFi = false
                    self.isUsingCellular = false
                } else if path.status == .satisfied {
                    self.connectionType = .other
                    self.isUsingWiFi = false
                    self.isUsingCellular = false
                } else {
                    self.connectionType = .none
                    self.isUsingWiFi = false
                    self.isUsingCellular = false
                }

                #if DEBUG
                print("🌐 [NetworkMonitor] Status changed:")
                print("   Connected: \(self.isConnected)")
                print("   Type: \(self.connectionType.description)")
                #endif
            }
        }

        monitor.start(queue: queue)
        print("🌐 [NetworkMonitor] Started monitoring network status")
    }

    /// Stop monitoring network status
    func stopMonitoring() {
        monitor.cancel()
        print("🌐 [NetworkMonitor] Stopped monitoring network status")
    }

    /// Check if upload is allowed based on user settings
    /// - Parameters:
    ///   - allowWiFi: Whether WiFi uploads are allowed
    ///   - allowCellular: Whether cellular uploads are allowed
    /// - Returns: Whether upload is currently allowed
    func canUpload(allowWiFi: Bool, allowCellular: Bool) -> Bool {
        guard isConnected else {
            #if DEBUG
            print("🌐 [NetworkMonitor] Upload not allowed: No connection")
            #endif
            return false
        }

        if isUsingWiFi && allowWiFi {
            #if DEBUG
            print("🌐 [NetworkMonitor] Upload allowed: WiFi connection")
            #endif
            return true
        }

        if isUsingCellular && allowCellular {
            #if DEBUG
            print("🌐 [NetworkMonitor] Upload allowed: Cellular connection")
            #endif
            return true
        }

        // Other connection types (e.g., Ethernet) are always allowed
        if connectionType == .ethernet || connectionType == .other {
            #if DEBUG
            print("🌐 [NetworkMonitor] Upload allowed: \(connectionType.description) connection")
            #endif
            return true
        }

        #if DEBUG
        print("🌐 [NetworkMonitor] Upload not allowed:")
        print("   Using WiFi: \(isUsingWiFi), allowed: \(allowWiFi)")
        print("   Using Cellular: \(isUsingCellular), allowed: \(allowCellular)")
        #endif

        return false
    }

    /// Check if currently using an expensive network (cellular)
    var isUsingExpensiveNetwork: Bool {
        return isUsingCellular
    }

    /// Check if currently using a constrained network
    var isConstrained: Bool {
        return isUsingCellular
    }

    // MARK: - Deinit

    deinit {
        // Directly cancel monitor without going through MainActor-isolated method
        monitor.cancel()
    }
}

// MARK: - Async Extensions

extension NetworkMonitor {
    /// Wait for network connection
    /// - Parameter timeout: Maximum time to wait in seconds
    /// - Returns: Whether network is connected within timeout
    func waitForConnection(timeout: TimeInterval = 30) async -> Bool {
        let startTime = Date()

        while !isConnected {
            if Date().timeIntervalSince(startTime) > timeout {
                print("🌐 [NetworkMonitor] Wait for connection timed out")
                return false
            }

            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }

        print("🌐 [NetworkMonitor] Connection established")
        return true
    }
}
