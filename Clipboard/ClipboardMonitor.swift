import AppKit

/// Reads the pasteboard only when its change count advances.
@MainActor
final class ClipboardMonitor {
    typealias Capture = (ClipPayload, String) -> Void

    private let pasteboard = NSPasteboard.general
    private let capture: Capture
    private var lastChangeCount: Int
    private var timer: Timer?
    var isPaused = false {
        didSet {
            // Do not capture changes that occurred while monitoring was paused.
            if oldValue && !isPaused { lastChangeCount = pasteboard.changeCount }
        }
    }

    init(capture: @escaping Capture) {
        self.capture = capture
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 0.65, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Avoid recapturing data we place on the clipboard ourselves.
    func acknowledgeOwnWrite() {
        lastChangeCount = pasteboard.changeCount
    }

    private func poll() {
        let current = pasteboard.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current
        guard !isPaused else { return }

        let source = NSWorkspace.shared.frontmostApplication
        let bundleID = (source?.bundleIdentifier ?? "").lowercased()
        let typeNames = (pasteboard.types ?? []).map(\.rawValue)
        guard !ClipboardPrivacy.shouldIgnore(
            bundleID: bundleID,
            typeNames: typeNames,
            customBundleIDs: ClipboardPreferences.excludedBundleIDs
        ) else { return }

        let appName = source?.localizedName ?? "Unknown App"

        if ClipboardPreferences.captureFiles,
           let urls = pasteboard.readObjects(
               forClasses: [NSURL.self],
               options: [.urlReadingFileURLsOnly: true]
           ) as? [URL], let first = urls.first {
            // JSON supports multi-file selections; single legacy file paths are still supported.
            let paths = urls.prefix(100).map(\.path)
            let encoded = (try? JSONEncoder().encode(paths)).flatMap {
                String(data: $0, encoding: .utf8)
            }
            let payload = ClipPayload(
                kind: .file,
                preview: paths.count == 1 ? first.lastPathComponent : "\(paths.count) files · \(first.lastPathComponent)",
                body: nil,
                filePath: encoded ?? first.path
            )
            capture(payload, appName)
            return
        }

        if ClipboardPreferences.captureImages,
           let image = NSImage(pasteboard: pasteboard),
           let tiff = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let png = bitmap.representation(using: .png, properties: [:]),
           png.count <= 12 * 1024 * 1024 {
            capture(ClipPayload(kind: .image, preview: "Image", imagePNG: png), appName)
            return
        }

        if let text = pasteboard.string(forType: .string), !text.isEmpty,
           text.utf8.count <= 2 * 1024 * 1024 {
            let preview = ClipText.preview(text)
            guard !preview.isEmpty else { return }
            capture(ClipPayload(kind: ClipText.kind(for: text), preview: preview, body: text), appName)
        }
    }
}
