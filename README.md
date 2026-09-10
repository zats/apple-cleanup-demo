# Apple Clean Up demo

Remove objects inside a rectangle with Apple's local Clean Up GAN, using Swift.

- [`Shared/Cleanup.swift`](Shared/Cleanup.swift): the complete cleanup implementation.
- [`macOS/main.swift`](macOS/main.swift): a CLI that takes an image path and rectangle.
- [`iOS/CleanupDemoApp.swift`](iOS/CleanupDemoApp.swift): choose a photo, drag a rectangle, clean it, and save the result.

Supply your own image. All image processing runs on the device.

## Setup

Use Xcode 27 on an Apple silicon Mac with macOS 27. Run this from the repository root:

```sh
python3 scripts/fetch-model.py
```

This downloads Apple's MagicCleanup 6.0.81607 archive using the Mac's Clean Up asset catalog, checks its SHA-256, and extracts `Models/inpainting.mlmodelc`. The download is about 189 MB. The model is kept outside Git.

The Mac's catalog must contain that version. If the catalog is missing, open a photo in Photos, choose **Edit → Clean Up**, let its assets download, and run the script again. A different catalog version needs separate compatibility testing.

## macOS

```sh
./macOS/build.sh
CLEANUP_MODEL="$PWD/Models/inpainting.mlmodelc" \
  ./build/cleanup-image /path/to/input.png 100 100 200 200 /path/to/output.png
```

Arguments: `INPUT X Y WIDTH HEIGHT [OUTPUT.png]`. Coordinates are whole pixels from the top-left after applying the image's EXIF orientation. The output defaults to `input.cleaned.png`. Existing output files are preserved.

## iPhone

1. Open `iOS/CleanupDemo.xcodeproj`.
2. Select your development team under **Signing & Capabilities**.
3. Select a physical iPhone and run.
4. Tap **Choose photo**, drag over the area to remove, then tap **Clean up**.
5. Tap **Save image** to share or save the PNG.

The Xcode project uses the same `Shared/Cleanup.swift` file and bundles the downloaded `Models` folder. The photo picker grants access to the selected image.

## Use the core

```swift
let source = CIImage(contentsOf: imageURL, options: [.applyOrientationProperty: true])!
let cleanup = try Cleanup(modelURL: modelURL)
let result = try cleanup.clean(source, rect: CGRect(x: 100, y: 100, width: 200, height: 200))
```

Add `Shared/Cleanup.swift` to your target and use the linker flags `-undefined dynamic_lookup`.

The file loads the private `PhotosGenerativeServices` framework and calls `InpaintGANPipeline.renderTile` through its Swift symbol. The two-field struct and `mutating` method match the tested private ABI. The precompiled Core ML model supplies the GAN. A mask limits changes to the selected rectangle.

The implementation targets the tested private Swift ABI. OS updates can change the symbols, struct layout, or model format.

## Tested

| Hardware | OS | Result |
| --- | --- | --- |
| Apple M4 Mac | macOS 27.0, 26A428 | Cleanup succeeds |
| iPhone 15 Pro | iOS 27.0, 24A435 | Cleanup succeeds |

With a 1254 × 1254 input and a 220 × 220 rectangle, the physical iPhone changed pixels inside the selection and preserved every decoded pixel outside it. This model failed to load in the iOS 27 simulator. Fill quality varies; a rectangle can leave a visible seam.

Source code: [MIT](LICENSE). The Apple model is downloaded separately and is not covered by this license.
