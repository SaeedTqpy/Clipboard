/// The AXUIElement permission and Quartz keyboard-event posting permission are
/// independently evaluated by macOS TCC. One may be granted while the other is
/// denied, even when the same app appears enabled in Accessibility settings.
enum ClipboardPastePermissionPolicy {
    enum Missing: Equatable {
        case none
        case accessibility
        case postEvent
        case both
    }

    static func missing(accessibility: Bool, postEvent: Bool) -> Missing {
        switch (accessibility, postEvent) {
        case (true, true): return .none
        case (false, true): return .accessibility
        case (true, false): return .postEvent
        case (false, false): return .both
        }
    }

    static func diagnostics(_ missing: Missing) -> String {
        switch missing {
        case .none: return "P0 · Both keyboard permissions granted"
        case .accessibility: return "E3A · Accessibility permission denied"
        case .postEvent: return "E3P · PostEvent permission denied (AX may be allowed)"
        case .both: return "E3B · Accessibility and PostEvent denied"
        }
    }

    static func message(_ missing: Missing) -> String {
        switch missing {
        case .none:
            return "Both Accessibility and PostEvent permissions are available."
        case .accessibility:
            return "Copied, not pasted. Accessibility is not approved for this build. Open System Settings → Privacy & Security → Accessibility, enable this exact Clipboard app and relaunch."
        case .postEvent:
            return "Copied, not pasted. Accessibility is ON, but macOS separately DENIED PostEvent (sending keystrokes). In Settings → Paste Diagnostics choose Request Event Posting Access. If it stays denied, quit Clipboard, run 'tccutil reset PostEvent dev.clipboard.app' in Terminal, relaunch, and request Event Posting again. No sudo or Input Monitoring is needed."
        case .both:
            return "Copied, not pasted. Accessibility and PostEvent are denied. Authorize Clipboard in Accessibility, use Request Event Posting Access in Settings, and relaunch. If PostEvent remains false, reset ONLY PostEvent for dev.clipboard.app."
        }
    }
}
