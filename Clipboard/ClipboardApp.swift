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
        buildPanel()
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
            onPaste: { [weak self] item in self?.paste(item) }
        ))
        self.panel = panel
    }

    @objc private func openPanel() { showPanel() }

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
        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let available = screen.visibleFrame
            let origin = NSPoint(
                x: available.midX - panel.frame.width / 2,
                y: available.minY + 36
            )
            panel.setFrameOrigin(origin)
        }
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    private func hidePanel() {
        panel?.orderOut(nil)
    }

    private func paste(_ item: ClipItem) {
        guard model.copy(item) else { return }
        guard AXIsProcessTrusted() else {
            model.message = "To paste automatically, allow Clipboard in System Settings → Privacy & Security → Accessibility. The item has been copied."
            return
        }
        hidePanel()
        previousApp?.activate(options: [.activateIgnoringOtherApps])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true),
                  let up = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false)
            else { return }
            down.flags = .maskCommand
            up.flags = .maskCommand
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
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
    private let callback: () -> Void

    init(callback: @escaping () -> Void) {
        self.callback = callback
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
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
        let identifier = EventHotKeyID(signature: 0x434C4950, id: 1)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(cmdKey | shiftKey),
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotkeyReference
        )
    }

    deinit {
        if let hotkeyReference { UnregisterEventHotKey(hotkeyReference) }
        if let handlerReference { RemoveEventHandler(handlerReference) }
    }
}
