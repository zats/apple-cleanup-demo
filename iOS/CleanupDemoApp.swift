import SwiftUI
import PhotosUI
import CoreImage

@main
struct CleanupDemoApp: App {
    var body: some Scene {
        WindowGroup { CleanupView() }
    }
}

private struct CleanupView: View {
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var input: Data?
    @State private var image: UIImage?
    @State private var selection = CGRect.zero
    @State private var output: URL?
    @State private var busy = false
    @State private var message = "Choose a photo, then drag over the area to remove."

    var body: some View {
        VStack(spacing: 20) {
            PhotosPicker("Choose photo", selection: $pickedPhoto, matching: .images)
            Spacer(minLength: 0)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .overlay {
                        GeometryReader { geometry in
                            Rectangle()
                                .stroke(.yellow, lineWidth: 2)
                                .frame(width: selection.width * geometry.size.width,
                                       height: selection.height * geometry.size.height)
                                .offset(x: selection.minX * geometry.size.width,
                                        y: selection.minY * geometry.size.height)
                                .opacity(selection.isEmpty ? 0 : 1)
                            Color.clear
                                .contentShape(Rectangle())
                                .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                                    let size = geometry.size
                                    let x1 = min(max(drag.startLocation.x / size.width, 0), 1)
                                    let y1 = min(max(drag.startLocation.y / size.height, 0), 1)
                                    let x2 = min(max(drag.location.x / size.width, 0), 1)
                                    let y2 = min(max(drag.location.y / size.height, 0), 1)
                                    selection = CGRect(x: min(x1, x2), y: min(y1, y2),
                                                       width: abs(x2 - x1), height: abs(y2 - y1))
                                })
                        }
                    }
            }
            Spacer(minLength: 0)
            if busy { ProgressView("Cleaning…") }
            Text(message).font(.callout).multilineTextAlignment(.center)
            HStack(spacing: 24) {
                Button("Clean up") { Task { await clean() } }
                    .disabled(input == nil || selection.isEmpty)
                if let output { ShareLink("Save image", item: output) }
            }
        }
        .padding()
        .disabled(busy)
        .task(id: pickedPhoto) {
            guard let pickedPhoto else { return }
            do {
                guard let data = try await pickedPhoto.loadTransferable(type: Data.self),
                      let photo = UIImage(data: data) else {
                    throw CleanupError(message: "Cannot read this image.")
                }
                input = data
                image = photo
                selection = .zero
                output = nil
                message = "Drag over the area to remove, then tap Clean up."
            } catch {
                message = error.localizedDescription
            }
        }
    }

    private func clean() async {
        guard let input else { return }
        busy = true
        defer { busy = false }
        let area = selection
        do {
            let data = try await Task.detached {
                guard let source = CIImage(data: input, options: [.applyOrientationProperty: true]),
                      let model = Bundle.main.url(forResource: "inpainting", withExtension: "mlmodelc",
                                                  subdirectory: "Models") else {
                    throw CleanupError(message: "Cannot load the image or model. Run scripts/fetch-model.py before building.")
                }
                let size = source.extent.size
                let rect = CGRect(x: area.minX * size.width, y: area.minY * size.height,
                                  width: area.width * size.width, height: area.height * size.height)
                    .integral.intersection(CGRect(origin: .zero, size: size))
                let result = try Cleanup(modelURL: model).clean(source, rect: rect)
                guard let png = CIContext().pngRepresentation(of: result, format: .RGBA8,
                    colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!) else {
                    throw CleanupError(message: "Cannot write the result.")
                }
                return png
            }.value
            let url = URL.documentsDirectory.appending(path: "cleaned.png")
            try data.write(to: url, options: .atomic)
            self.input = data
            image = UIImage(data: data)
            output = url
            selection = .zero
            message = "Done. Save the image, or select another area."
        } catch {
            message = error.localizedDescription
        }
    }
}
