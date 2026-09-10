import Foundation
import CoreImage

do {
    let args = CommandLine.arguments
    guard args.count == 6 || args.count == 7 else {
        throw CleanupError(message:
            "Usage: cleanup-image INPUT X Y WIDTH HEIGHT [OUTPUT.png]\nSet CLEANUP_MODEL to a compatible inpainting.mlmodelc directory.")
    }
    let values = args[2...5].compactMap(Int.init)
    guard values.count == 4 else {
        throw CleanupError(message: "X, Y, WIDTH and HEIGHT must be integers in pixels.")
    }
    let inputURL = URL(fileURLWithPath: args[1])
    let outputURL = args.count == 7 ? URL(fileURLWithPath: args[6]) :
        inputURL.deletingPathExtension().appendingPathExtension("cleaned.png")
    guard !FileManager.default.fileExists(atPath: outputURL.path) else {
        throw CleanupError(message: "The output already exists. Choose a new output path.")
    }
    guard let modelPath = ProcessInfo.processInfo.environment["CLEANUP_MODEL"], !modelPath.isEmpty else {
        throw CleanupError(message: "Set CLEANUP_MODEL to the inpainting.mlmodelc directory.")
    }
    guard let source = CIImage(contentsOf: inputURL, options: [.applyOrientationProperty: true]) else {
        throw CleanupError(message: "Core Image cannot read the input image.")
    }
    let cleaner = try Cleanup(modelURL: URL(fileURLWithPath: modelPath))
    let rect = CGRect(x: values[0], y: values[1], width: values[2], height: values[3])
    let result = try cleaner.clean(source, rect: rect)
    try CIContext().writePNGRepresentation(of: result, to: outputURL,
        format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
    print(outputURL.path)
} catch {
    FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
    exit(1)
}
