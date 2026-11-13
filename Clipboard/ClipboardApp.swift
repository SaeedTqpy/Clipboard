import AppKit
import SwiftUI
import Carbon
import ApplicationServices
import QuartzCore

@main
struct ClipboardApp: App {
    @NSApplicationDelegateAdaptor(ClipboardAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            ClipboardSettingsView(model: .shared)
        }
    }
}

enum ClipboardEntrySource {
    case keyboardShortcut
    case menuBarClick

    var presentation: ClipboardPanelPresentation {
        switch self {
        case .keyboardShortcut: return .shelf
        case .menuBarClick: return .management
        }
    }
}

private enum ClipboardPanelNavigation {
    case earlier, later, paste, pastePlain, togglePin, delete, quick(Int)
}

private final class ClipboardFloatingPanel: NSPanel {
    var navigationHandler: ((ClipboardPanelNavigation) -> Bool)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// NSPanel intercepts navigation before NSTextField consumes Return/arrow keys.
    /// Left/right are left available for cursor editing in the search field.
    override func sendEvent(_ event: NSEvent) {
        guard event.type == .keyDown, attachedSheet == nil else {
            super.sendEvent(event)
            return
        }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let command = flags.contains(.command)
        let option = flags.contains(.option)
        let control = flags.contains(.control)
        let shift = flags.contains(.shift)
        var action: ClipboardPanelNavigation?

        if !command && !control && !shift {
            switch event.keyCode {
            case 125: action = .later                  // Down
            case 126: action = .earlier                // Up
            case 36, 76: action = option ? .pastePlain : .paste
            default: break
            }
        }
        if command && !option && !control && !shift {
            if event.keyCode == 35 { action = .togglePin } // Cmd+P
            if event.keyCode == 51 { action = .delete }    // Cmd+Backspace
            if let number = Int(event.charactersIgnoringModifiers ?? ""),
               (1...9).contains(number) {
                action = .quick(number - 1)
            }
        }
        if let action, navigationHandler?(action) == true { return }
        super.sendEvent(event)
    }
}

