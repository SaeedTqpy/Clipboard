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
        // Automatic paste only synthesizes a CGEvent. It never queries or
        // modifies AXUIElement state, so PostEvent is the required grant.
        // AX status is still reported separately for diagnostics.
        case (false, true): return .none
        case (true, false): return .postEvent
        case (false, false): return .both
        }
    }

    static func diagnostics(_ missing: Missing) -> String {
        switch missing {
        case .none: return "P0 · PostEvent keyboard permission granted"
        case .accessibility: return "E3A · Accessibility permission denied"
        case .postEvent: return "E3P · PostEvent permission denied (AX may be allowed)"
        case .both: return "E3B · Accessibility and PostEvent denied"
        }
    }

    static func message(_ missing: Missing) -> String {
        switch missing {
        case .none:
            return "PostEvent permission is available for keyboard paste."
        case .accessibility:
            return "Accessibility is denied, but PostEvent permission is available; CGEvent paste does not need AXUIElement access."
        case .postEvent:
            return "Copied, not pasted. Accessibility is ON, but macOS separately DENIED PostEvent (sending keystrokes). In Settings → Paste Diagnostics choose Request Event Posting Access. If it stays denied, quit Clipboard, run 'tccutil reset PostEvent dev.clipboard.app' in Terminal, relaunch, and request Event Posting again. No sudo or Input Monitoring is needed."
        case .both:
            return "Copied, not pasted. PostEvent keyboard permission is denied (Accessibility is also false). In Settings choose Request Event Posting Access. If it stays denied, quit Clipboard, run 'tccutil reset PostEvent dev.clipboard.app', relaunch and request permission again. AXUIElement permission is not required just to send Command-V."
        }
    }
}
