//
//  TaskType.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//

import Foundation
import SwiftUI

/// Task type enumeration for different scanning tasks
enum TaskType: String, CaseIterable, Identifiable {
    // MARK: - Cases

    case shelfTagSnap = "Shelf Tag Snap"
    case productPhotos = "Product photos and barcodes"
    case shelfSnapping = "Shelf snapping"
    case advancedShelfSnapping = "Advanced shelf snapping"
    case generalCapture = "General capture"

    // MARK: - Identifiable

    var id: String { self.rawValue }

    // MARK: - Computed Properties

    /// Task description
    var description: String {
        switch self {
        case .shelfTagSnap:
            return ""
        case .productPhotos:
            return "Take photos of the products and scan their barcodes."
        case .shelfSnapping:
            return "Take only photos of the shelves."
        case .advancedShelfSnapping:
            return "Take a photo of a shelf and label the items in view"
        case .generalCapture:
            return "Your task will be clearly defined in the task details provided to you."
        }
    }

    /// Detailed instructions
    var instructions: String {
        switch self {
        case .shelfTagSnap:
            return "Simply hover over the shelf tag until you feel it being collected and then move onto the next tag! Only select done when you're finished scanning all tags"
        case .productPhotos:
            return "Position the product clearly in frame, ensuring the barcode is visible and in focus. Tap to capture when ready."
        case .shelfSnapping:
            return "Capture clear photos of the entire shelf, ensuring all products are visible and well-lit."
        case .advancedShelfSnapping:
            return "Take a comprehensive photo of the shelf and identify each item visible in the frame."
        case .generalCapture:
            return "Follow the specific instructions provided in your task details."
        }
    }

    /// Task number for display
    var number: Int {
        switch self {
        case .shelfTagSnap:
            return 1
        case .productPhotos:
            return 2
        case .shelfSnapping:
            return 3
        case .advancedShelfSnapping:
            return 4
        case .generalCapture:
            return 5
        }
    }

    /// Whether the task is repeatable
    var isRepeatable: Bool {
        return true  // All tasks are currently repeatable
    }

    /// Task icon (SF Symbols)
    var iconName: String {
        switch self {
        case .shelfTagSnap:
            return "tag.fill"
        case .productPhotos:
            return "camera.fill"
        case .shelfSnapping:
            return "rectangle.stack.fill"
        case .advancedShelfSnapping:
            return "square.3.layers.3d"
        case .generalCapture:
            return "photo.on.rectangle"
        }
    }

    /// Task card background gradient colors
    var gradientColors: [Color] {
        switch self {
        case .shelfTagSnap:
            return [Color.blue.opacity(0.1), Color.blue.opacity(0.05)]
        case .productPhotos:
            return [Color.green.opacity(0.1), Color.green.opacity(0.05)]
        case .shelfSnapping:
            return [Color.orange.opacity(0.1), Color.orange.opacity(0.05)]
        case .advancedShelfSnapping:
            return [Color.purple.opacity(0.1), Color.purple.opacity(0.05)]
        case .generalCapture:
            return [Color.gray.opacity(0.1), Color.gray.opacity(0.05)]
        }
    }
}
