import AppKit
import Combine
import ServiceManagement

@MainActor
final class ClipboardModel: ObservableObject {
    static let shared = ClipboardModel()

    @Published private(set) var clips: [ClipItem] = []
    @Published var searchText = "" { didSet { reload() } }
    @Published var panelPresentationID = 0
    @Published var settingsPresentationID = 0
    @Published var pinnedOnly = false { didSet { reload() } }
    @Published var selectedKind: ClipKind? = nil { didSet { reload() } }
    @Published var selectedCollection: String? = nil { didSet { reload() } }
    @Published private(set) var collections: [String] = []
    @Published private(set) var pasteStack: [ClipItem] = []
    @Published private(set) var isPaused: Bool
    @Published var message: String?
    @Published private(set) var launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
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
    private var store: ClipboardStore?
    var databaseUnavailable: Bool { store == nil }

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
            clips = try store.items(
                search: searchText,
                pinnedOnly: pinnedOnly,
                collection: selectedCollection,
                kind: selectedKind
            )
            collections = try store.collectionNames()
            if let selectedCollection, !collections.contains(selectedCollection) {
                self.selectedCollection = nil
            }
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

    func addToPasteStack(_ item: ClipItem) {
        guard pasteStack.count < 100 else {
            message = "Paste Stack is full (100 items)."
            return
        }
        pasteStack.append(item)
    }

    func clearPasteStack() {
        pasteStack.removeAll()
    }

    func completePasteStackItem(id: String) {
        if pasteStack.first?.id == id {
            pasteStack.removeFirst()
        }
    }

    func move(_ item: ClipItem, toCollection name: String?) {
        do {
            try store?.setCollection(name, id: item.id)
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
            pasteStack.removeAll { $0.id == item.id }
            reload()
        } catch {
            message = error.localizedDescription
        }
    }

    func clearHistory() {
        do {
            try store?.clearAll()
            pasteStack.removeAll()
            selectedCollection = nil
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
        case .richText:
            let plain = board.setString(item.body ?? item.preview, forType: .string)
            if let data = item.richData, let rawType = item.richType,
               [NSPasteboard.PasteboardType.rtf.rawValue,
                NSPasteboard.PasteboardType.html.rawValue].contains(rawType) {
                let rich = board.setData(
                    data, forType: NSPasteboard.PasteboardType(rawType)
                )
                success = plain || rich
            } else {
                success = plain
            }
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
            if let raw = try? store?.imageData(for: item),
               let image = NSImage(data: raw) {
                success = board.writeObjects([image])
            } else {
                success = false
            }
        }
        onClipboardWrite?()
        if !success { message = "Could not copy this item." }
        return success
    }

    @discardableResult
    func copyAsPlainText(_ item: ClipItem) -> Bool {
        guard [.text, .link, .richText].contains(item.kind) else {
            message = "This item has no plain text representation."
            return false
        }
        let board = NSPasteboard.general
        board.clearContents()
        let success = board.setString(item.body ?? item.preview, forType: .string)
        onClipboardWrite?()
        if !success { message = "Could not copy plain text." }
        return success
    }

    func thumbnailSource(for item: ClipItem) -> ClipboardThumbnailSource? {
        store?.thumbnailSource(for: item)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
            if enabled && !launchAtLoginEnabled {
                message = "Launch at login requires approval in System Settings → General → Login Items."
            }
        } catch {
            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
            message = "Launch at login could not be changed: \(error.localizedDescription)"
        }
    }

    func quarantineAndResetStorage() {
        guard store == nil else {
            message = "Database recovery is available only when the current database could not be opened."
            return
        }
        do {
            let savedDirectory = try ClipboardRecovery.quarantine()
            let cleanStore = try ClipboardStore()
            store = cleanStore
            isPaused = true
            UserDefaults.standard.set(true, forKey: "clipboard.monitor.paused")
            onMonitoringChange?(true)
            reload()
            message = "A fresh encrypted history was created. Your previous files are preserved in \(savedDirectory.path)."
        } catch {
            message = "Recovery could not complete: \(error.localizedDescription)"
        }
    }

    func exportEncryptedBackup(password: String, to url: URL) {
        do {
            guard let store else {
                message = "History database is not available."
                return
            }
            let encrypted = try store.exportBackup(password: password)
            try encrypted.write(to: url, options: .atomic)
            message = "Encrypted backup exported."
        } catch {
            message = error.localizedDescription
        }
    }

    func importEncryptedBackup(from url: URL, password: String) {
        do {
            guard let store else {
                message = "History database is not available."
                return
            }
            let file = try Data(contentsOf: url)
            try store.importBackup(file, password: password)
            reload()
            message = "Encrypted backup imported."
        } catch {
            message = error.localizedDescription
        }
    }
}
