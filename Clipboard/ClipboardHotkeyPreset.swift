import Foundation
import Carbon

/// Presets avoid requesting Input Monitoring to implement a hotkey recorder.
enum ClipboardHotkeyPreset: String, CaseIterable, Identifiable {
    case commandShiftV
    case commandOptionV
    case controlOptionV
    case controlShiftV
    case optionShiftV

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .commandShiftV: return "⌘⇧V"
        case .commandOptionV: return "⌘⌥V"
        case .controlOptionV: return "⌃⌥V"
        case .controlShiftV: return "⌃⇧V"
        case .optionShiftV: return "⌥⇧V"
        }
    }

    var keyCode: UInt32 { UInt32(kVK_ANSI_V) }

    var carbonModifiers: UInt32 {
        switch self {
        case .commandShiftV: return UInt32(cmdKey | shiftKey)
        case .commandOptionV: return UInt32(cmdKey | optionKey)
        case .controlOptionV: return UInt32(controlKey | optionKey)
        case .controlShiftV: return UInt32(controlKey | shiftKey)
        case .optionShiftV: return UInt32(optionKey | shiftKey)
        }
    }
}
