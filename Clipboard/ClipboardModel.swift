import AppKit
import Combine

@MainActor
final class ClipboardModel: ObservableObject {
    static let shared = ClipboardModel()

    @Published private(set) var clips: [ClipItem] = []
    @Published var searchText = "" { didSet { reload() } }
    @Published var pinnedOnly = false { didSet { reload() } }
    @Published private(set) var isPaused: Bool
    @Published var message: String?

    var onClipboardWrite: (() -> Void)?
    private let store: ClipboardStore?

    private init() {
        isPaused = UserDefaults.standard.bool(forKey: "clipboard.monitor.paused")
        do {
            store = try ClipboardStore()
        } catch {
            store = nil
            message = error.localizedDescription
        }
        reload()
    }

    func capture(_ payload: ClipPayload, sourceApp: String) {
        guard !isPaused, let store else { return }
        do {
            try store.save(payload, sourceApp: sourceApp)
            reload()
        } catch {
            message = error.localizedDescription
        }
    }

    func reload() {
        guard let store else { return }
        do {
            clips = try store.items(search: searchText, pinnedOnly: pinnedOnly)
        } catch {
            message = error.localizedDescription
        }
    }

    func togglePaused() {
        isPaused.toggle()
        UserDefaults.standard.set(isPaused, forKey: "clipboard.monitor.paused")
    }

    func togglePinned(_ item: ClipItem) {
        do {
            try store?.setPinned(!item.pinned, id: item.id)
            reload()
        } catch {
            message = error.localizedDescription
        }
    }

    func delete(_ item: ClipItem) {
        do {
            try store?.delete(id: item.id)
            reload()
        } catch {
            message = error.localizedDescription
        }
    }

    func clearHistory() {
        do {
            try store?.clearAll()
            reload()
            message = "History cleared."
        } catch {
            message = error.localizedDescription
        }
    }

    @discardableResult
    func copy(_ item: ClipItem) -> Bool {
        let board = NSPasteboard.general
        board.clearContents()

        let success: Bool
        switch item.kind {
        case .text, .link:
            success = board.setString(item.body ?? item.preview, forType: .string)
        case .file:
            if let path = item.filePath {
                success = board.writeObjects([URL(fileURLWithPath: path) as NSURL])
            } else {
                success = false
            }
        case .image:
            if let url = store?.assetURL(for: item),
               let image = NSImage(contentsOf: url) {
                success = board.writeObjects([image])
            } else {
                success = false
            }
        }
        onClipboardWrite?()
        if !success { message = "Could not copy this item." }
        return success
    }

    func assetURL(for item: ClipItem) -> URL? {
        store?.assetURL(for: item)
    }
}
