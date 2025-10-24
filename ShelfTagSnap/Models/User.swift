//
//  User.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//

import Foundation

/// User data model
struct User: Codable, Identifiable, Hashable {
    // MARK: - Properties

    /// User unique identifier
    let id: String

    /// User email address
    let email: String

    /// Display name (optional)
    let displayName: String?

    /// Account creation time
    let createdAt: Date

    // MARK: - Initialization

    /// Create new user
    /// - Parameters:

    init(id: String, email: String, displayName: String? = nil) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.createdAt = Date()
    }

    // MARK: - Computed Properties

    /// Username (prefer displayName, fallback to email prefix)
    var username: String {
        displayName ?? email.components(separatedBy: "@").first ?? email
    }

    /// Formatted creation time
    var formattedCreatedAt: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}

// MARK: - Extensions

extension User {

    /// Create from Firebase User

    static func from(firebaseUID: String, email: String, displayName: String?) -> User {
        return User(
            id: firebaseUID,
            email: email,
            displayName: displayName
        )
    }
}
