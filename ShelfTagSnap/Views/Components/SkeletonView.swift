//
//  SkeletonView.swift
//  ShelfTagSnap
//
//  Skeleton loading views for better UX
//

import SwiftUI

// MARK: - Shimmer Effect Modifier

/// Shimmer animation effect for skeleton views
struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.white.opacity(0.4),
                            Color.clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + phase * geometry.size.width * 2)
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    /// Apply shimmer animation to the view
    func shimmer() -> some View {
        self.modifier(ShimmerEffect())
    }
}

// MARK: - Basic Skeleton Shapes

/// Rounded rectangle skeleton placeholder
struct SkeletonBox: View {
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat

    init(width: CGFloat? = nil, height: CGFloat = 16, cornerRadius: CGFloat = 8) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(.systemGray5))
            .frame(width: width, height: height)
            .shimmer()
    }
}

/// Circle skeleton placeholder
struct SkeletonCircle: View {
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(Color(.systemGray5))
            .frame(width: size, height: size)
            .shimmer()
    }
}

/// Text line skeleton placeholder
struct SkeletonText: View {
    let width: CGFloat?
    let height: CGFloat

    init(width: CGFloat? = nil, height: CGFloat = 14) {
        self.width = width
        self.height = height
    }

    var body: some View {
        SkeletonBox(width: width, height: height, cornerRadius: 4)
    }
}

// MARK: - Cloud List Skeleton

/// Skeleton view for cloud record list item
struct CloudListItemSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail skeleton
            SkeletonBox(width: 70, height: 70, cornerRadius: 10)

            // Content skeleton
            VStack(alignment: .leading, spacing: 6) {
                // SKU and Store line
                HStack(spacing: 8) {
                    SkeletonText(width: 100, height: 12)
                    SkeletonText(width: 80, height: 12)
                }

                // Product title
                SkeletonText(width: 180, height: 14)

                // Date line
                SkeletonText(width: 120, height: 12)
            }

            Spacer()

            // Status badge skeleton
            SkeletonBox(width: 40, height: 24, cornerRadius: 12)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

/// Full skeleton view for cloud records list
struct CloudListSkeleton: View {
    let itemCount: Int

    init(itemCount: Int = 5) {
        self.itemCount = itemCount
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(0..<itemCount, id: \.self) { _ in
                    CloudListItemSkeleton()
                }
            }
            .padding()
        }
    }
}

// MARK: - Cloud Detail Skeleton

/// Skeleton view for cloud record detail page
struct CloudDetailSkeleton: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Image skeleton
                SkeletonBox(height: 300, cornerRadius: 12)
                    .padding(.horizontal)

                // AI Result Card Skeleton
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack {
                        SkeletonText(width: 150, height: 20)
                        Spacer()
                    }

                    Divider()

                    // Fields
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(0..<6, id: \.self) { _ in
                            HStack {
                                SkeletonText(width: 80, height: 12)
                                Spacer()
                                SkeletonText(width: 120, height: 14)
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .padding(.horizontal)

                // Basic Info Card Skeleton
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    SkeletonText(width: 150, height: 20)

                    Divider()

                    // Fields
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(0..<4, id: \.self) { _ in
                            HStack {
                                SkeletonText(width: 80, height: 12)
                                Spacer()
                                SkeletonText(width: 100, height: 14)
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SkeletonView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // List skeleton preview
            NavigationView {
                CloudListSkeleton()
                    .navigationTitle("Cloud Backup")
            }
            .previewDisplayName("List Skeleton")

            // Detail skeleton preview
            NavigationView {
                CloudDetailSkeleton()
                    .navigationTitle("Record Detail")
            }
            .previewDisplayName("Detail Skeleton")

            // Individual components
            VStack(spacing: 20) {
                SkeletonText(width: 200)
                SkeletonBox(width: 300, height: 100)
                SkeletonCircle(size: 50)
                CloudListItemSkeleton()
            }
            .padding()
            .previewDisplayName("Components")
        }
    }
}
#endif
