//
//  PhotoInfoEntity.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/27.
//

import Foundation
import SwiftData

/// SwiftData entity for photo information
@Model
final class PhotoInfoEntity {
    // MARK: - Properties

    /// Image filename (stored in app's documents directory)
    var filename: String

    /// File size in bytes
    var fileSize: Int64?

    /// Image width in pixels
    var width: Int?

    /// Image height in pixels
    var height: Int?

    /// Compression quality used (0.0-1.0)
    var compressionQuality: Double?

    /// Thumbnail data (small preview, ~5-10KB)
    /// Using externalStorage for binary data
    @Attribute(.externalStorage)
    var thumbnailData: Data?

    /// Image format (e.g., "JPEG", "PNG")
    var imageFormat: String?

    /// EXIF metadata (JSON string)
    var exifMetadata: String?

    /// Additional photo metadata
    var metadata: String?

    // MARK: - Initialization

    init(
        filename: String,
        fileSize: Int64? = nil,
        width: Int? = nil,
        height: Int? = nil,
        compressionQuality: Double? = nil,
        thumbnailData: Data? = nil,
        imageFormat: String? = "JPEG",
        exifMetadata: String? = nil,
        metadata: String? = nil
    ) {
        self.filename = filename
        self.fileSize = fileSize
        self.width = width
        self.height = height
        self.compressionQuality = compressionQuality
        self.thumbnailData = thumbnailData
        self.imageFormat = imageFormat
        self.exifMetadata = exifMetadata
        self.metadata = metadata
    }

    // MARK: - Computed Properties

    /// Whether has thumbnail
    var hasThumbnail: Bool {
        return thumbnailData != nil
    }

    /// File size in MB
    var fileSizeInMB: Double? {
        guard let size = fileSize else { return nil }
        return Double(size) / (1024.0 * 1024.0)
    }

    /// Image dimensions string
    var dimensionsString: String? {
        guard let w = width, let h = height else { return nil }
        return "\(w)×\(h)"
    }

    /// Aspect ratio
    var aspectRatio: Double? {
        guard let w = width, let h = height, h > 0 else { return nil }
        return Double(w) / Double(h)
    }

    /// File size formatted string
    var formattedFileSize: String? {
        guard let size = fileSize else { return nil }

        if size < 1024 {
            return "\(size) B"
        } else if size < 1024 * 1024 {
            return String(format: "%.1f KB", Double(size) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(size) / (1024.0 * 1024.0))
        }
    }
}
