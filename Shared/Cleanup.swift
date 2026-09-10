import Foundation
import CoreImage
import CoreML
import ImageIO
import Darwin

struct CleanupError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

// Match the private pipeline's two-word layout. `mutating` passes self by address.
private struct GANPipeline {
    var cleanupModel: MLModel
    var refinementModel: MLModel? = nil

    @_silgen_name("$s24PhotosGenerativeServices18InpaintGANPipelineV10renderTile7context10inputImage04maskJ0013exclusionMaskJ011orientation012shouldDilateM0So7CIImageCSo9CIContextC_A3LSgSo26CGImagePropertyOrientationVSbtKF")
    mutating func render(context: CIContext, inputImage: CIImage, maskImage: CIImage, exclusionMaskImage: CIImage?, orientation: CGImagePropertyOrientation, shouldDilateMask: Bool) throws -> CIImage
}

public struct Cleanup {
    private let model: MLModel
    private let context = CIContext()

    public init(modelURL: URL) throws {
        guard dlopen("/System/Library/PrivateFrameworks/PhotosGenerativeServices.framework/PhotosGenerativeServices", RTLD_NOW | RTLD_GLOBAL) != nil else {
            throw CleanupError(message: "Cannot load the private cleanup framework.")
        }
        let configuration = MLModelConfiguration()
        configuration.setValue(true, forKey: "usePrecompiledE5Bundle")
        model = try MLModel(contentsOf: modelURL, configuration: configuration)
    }

    /// Rect uses integer pixels from the top-left of the oriented image.
    public func clean(_ image: CIImage, rect: CGRect) throws -> CIImage {
        let source = image.transformed(by: .init(
            translationX: -image.extent.minX, y: -image.extent.minY))
        guard rect.size.width > 0, rect.size.height > 0,
              rect == rect.integral, source.extent.contains(rect) else {
            throw CleanupError(message: "The rectangle must use whole pixels and fit inside the image.")
        }
        // Core Image uses a bottom-left origin.
        let area = CGRect(x: rect.minX, y: source.extent.height - rect.maxY,
                          width: rect.width, height: rect.height)
        let mask = CIImage(color: .white).cropped(to: area).composited(over:
            CIImage(color: .black).cropped(to: source.extent))
        var pipeline = GANPipeline(cleanupModel: model)
        let tile = try pipeline.render(context: context, inputImage: source,
            maskImage: mask, exclusionMaskImage: nil, orientation: .up, shouldDilateMask: true)
        let generated = tile.cropped(to: source.extent)
        return generated.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: source,
            kCIInputMaskImageKey: mask
        ]).cropped(to: source.extent)
    }
}
