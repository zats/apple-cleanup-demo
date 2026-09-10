import Foundation
import CoreImage

struct CleanupError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Remove a rectangle using the OS inpainting model.
/// Rect uses whole pixels from the top-left of the oriented image.
public func cleanUp(_ image: CIImage, rect: CGRect) throws -> CIImage {
    let source = image.transformed(by: .init(
        translationX: -image.extent.minX, y: -image.extent.minY))
    guard rect.width > 0, rect.height > 0,
          rect == rect.integral, source.extent.contains(rect) else {
        throw CleanupError(message: "The rectangle must use whole pixels and fit inside the image.")
    }
    guard let filter = CIFilter(name: "CIInpaintingFilter") else {
        throw CleanupError(message: "This OS does not provide the inpainting filter.")
    }
    let area = CGRect(x: rect.minX, y: source.extent.height - rect.maxY,
                      width: rect.width, height: rect.height)
    let mask = CIImage(color: .white).cropped(to: area).composited(over:
        CIImage(color: .black).cropped(to: source.extent))
    filter.setValue(source, forKey: kCIInputImageKey)
    // The inpainting filter removes black pixels; the blend mask uses white.
    filter.setValue(mask.applyingFilter("CIColorInvert"), forKey: kCIInputMaskImageKey)
    filter.setValue(CIVector(cgRect: area), forKey: "inputMaskBoundingBox")
    guard let generated = filter.outputImage else {
        throw CleanupError(message: "The inpainting filter did not return an image.")
    }
    return generated.applyingFilter("CIBlendWithMask", parameters: [
        kCIInputBackgroundImageKey: source, kCIInputMaskImageKey: mask
    ]).cropped(to: source.extent)
}
