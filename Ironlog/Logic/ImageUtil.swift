import Foundation
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics

enum ImageUtil {
    /// Re-encodes any image (HEIC, PNG, JPEG...) as an orientation-corrected JPEG no larger
    /// than `maxPixel` on its long edge.
    static func jpeg(from data: Data, maxPixel: Int, quality: Double = 0.82) -> Data? {
        guard let image = cgImage(from: data, maxPixel: maxPixel) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }
        let options = [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        CGImageDestinationAddImage(destination, image, options)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    static func cgImage(from data: Data, maxPixel: Int?) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        guard let maxPixel else {
            return CGImageSourceCreateImageAtIndex(source, 0, nil)
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Prepared photo + thumbnail, encoded off the main thread.
    static func prepare(_ data: Data) async -> (full: Data, thumb: Data?)? {
        await Task.detached(priority: .userInitiated) { () -> (full: Data, thumb: Data?)? in
            guard let full = jpeg(from: data, maxPixel: 2400) else { return nil }
            return (full, jpeg(from: data, maxPixel: 480, quality: 0.75))
        }.value
    }

    static func decode(_ data: Data?, maxPixel: Int?) async -> CGImage? {
        guard let data else { return nil }
        return await Task.detached(priority: .userInitiated) { () -> CGImage? in
            cgImage(from: data, maxPixel: maxPixel)
        }.value
    }
}
