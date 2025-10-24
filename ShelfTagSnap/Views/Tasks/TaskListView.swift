//
//  TaskListView.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//

import SwiftUI

/// Task list view showing available scanning tasks
struct TaskListView: View {
    // MARK: - Properties

    private let tasks: [TaskType] = [.shelfTagSnap]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(tasks) { task in
                        NavigationLink(destination: StoreSelectionView(task: task)) {
                            TaskCardView(task: task)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Task Card View

/// Individual task card component
struct TaskCardView: View {
    // MARK: - Properties

    let task: TaskType

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Task title
            Text(task.rawValue)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Task description (if available)
            if !task.description.isEmpty {
                Text(task.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }

            // Repeatable note
            if task.isRepeatable {
                Text("Note: this task is repeatable.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: task.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Preview

#Preview("Task List") {
    TaskListView()
}

#Preview("Task Card") {
    TaskCardView(task: .shelfTagSnap)
        .padding()
}
