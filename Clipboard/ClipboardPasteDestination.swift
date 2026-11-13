import Foundation

/// Pure routing policy for the quick-paste target, independently unit-testable
/// without Accessibility or a real graphical desktop session.
enum ClipboardPasteDestination {
    static func choose(
        frontmostPID: pid_t?, fallbackPID: pid_t?, ownPID: pid_t
    ) -> pid_t? {
        if let frontmostPID, frontmostPID > 0, frontmostPID != ownPID {
            return frontmostPID
        }
        if let fallbackPID, fallbackPID > 0, fallbackPID != ownPID {
            return fallbackPID
        }
        return nil
    }

    /// Never post to Clipboard itself or to an unrelated foreground process.
    /// If no process is frontmost (e.g. during Space transitions), keep waiting.
    static func mayPost(
        targetPID: pid_t, frontmostPID: pid_t?, ownPID: pid_t
    ) -> Bool {
        targetPID > 0 &&
        targetPID != ownPID &&
        frontmostPID == targetPID
    }

    /// Allow app activation to settle before sending an actual session shortcut.
    /// Never resend after a successful dispatch; blindly retrying duplicates text.
    static let maximumActivationAttempts = 12
    static let activationRetryInterval: TimeInterval = 0.085

    static func mayRetryActivation(after attempt: Int) -> Bool {
        attempt < maximumActivationAttempts
    }
}
