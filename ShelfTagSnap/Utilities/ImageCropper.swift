//
//  ImageCropper.swift
//  ShelfTagSnap
//
//  Created by Claude on 2025/10/26.
//
//  ULTRA-SIMPLE AUTO-CROP ALGORITHM
//  ================================
//  Strategy: Expand barcode with custom multipliers
//    - Vertical (top/bottom): 0.8 barcode height
//    - Horizontal (left/right): 4.7 barcode width
//  Complexity: ~170 lines (was 1080 lines)
//  Reliability: 100% predictable, easy to tune
//

import Foundation
import UIKit
import CoreGraphics

/// Ultra-simple image cropper for barcode regions
class ImageCropper {

    // MARK: - Configuration

    /// Vertical expansion multiplier (top/bottom: 0.8 barcode height)
    private static let verticalExpansionMultiplier: CGFloat = 0.9

    /// Horizontal expansion multiplier (left/right: 4.7 barcode width)
    private static let horizontalExpansionMultiplier: CGFloat = 4.7

    // MARK: - Public Methods

    /// Crop image around barcode with custom expansion (vertical: 3.5x, horizontal: 1.5x)
    ///
    /// - Parameters:
    ///   - image: Original image
    ///   - barcodeBoundingBox: Barcode bounding box (Vision normalized coordinates, 0-1 range, bottom-left origin)
    /// - Returns: Cropped image
    static func cropAroundBarcode(
        image: UIImage,
        barcodeBoundingBox: CGRect
    ) -> UIImage {

        guard let cgImage = image.cgImage else {
            print("⚠️ [ImageCropper] No CGImage available, returning original")
            return image
        }

        let imageSize = CGSize(
            width: CGFloat(cgImage.width),
            height: CGFloat(cgImage.height)
        )

        #if DEBUG
        print("📸 [ImageCropper] ===== ULTRA-SIMPLE CROP START =====")
        print("📏 [ImageCropper] Image size: \(imageSize)")
        print("📏 [ImageCropper] Barcode box (normalized): \(barcodeBoundingBox)")
        #endif

        // Step 1: Convert Vision normalized coordinates to pixel coordinates
        let pixelBarcodeBox = convertVisionToImageCoordinates(
            visionBox: barcodeBoundingBox,
            imageSize: imageSize
        )

        #if DEBUG
        print("📏 [ImageCropper] Barcode box (pixels): \(pixelBarcodeBox)")
        #endif

        // Step 2: Expand with custom vertical/horizontal multipliers
        let expandedBox = expandByMultiplier(
            barcodeBoundingBox: pixelBarcodeBox,
            imageSize: imageSize,
            verticalMultiplier: verticalExpansionMultiplier,
            horizontalMultiplier: horizontalExpansionMultiplier
        )

        #if DEBUG
        print("📐 [ImageCropper] Expanded box: \(expandedBox)")
        print("🔢 [ImageCropper] Expansion: vertical=\(verticalExpansionMultiplier)x, horizontal=\(horizontalExpansionMultiplier)x")
        #endif

        // Step 3: Crop the image
        guard let croppedCGImage = cgImage.cropping(to: expandedBox) else {
            print("⚠️ [ImageCropper] Crop failed, returning original")
            return image
        }

        let croppedImage = UIImage(
            cgImage: croppedCGImage,
            scale: image.scale,
            orientation: image.imageOrientation
        )

        #if DEBUG
        print("✅ [ImageCropper] Cropped size: \(croppedImage.size)")
        let reductionPercent = (1.0 - (croppedImage.size.width * croppedImage.size.height) / (imageSize.width * imageSize.height)) * 100
        print("📉 [ImageCropper] Size reduction: \(Int(reductionPercent))%")
        print("🎉 [ImageCropper] ===== ULTRA-SIMPLE CROP COMPLETE =====")
        #endif

        return croppedImage
    }

    // MARK: - Private Helper Methods

    /// Convert Vision normalized coordinates (0-1, bottom-left origin) to image pixel coordinates (top-left origin)
    private static func convertVisionToImageCoordinates(
        visionBox: CGRect,
        imageSize: CGSize
    ) -> CGRect {

        // Vision uses normalized coordinates (0-1) with bottom-left origin
        // UIImage/CGImage uses pixel coordinates with top-left origin

        let x = visionBox.origin.x * imageSize.width
        let y = (1.0 - visionBox.origin.y - visionBox.height) * imageSize.height  // Flip Y axis
        let width = visionBox.width * imageSize.width
        let height = visionBox.height * imageSize.height

        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Expand bounding box with custom vertical/horizontal multipliers
    ///
    /// - Parameters:
    ///   - barcodeBoundingBox: Barcode box in pixel coordinates
    ///   - imageSize: Image size
    ///   - verticalMultiplier: Vertical expansion (e.g., 3.5 = expand 3.5x barcode height top/bottom)
    ///   - horizontalMultiplier: Horizontal expansion (e.g., 1.5 = expand 1.5x barcode width left/right)
    /// - Returns: Expanded box, clamped to image boundaries
    private static func expandByMultiplier(
        barcodeBoundingBox: CGRect,
        imageSize: CGSize,
        verticalMultiplier: CGFloat,
        horizontalMultiplier: CGFloat
    ) -> CGRect {

        let barcodeWidth = barcodeBoundingBox.width
        let barcodeHeight = barcodeBoundingBox.height

        // Calculate expansion amounts (different for vertical and horizontal)
        let expandLeft = barcodeWidth * horizontalMultiplier
        let expandRight = barcodeWidth * horizontalMultiplier
        let expandTop = barcodeHeight * verticalMultiplier
        let expandBottom = barcodeHeight * verticalMultiplier

        // Expand the box
        let expandedBox = CGRect(
            x: barcodeBoundingBox.origin.x - expandLeft,
            y: barcodeBoundingBox.origin.y - expandTop,
            width: barcodeWidth + expandLeft + expandRight,
            height: barcodeHeight + expandTop + expandBottom
        )

        // Clamp to image boundaries
        let clampedBox = expandedBox.intersection(
            CGRect(origin: .zero, size: imageSize)
        )

        // Validate result
        if clampedBox.isEmpty || clampedBox.isNull || clampedBox.isInfinite {
            print("⚠️ [ImageCropper] Invalid expanded box, using original barcode box")
            return barcodeBoundingBox
        }

        return clampedBox
    }
}
