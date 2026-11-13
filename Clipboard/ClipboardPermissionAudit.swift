import AppKit
import ApplicationServices
import CoreGraphics

/// Read-only, privacy-safe TCC identity diagnostics.
/// The current executable must match the code identity granted in System Settings.
enum ClipboardPermissionAudit {
    enum InstallLocation: String {
        case applications = "Applications"
        case translocated = "App Translocation (move to Applications)"
        case other = "Other directory (install in /Applications)"
    }

    enum Signature: String {
        case adHoc = "Ad-hoc: version-specific TCC identity"
        case certificate = "Certificate-signed: verify signer"
        case unsigned = "Unsigned or invalid: TCC identity unavailable"
        case unknown = "Could not inspect signature"
    }

    static func installLocation(for path: String) -> InstallLocation {
        if path.contains("/AppTranslocation/") { return .translocated }
        if path == "/Applications/Clipboard.app" { return .applications }
        return .other
    }

    static func classifySignature(_ output: String, exitCode: Int32) -> Signature {
        guard exitCode == 0 else { return .unsigned }
        if output.contains("Signature=adhoc") { return .adHoc }
        if output.contains("Authority=") { return .certificate }
        return .unknown
    }

    /// Launches codesign only for a user-requested diagnostic snapshot.
    /// This runs no shell command and never reads clipboard contents.
    static func signature() -> Signature {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        task.arguments = ["--display", "--verbose=4", Bundle.main.bundleURL.path]
        let output = Pipe()
        task.standardOutput = output
        task.standardError = output
        do {
            try task.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            return classifySignature(
                String(decoding: data, as: UTF8.self),
                exitCode: task.terminationStatus
            )
        } catch {
            return .unknown
        }
    }

    static func summary() -> String {
        let location = installLocation(
            for: Bundle.main.bundleURL.standardizedFileURL.path
        )
        let bundleID = Bundle.main.bundleIdentifier ?? "unknown"
        return """
        Bundle ID: \(bundleID)
        Running location: \(location.rawValue)
        Code signature: \(signature().rawValue)
        Accessibility (AX): \(AXIsProcessTrusted())
        Event Posting (PostEvent): \(CGPreflightPostEventAccess())
        AX and PostEvent are distinct TCC permissions.
        If AX=true but PostEvent=false, use Request Event Posting Access in Settings.
        If denied persistently: quit Clipboard; run tccutil reset PostEvent dev.clipboard.app; relaunch and request PostEvent.
        A green system toggle for an older binary is not proof of TCC trust.
        """
    }
}
