# macOS Clean Up demo

Remove an object inside a rectangle with the inpainting model included in macOS.

- [`Cleanup.swift`](Cleanup.swift) is the library. Add this file to your target.
- [`main.swift`](main.swift) is the command-line demo.
- [`build.sh`](build.sh) builds the demo.

Supply your own image. Processing runs locally, using the OS model without a download or setup step.

## Run

With Xcode Command Line Tools installed:

```sh
./build.sh
./cleanup-image /path/to/input.png 100 100 200 200 /path/to/output.png
```

Arguments: `INPUT X Y WIDTH HEIGHT [OUTPUT.png]`. Coordinates are whole pixels from the top-left after applying the image's EXIF orientation. The output defaults to `input.cleaned.png`. Existing output files are preserved.

## Use the library

```swift
import CoreImage

let source = CIImage(contentsOf: imageURL, options: [.applyOrientationProperty: true])!
let result = try cleanUp(source, rect: CGRect(x: 100, y: 100, width: 200, height: 200))
```

The library calls the private Core Image filter `CIInpaintingFilter`. macOS supplies its model. A mask preserves pixels outside the rectangle. This filter uses a different model from Photos' Clean Up GAN. Its private API can change with OS updates.

Tested on an Apple M4 Mac running macOS 27.0 (26A428), including an EXIF-rotated JPEG. Fill quality varies and can leave a visible seam.

Source code: [MIT](LICENSE).
