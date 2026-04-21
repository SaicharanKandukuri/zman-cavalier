import AppKit
import CoreGraphics

/// Tiny helper that loads and caches a CGImage from a file path.
/// Only re-decodes when the path changes, so rendering stays at display-link rate.
final class ImageCache {
    private var cachedPath: String = ""
    private var cached: CGImage?

    func image(for path: String) -> CGImage? {
        if path.isEmpty { return nil }
        if path == cachedPath, let cached = cached { return cached }
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        guard let data = try? Data(contentsOf: url),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let img = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            cachedPath = ""
            cached = nil
            return nil
        }
        cachedPath = path
        cached = img
        return img
    }
}
