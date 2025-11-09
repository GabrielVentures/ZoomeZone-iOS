//
//  HistoryTypes.swift
//  ShelfTagSnap
//
//  Shared types for History views
//

import Foundation

/// Layout mode for history list display
enum HistoryLayoutMode: String, CaseIterable, Identifiable {
    case compact      // Compact list
    case comfortable  // Comfortable list
    case gallery      // Gallery grid

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .compact:
            return "Compact"
        case .comfortable:
            return "Comfortable"
        case .gallery:
            return "Gallery"
        }
    }

    var icon: String {
        switch self {
        case .compact:
            return "list.bullet"
        case .comfortable:
            return "list.bullet.indent"
        case .gallery:
            return "square.grid.2x2"
        }
    }
}
