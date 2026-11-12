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
    @Published var captureImages: Bool {
        didSet { UserDefaults.standard.set(captureImages, forKey: ClipboardPreferences.imagesKey) }
    }
    @Published var captureFiles: Bool {
        didSet { UserDefaults.standard.set(captureFiles, forKey: ClipboardPreferences.filesKey) }
    }
    @Published var excludedAppsText: String {
        didSet { UserDefaults.standard.set(excludedAppsText, forKey: ClipboardPreferences.excludedAppsKey) }
    }
    @Published var retentionDays: Int {
        didSet {
            UserDefaults.standard.set(retentionDays, forKey: ClipboardPreferences.retentionDaysKey)
            enforceRetention()
        }
    }
    @Published var retentionCount: Int {
        didSet {
            UserDefaults.standard.set(retentionCount, forKey: ClipboardPreferences.retentionCountKey)
            enforceRetention()
        }
    }

    var onClipboardWrite: (() -> Void)?
    var onMonitoringChange: ((Bool) -> Void)?
    private let store: ClipboardStore?

    private init() {
        captureImages = ClipboardPreferences.captureImages
        captureFiles = ClipboardPreferences.captureFiles
        excludedAppsText = UserDefaults.standard.string(forKey: ClipboardPreferences.excludedAppsKey) ?? ""
        retentionDays = ClipboardPreferences.retentionDays
        retentionCount = ClipboardPreferences.retentionCount
        // Explicit opt-in: do not record clipboard history on first launch.
        let preferenceKey = "clipboard.monitor.paused"
        if UserDefaults.standard.object(forKey: preferenceKey) == nil {
            UserDefaults.standard.set(true, forKey: preferenceKey)
        }
        isPaused = UserDefaults.standard.bool(forKey: preferenceKey)
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
        onMonitoringChange?(isPaused)
    }

    func enforceRetention() {
        do {
            try store?.prune()
            reload()
        } catch {
            message = error.localizedDescription
        }
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
            if let stored = item.filePath {
                let paths = (try? JSONDecoder().decode([String].self, from: Data(stored.utf8))) ?? [stored]
                let existing = paths.filter {
                    FileManager.default.fileExists(atPath: $0)
                }
                success = !existing.isEmpty && board.writeObjects(
                    existing.map { URL(fileURLWithPath: $0) as NSURL }
                )
                if existing.count != paths.count {
                    message = "Some copied files were moved or deleted."
                }
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
