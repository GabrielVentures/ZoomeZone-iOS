//
//  UploadStatus.swift
//  ShelfTagSnap
//
//  Created by Claude on 2025-10-31.
//  Milestone 2: Cloud Sync Implementation
//

import Foundation
import SwiftUI

/// Cloud upload status for scan records
enum UploadStatus: String, Codable {
    /// Pending upload (not started)
    case pending = "pending"

    /// Currently uploading
    case uploading = "uploading"

    /// Successfully synced to cloud
    case synced = "synced"

    /// Upload failed
    case failed = "failed"

    // MARK: - Display Properties

    /// Status icon (SF Symbol name)
    var icon: String {
        switch self {
        case .pending:
            return "clock.fill"
        case .uploading:
            return "arrow.up.circle.fill"
        case .synced:
            return "checkmark.icloud.fill"
        case .failed:
            return "exclamationmark.icloud.fill"
        }
    }

    /// Status color
    var color: Color {
        switch self {
        case .pending:
            return .orange
        case .uploading:
            return .blue
        case .synced:
            return .green
        case .failed:
            return .red
        }
    }

    /// Status display text
    var displayText: String {
        switch self {
        case .pending:
            return "Pending Upload"
        case .uploading:
            return "Uploading..."
        case .synced:
            return "Synced"
        case .failed:
            return "Upload Failed"
        }
    }

    /// Short status text for compact display
    var shortText: String {
        switch self {
        case .pending:
            return "Pending"
        case .uploading:
            return "Uploading"
        case .synced:
            return "Synced"
        case .failed:
            return "Failed"
        }
    }

    /// Whether this status represents a successful sync
    var isSynced: Bool {
        return self == .synced
    }

    /// Whether this status allows retry
    var canRetry: Bool {
        return self == .failed || self == .pending
    }
}

// MARK: - Comparable

extension UploadStatus: Comparable {
    static func < (lhs: UploadStatus, rhs: UploadStatus) -> Bool {
        // Define priority order: failed > pending > uploading > synced
        let order: [UploadStatus] = [.failed, .pending, .uploading, .synced]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}
