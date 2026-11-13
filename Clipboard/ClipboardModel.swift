import AppKit
import Combine
import ServiceManagement

@MainActor
final class ClipboardModel: ObservableObject {
    static let shared = ClipboardModel()

    @Published private(set) var clips: [ClipItem] = []
    @Published var selectedClipID: String?
    @Published private(set) var hotkeyPreset: ClipboardHotkeyPreset
    @Published var searchText = ""
    @Published var panelPresentationID = 0
    @Published var managerPresentationID = 0
    @Published var shelfBottomInset: CGFloat = 0
    @Published var settingsPresentationID = 0
    @Published var pinnedOnly = false { didSet { reload() } }
    @Published var selectedKind: ClipKind? = nil { didSet { reload() } }
    @Published var selectedCollection: String? = nil { didSet { reload() } }
    @Published var selectedSourceApp: String? = nil { didSet { reload() } }
    @Published var historyPeriod: ClipboardHistoryPeriod = .all { didSet { reload() } }
    @Published private(set) var sourceApps: [String] = []
    @Published private(set) var collections: [String] = []
    @Published private(set) var tags: [ClipTag] = []
    @Published var selectedTagID: String? = nil { didSet { reload() } }
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
    @Published var recognizeImages: Bool {
        didSet { UserDefaults.standard.set(recognizeImages, forKey: ClipboardPreferences.ocrKey) }
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

    private var cancellables = Set<AnyCancellable>()
    var onClipboardWrite: (() -> Void)?
    var onMonitoringChange: ((Bool) -> Void)?
    var onHotkeyChange: ((ClipboardHotkeyPreset) -> Bool)?
    private var store: ClipboardStore?
    var databaseUnavailable: Bool { store == nil }

    private init() {
        // The old Ctrl+Shift+V default is migrated once to the requested
        // Windows-key / Command+Shift+V shortcut. Preserve other explicit choices.
        // On a standard Mac key mapping, the Windows key acts as Command.
        let savedHotkey = UserDefaults.standard.string(
            forKey: ClipboardPreferences.hotkeyKey
        )
        let migrationKey = "clipboard.hotkey.commandShiftMigration.v1"
        if !UserDefaults.standard.bool(forKey: migrationKey) {
            if let replacement = ClipboardHotkeyPreset.migrateOldDefault(savedHotkey) {
                UserDefaults.standard.set(
                    replacement.rawValue,
                    forKey: ClipboardPreferences.hotkeyKey
                )
            }
            UserDefaults.standard.set(true, forKey: migrationKey)
        }
        hotkeyPreset = ClipboardHotkeyPreset(
            rawValue: UserDefaults.standard.string(forKey: ClipboardPreferences.hotkeyKey) ?? ""
        ) ?? .commandShiftV
        captureImages = ClipboardPreferences.captureImages
        captureFiles = ClipboardPreferences.captureFiles
        recognizeImages = ClipboardPreferences.recognizeImages
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
        $searchText
            .removeDuplicates()
            .debounce(for: .milliseconds(180), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.reload() }
            .store(in: &cancellables)
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
                kind: selectedKind,
                sourceApp: selectedSourceApp,
                since: historyPeriod.startDate,
                tagID: selectedTagID
            )
            if let selectedClipID, !clips.contains(where: { $0.id == selectedClipID }) {
                self.selectedClipID = clips.first?.id
            } else if selectedClipID == nil {
                self.selectedClipID = clips.first?.id
            }
            collections = try store.collectionNames()
            tags = try store.tagCatalog()
            if let selectedTagID, !tags.contains(where: { $0.id == selectedTagID }) {
                self.selectedTagID = nil
            }
            sourceApps = try store.sourceApplicationNames()
            if let selectedSourceApp, !sourceApps.contains(selectedSourceApp) {
                self.selectedSourceApp = nil
            }
            if let selectedCollection, !collections.contains(selectedCollection) {
                self.selectedCollection = nil
            }
        } catch {
            message = error.localizedDescription
        }
    }

    var selectedClip: ClipItem? {
        clips.first(where: { $0.id == selectedClipID }) ?? clips.first
    }

    @discardableResult
    func navigate(_ distance: Int) -> Bool {
        guard !clips.isEmpty else { return false }
        let currentIndex = clips.firstIndex(where: { $0.id == selectedClipID }) ?? 0
        let nextIndex = max(0, min(clips.count - 1, currentIndex + distance))
        selectedClipID = clips[nextIndex].id
        return true
    }

    func setHotkeyPreset(_ preset: ClipboardHotkeyPreset) {
        guard preset != hotkeyPreset else { return }
        guard onHotkeyChange?(preset) == true else {
            message = "Shortcut could not be registered. Another app may be using it."
            return
        }
        hotkeyPreset = preset
        UserDefaults.standard.set(preset.rawValue, forKey: ClipboardPreferences.hotkeyKey)
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

    func createSnippet(title: String, body: String) {
        do {
            try store?.createSnippet(title: title, body: body)
            selectedCollection = "Snippets"
            reload()
        } catch {
            message = error.localizedDescription
        }
    }

    func edit(_ item: ClipItem, title: String?, text: String?, asSnippet: Bool) {
        do {
            try store?.updateClip(
                id: item.id, title: title, text: text, asSnippet: asSnippet
            )
            pasteStack.removeAll { $0.id == item.id }
            reload()
        } catch {
            message = error.localizedDescription
        }
    }

    func rename(_ item: ClipItem, title: String?) {
        do {
            try store?.rename(id: item.id, to: title)
            reload()
        } catch {
            message = error.localizedDescription
        }
    }

    func saveAsSnippet(_ item: ClipItem, title: String) {
        do {
            try store?.saveAsSnippet(id: item.id, title: title)
            reload()
        } catch {
            message = error.localizedDescription
        }
    }

    func attachTag(_ tag: ClipTag, to item: ClipItem) {
        do {
            try store?.addTag(tag, to: item.id)
            reload()
        } catch { message = error.localizedDescription }
    }

    func detachTag(_ tagID: String, from item: ClipItem) {
        do {
            try store?.removeTag(tagID, from: item.id)
            reload()
        } catch { message = error.localizedDescription }
    }

    func editTag(_ tag: ClipTag, name: String, color: ClipTagColor) {
        do {
            try store?.editTag(tag.id, name: name, color: color)
            reload()
        } catch { message = error.localizedDescription }
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

    func clearRecent(minutes: Int) {
        do {
            try store?.deleteRecent(minutes: minutes)
            pasteStack.removeAll { item in !item.pinned &&
                item.createdAt >= Date().addingTimeInterval(-Double(minutes) * 60)
            }
            reload()
            message = "Recent unpinned history cleared."
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
        case .text, .link, .color:
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
    func copyRecognizedText(_ item: ClipItem) -> Bool {
        guard let text = item.recognizedText, !text.isEmpty else {
            message = "No recognized text is stored for this image."
            return false
        }
        let board = NSPasteboard.general
        board.clearContents()
        let result = board.setString(text, forType: .string)
        onClipboardWrite?()
        if !result { message = "Could not copy recognized image text." }
        return result
    }

    @discardableResult
    func copyAsPlainText(_ item: ClipItem) -> Bool {
        guard [.text, .link, .richText, .color].contains(item.kind) else {
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
