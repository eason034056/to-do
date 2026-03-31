import UIKit

enum AvatarProcessor {

    enum ProcessingError: Error, LocalizedError {
        case imageCreationFailed

        var errorDescription: String? {
            switch self {
            case .imageCreationFailed: "Failed to create the processed image."
            }
        }
    }

    static func processAvatar(from source: UIImage, outputSize: CGFloat = 256) async throws -> UIImage {
        let downscaled = downscale(source, maxDimension: 1024)

        guard let cgImage = downscaled.cgImage else {
            throw ProcessingError.imageCreationFailed
        }

        let cropped = cropToSquare(cgImage: cgImage)

        guard let result = renderCircularAvatar(from: UIImage(cgImage: cropped), outputSize: outputSize) else {
            throw ProcessingError.imageCreationFailed
        }
        return result
    }

    // MARK: - Downscale

    private static func downscale(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else { return image }

        let scale = maxDimension / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    // MARK: - Square Crop (center)

    private static func cropToSquare(cgImage: CGImage) -> CGImage {
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let side = min(width, height)
        let rect = CGRect(
            x: (width - side) / 2,
            y: (height - side) / 2,
            width: side,
            height: side
        )
        return cgImage.cropping(to: rect) ?? cgImage
    }

    // MARK: - Circular Render

    private static func renderCircularAvatar(from image: UIImage, outputSize: CGFloat) -> UIImage? {
        let size = CGSize(width: outputSize, height: outputSize)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let ctx = context.cgContext
            let rect = CGRect(origin: .zero, size: size)

            ctx.saveGState()
            let clipPath = UIBezierPath(ovalIn: rect)
            clipPath.addClip()
            image.draw(in: rect)
            ctx.restoreGState()
        }
    }
}
