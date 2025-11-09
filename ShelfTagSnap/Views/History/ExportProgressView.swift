//
//  ExportProgressView.swift
//  ShelfTagSnap
//
//  Shared export progress overlay view
//

import SwiftUI

/// Export progress overlay view
struct ExportProgressView: View {
    let progress: ExportProgress

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Progress circle

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 8)
                        .frame(width: 100, height: 100)

                    Circle()
                        .trim(from: 0, to: progress.percentage)
                        .stroke(Color.blue, lineWidth: 8)
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear, value: progress.percentage)

                    Text("\(Int(progress.percentage * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }

                VStack(spacing: 8) {
                    Text(progress.status)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("\(progress.currentItem) / \(progress.totalItems)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground).opacity(0.95))
            )
            .shadow(radius: 20)
        }
    }
}