@MainActor
final class ClipboardAppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let model = ClipboardModel.shared
    private var statusItem: NSStatusItem?
    private var panel: ClipboardFloatingPanel?
    private var managementWindow: NSWindow?
    private let statusContextMenu = NSMenu()
    private var monitor: ClipboardMonitor?
    private var hotkey: ClipboardGlobalHotkey?
    private var outsideClickMonitor: Any?
    private var previousApp: NSRunningApplication?
    private var panelTransitionID = 0
    private var isClosingShelf = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // A previous unsigned build may still be running from Downloads or
        // another Applications folder. Request its normal termination so it
        // cannot keep a second shelf/hotkey alive after updating.
        if let identifier = Bundle.main.bundleIdentifier {
            let duplicates = NSWorkspace.shared.runningApplications.filter {
                $0.bundleIdentifier == identifier &&
                    $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
            }
            for older in duplicates where !older.isTerminated {
                _ = older.terminate()
            }
        }

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

        let statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength
        )
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "doc.on.clipboard",
                accessibilityDescription: "Manage Clipboard"
            )
            button.toolTip = "Manage Clipboard (right-click for actions)"
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        // No statusItem.menu assignment! AppKit bypasses the click action
        // whenever this property is set. Left-click opens the manager;
        // right-click explicitly presents the contextual menu.
        statusContextMenu.delegate = self
        self.statusItem = statusItem

        installInitialHotkey()
        model.onHotkeyChange = { [weak self] preset in
            self?.registerHotkey(preset) ?? false
        }
        buildPanel()
        buildManagementWindow()
        let onboardingKey = "clipboard.hasOpenedOnce"
        if UserDefaults.standard.object(forKey: onboardingKey) == nil {
            UserDefaults.standard.set(true, forKey: onboardingKey)
            DispatchQueue.main.async { [weak self] in self?.showManagementWindow() }
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(NSMenuItem(
            title: "Manage Clipboard",
            action: #selector(openManager), keyEquivalent: ""
        ))
        menu.addItem(NSMenuItem(
            title: "Open Quick Shelf  \(model.hotkeyPreset.displayName)",
            action: #selector(openPanel), keyEquivalent: ""
        ))
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
        let rect = NSRect(x: 0, y: 0, width: 1100, height: 360)
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
        panel.hasShadow = false
        panel.animationBehavior = .none
        panel.isMovableByWindowBackground = false
        panel.navigationHandler = { [weak self] action in
            self?.handleNavigation(action) ?? false
        }
        panel.contentView = NSHostingView(rootView: ClipboardPanelView(
            model: model,
            presentation: .shelf,
            onDismiss: { [weak self] in self?.hidePanel() },
            onPaste: { [weak self] item in self?.paste(item) },
            onPastePlain: { [weak self] item in self?.paste(item, asPlainText: true) },
            onPasteNext: { [weak self] in self?.pasteStackNext() }
        ))
        self.panel = panel
    }

    private func buildManagementWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1050, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Clipboard — Manager"
        window.minSize = NSSize(width: 720, height: 445)
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: ClipboardPanelView(
            model: model,
            presentation: .management,
            onDismiss: { [weak window] in window?.orderOut(nil) },
            onPaste: { [weak self] item in self?.paste(item) },
            onPastePlain: { [weak self] item in self?.paste(item, asPlainText: true) },
            onPasteNext: { [weak self] in self?.pasteStackNext() }
        ))
        managementWindow = window
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            statusContextMenu.popUp(
                positioning: nil,
                at: NSPoint(x: 0, y: sender.bounds.minY),
                in: sender
            )
        } else {
            open(entry: .menuBarClick)
        }
    }

    private func open(entry: ClipboardEntrySource) {
        switch entry.presentation {
        case .shelf: togglePanel()
        case .management: showManagementWindow()
        }
    }

    private func installInitialHotkey(attempt: Int = 0) {
        let registration = ClipboardGlobalHotkey(
            preset: model.hotkeyPreset
        ) { [weak self] in
            self?.open(entry: .keyboardShortcut)
        }
        if registration.isRegistered {
            hotkey = registration
            return
        }
        // Older Clipboard processes need a short moment to unregister
        // Carbon hotkeys after the termination request at startup.
        if attempt < 4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                self?.installInitialHotkey(attempt: attempt + 1)
            }
        } else {
            model.message = "Shortcut \(model.hotkeyPreset.displayName) could not register. Quit older Clipboard instances, then relaunch or choose another shortcut."
        }
    }

    private func showManagementWindow() {
        guard let managementWindow else { return }
        let foreground = NSWorkspace.shared.frontmostApplication
        if foreground?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp = foreground
        }
        // There is exactly one visible Clipboard surface at any time.
        hidePanelImmediately()
        NSApp.activate(ignoringOtherApps: true)
        managementWindow.makeKeyAndOrderFront(nil)
        model.managerPresentationID &+= 1
    }

    @objc private func openManager() { showManagementWindow() }
    @objc private func openPanel() { showPanel() }

    @objc private func openSettings() {
        showManagementWindow()
        model.settingsPresentationID &+= 1
    }

    private func togglePanel() {
        guard let panel else { return }
        if panel.isVisible && !isClosingShelf { hidePanel() } else { showPanel() }
    }

    private func showPanel() {
        guard let panel else { return }
        if panel.isVisible && !isClosingShelf {
            model.panelPresentationID &+= 1
            return
        }
        let foreground = NSWorkspace.shared.frontmostApplication
        if foreground?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp = foreground
        }
        // A keyboard shortcut must never reveal the manager as a second window.
        managementWindow?.orderOut(nil)
        model.searchText = ""
        guard let screen = NSScreen.screens.first(where: {
            $0.frame.contains(NSEvent.mouseLocation)
        }) ?? NSScreen.main ?? NSScreen.screens.first else { return }

        // Physically flush with the display, not with NSScreen.visibleFrame.
        // The latter excludes the Dock and caused the visible lower gap.
        let target = ClipboardShelfLayout.frame(
            in: screen.frame, visibleFrame: screen.visibleFrame
        )
        model.shelfBottomInset = ClipboardShelfLayout.bottomContentInset(
            screenFrame: screen.frame, visibleFrame: screen.visibleFrame
        )
        panelTransitionID &+= 1
        isClosingShelf = false
        let reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        if reducedMotion {
            panel.setFrame(target, display: true)
            panel.alphaValue = 1
            panel.orderFrontRegardless()
        } else {
            let start = ClipboardShelfLayout.hiddenFrame(
                for: target, displayFrame: screen.frame
            )
            panel.setFrame(start, display: true)
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.38
                context.timingFunction = CAMediaTimingFunction(
                    controlPoints: 0.20, 0.82, 0.18, 1.0
                )
                panel.animator().setFrame(target, display: true)
                panel.animator().alphaValue = 1
            }
        }
        panel.makeKey()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
            guard let self, !self.isClosingShelf else { return }
            self.model.panelPresentationID &+= 1
        }
        if outsideClickMonitor == nil {
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.hidePanel() }
            }
        }
    }

    private func hidePanel() {
        guard let panel, panel.isVisible, !isClosingShelf else { return }
        panelTransitionID &+= 1
        let token = panelTransitionID
        isClosingShelf = true
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
              let screen = panel.screen ?? NSScreen.main else {
            panel.orderOut(nil)
            panel.alphaValue = 1
            return
        }

        let hidden = ClipboardShelfLayout.hiddenFrame(
            for: panel.frame, displayFrame: screen.frame
        )
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(hidden, display: true)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self, weak panel] in
            guard let self, self.panelTransitionID == token else { return }
            panel?.orderOut(nil)
            panel?.alphaValue = 1
        })
    }

    private func hidePanelImmediately() {
        panelTransitionID &+= 1
        isClosingShelf = false
        panel?.orderOut(nil)
        panel?.alphaValue = 1
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }

    private func registerHotkey(_ preset: ClipboardHotkeyPreset) -> Bool {
        // Register replacement before dropping the old shortcut; failure is reversible.
        let replacement = ClipboardGlobalHotkey(preset: preset) { [weak self] in
            self?.open(entry: .keyboardShortcut)
        }
        guard replacement.isRegistered else { return false }
        hotkey = replacement
        statusItem?.button?.toolTip =
            "Manage Clipboard (Quick Shelf: \(preset.displayName))"
        return true
    }

    private func handleNavigation(_ action: ClipboardPanelNavigation) -> Bool {
        switch action {
        case .earlier: return model.navigate(-1)
        case .later: return model.navigate(1)
        case .paste:
            guard let item = model.selectedClip else { return false }
            paste(item)
        case .pastePlain:
            guard let item = model.selectedClip else { return false }
            paste(item, asPlainText: true)
        case .quick(let index):
            guard model.clips.indices.contains(index) else { return false }
            paste(model.clips[index])
        case .togglePin:
            guard let item = model.selectedClip else { return false }
            model.togglePinned(item)
        case .delete:
            guard let item = model.selectedClip else { return false }
            let alert = NSAlert()
            alert.messageText = "Delete selected clipboard item?"
            alert.informativeText = "This cannot be undone."
            alert.addButton(withTitle: "Delete")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn { model.delete(item) }
        }
        return true
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
            hidePanelImmediately()
            return
        }
        guard let target = previousApp, !target.isTerminated,
              target.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            model.message = "Copied. No previous application is available for automatic paste."
            hidePanelImmediately()
            return
        }
        // Paste must release the key panel immediately before restoring focus.
        // Keyboard delivery takes priority over the decorative close animation.
        hidePanelImmediately()
        guard target.activate(options: []) else {
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

    init(preset: ClipboardHotkeyPreset, callback: @escaping () -> Void) {
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
            preset.keyCode,
            preset.carbonModifiers,
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
