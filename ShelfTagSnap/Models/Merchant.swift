//
//  Merchant.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//

import Foundation

/// Merchant enumeration
enum Merchant: String, CaseIterable, Codable, Identifiable {
    // MARK: - Cases

    case walmart = "Walmart"
    case target = "Target"
    case costco = "Costco"
    case kroger = "Kroger"

    // MARK: - Identifiable

    var id: String { self.rawValue }

    // MARK: - Computed Properties

    /// Display name
    var displayName: String {
        return self.rawValue
    }

    /// Icon name (SF Symbols)
    var iconName: String {
        switch self {
        case .walmart, .target, .costco, .kroger:
            return "storefront"
        }
    }

    /// Theme color (can be customized by brand)
    var colorHex: String {
        switch self {
        case .walmart:
            return "#0071CE"  // Walmart Blue
        case .target:
            return "#CC0000"  // Target Red
        case .costco:
            return "#0060A9"  // Costco Blue
        case .kroger:
            return "#004C97"  // Kroger Blue
        }
    }
}

// MARK: - Extensions

extension Merchant {

    /// Create merchant from string

    static func from(_ string: String) -> Merchant? {
        return Merchant.allCases.first { $0.rawValue == string }
    }

    /// Get all merchant display names
    static var allDisplayNames: [String] {
        return Merchant.allCases.map { $0.displayName }
    }
}
