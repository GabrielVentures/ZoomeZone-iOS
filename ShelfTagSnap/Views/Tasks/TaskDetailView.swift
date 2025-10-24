//
//  TaskDetailView.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//

import SwiftUI

/// Task detail view showing instructions
struct TaskDetailView: View {
    // MARK: - Properties

    let task: TaskType

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Instructions content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Task number and title
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(task.number)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(task.rawValue)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Text(task.instructions)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(24)
            }

            // Start button (fixed at bottom)
            VStack(spacing: 0) {
                Divider()

                NavigationLink(destination: StoreSelectionView(task: task)) {
                    Text("Start")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .background(Color(UIColor.systemBackground))
        }
        .navigationTitle("Instructions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TaskDetailView(task: .shelfTagSnap)
    }
}
