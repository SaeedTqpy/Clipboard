import AppKit
import SwiftUI
import Carbon
import ApplicationServices

@main
struct ClipboardApp: App {
    @NSApplicationDelegateAdaptor(ClipboardAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            ClipboardSettingsView(model: .shared)
        }
    }
}

private final class ClipboardFloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class ClipboardAppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let model = ClipboardModel.shared
    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var monitor: ClipboardMonitor?
    private var hotkey: ClipboardGlobalHotkey?
    private var outsideClickMonitor: Any?
    private var previousApp: NSRunningApplication?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let monitor = ClipboardMonitor { [weak self] payload, source in
            self?.model.capture(payload, sourceApp: source)
        }
        monitor.isPaused = model.isPaused
        monitor.start()
        self.monitor = monitor

        model.onClipboardWrite = { [weak monitor] in
            monitor?.acknowledgeOwnWrite()
        }
        model.onMonitoringChange = { [weak monitor] paused in
            monitor?.isPaused = paused
        }

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard")
            button.toolTip = "Clipboard — Command Shift V"
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        self.statusItem = statusItem

        hotkey = ClipboardGlobalHotkey { [weak self] in
            self?.togglePanel()
        }
        if hotkey?.isRegistered != true {
            model.message = "The ⌘⇧V shortcut could not be registered. Another app may be using it. Use the menu bar to open Clipboard."
        }
        buildPanel()
        let onboardingKey = "clipboard.hasOpenedOnce"
        if UserDefaults.standard.object(forKey: onboardingKey) == nil {
            UserDefaults.standard.set(true, forKey: onboardingKey)
            DispatchQueue.main.async { [weak self] in self?.showPanel() }
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(NSMenuItem(title: "Open Clipboard  ⌘⇧V", action: #selector(openPanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem(
            title: model.isPaused ? "Resume Monitoring" : "Pause Monitoring",
            action: #selector(toggleMonitoring),
            keyEquivalent: ""
        ))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Clear All History…", action: #selector(confirmClear), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Clipboard", action: #selector(quit), keyEquivalent: ""))
        for item in menu.items { item.target = self }
    }

    private func buildPanel() {
        let rect = NSRect(x: 0, y: 0, width: 1050, height: 445)
        let panel = ClipboardFloatingPanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.contentView = NSHostingView(rootView: ClipboardPanelView(
            model: model,
            onDismiss: { [weak self] in self?.hidePanel() },
            onPaste: { [weak self] item in self?.paste(item) },
            onPastePlain: { [weak self] item in self?.paste(item, asPlainText: true) },
            onPasteNext: { [weak self] in self?.pasteStackNext() }
        ))
        self.panel = panel
    }

    @objc private func openPanel() { showPanel() }

    @objc private func openSettings() {
        showPanel()
        model.settingsPresentationID &+= 1
    }

    private func togglePanel() {
        guard let panel else { return }
        if panel.isVisible { hidePanel() } else { showPanel() }
    }

    private func showPanel() {
        guard let panel else { return }
        let foreground = NSWorkspace.shared.frontmostApplication
        if foreground?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp = foreground
        }
        model.searchText = ""
        model.panelPresentationID &+= 1
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
            ?? NSScreen.main ?? NSScreen.screens.first {
            let available = screen.visibleFrame
            let width = min(1050, max(520, available.width - 24))
            let x = available.midX - width / 2
            panel.setFrame(NSRect(
                x: x, y: available.minY + 24,
                width: width, height: 445
            ), display: true)
        }
        panel.orderFrontRegardless()
        panel.makeKey()
        if outsideClickMonitor == nil {
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.hidePanel() }
            }
        }
    }

    private func hidePanel() {
        panel?.orderOut(nil)
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }

    private func pasteStackNext() {
        guard let item = model.pasteStack.first else { return }
        paste(item, onPosted: { [weak self] in
            self?.model.completePasteStackItem(id: item.id)
        })
    }

    private func paste(
        _ item: ClipItem,
        asPlainText: Bool = false,
        onPosted: (() -> Void)? = nil
    ) {
        let copied = asPlainText ? model.copyAsPlainText(item) : model.copy(item)
        guard copied else { return }
        guard AXIsProcessTrusted() else {
            model.message = "Copied. To paste automatically, enable Clipboard under System Settings → Privacy & Security → Accessibility."
            hidePanel()
            return
        }
        guard let target = previousApp, !target.isTerminated,
              target.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            model.message = "Copied. No previous application is available for automatic paste."
            hidePanel()
            return
        }
        hidePanel()
        guard target.activate(options: [.activateIgnoringOtherApps]) else {
            model.message = "Copied. Could not restore the destination application."
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            // Never synthesize Cmd+V into a different application than the intended target.
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier
            else {
                self?.model.message = "Copied. Focus changed before the paste command."
                return
            }
            guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true),
                  let up = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false)
            else { return }
            down.flags = .maskCommand
            up.flags = .maskCommand
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
            onPosted?()
        }
    }

    @objc private func toggleMonitoring() {
        model.togglePaused()
        monitor?.isPaused = model.isPaused
    }

    @objc private func confirmClear() {
        let alert = NSAlert()
        alert.messageText = "Clear all clipboard history?"
        alert.informativeText = "This permanently deletes all items, including pinned clips. This cannot be undone."
        alert.addButton(withTitle: "Clear History")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn { model.clearHistory() }
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

/// Carbon hotkeys work without Input Monitoring permission.
private final class ClipboardGlobalHotkey {
    private var hotkeyReference: EventHotKeyRef?
    private var handlerReference: EventHandlerRef?
    private(set) var isRegistered = false
    private let callback: () -> Void

    init(callback: @escaping () -> Void) {
        self.callback = callback
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, pointer in
                guard let pointer else { return noErr }
                let owner = Unmanaged<ClipboardGlobalHotkey>.fromOpaque(pointer).takeUnretainedValue()
                DispatchQueue.main.async { owner.callback() }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerReference
        )
        guard installStatus == noErr else { return }
        let identifier = EventHotKeyID(signature: 0x434C4950, id: 1)
        let registrationStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(cmdKey | shiftKey),
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotkeyReference
        )
        isRegistered = registrationStatus == noErr
    }

    deinit {
        if let hotkeyReference { UnregisterEventHotKey(hotkeyReference) }
        if let handlerReference { RemoveEventHandler(handlerReference) }
    }
}
