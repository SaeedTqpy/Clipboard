import AppKit
import ApplicationServices
import CoreGraphics
import SwiftUI

/// First-install permission flow for the real PostEvent service.
/// This view never modifies the TCC database or runs Terminal commands.
enum ClipboardQuickPasteSetupPolicy {
    static func shouldPresentOnFirstLaunch(
        hasOpenedBefore: Bool, canPostEvents: Bool
    ) -> Bool {
        !hasOpenedBefore && !canPostEvents
    }
}

struct ClipboardQuickPasteSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var canPostEvents = false
    @State private var axTrusted = false
    @State private var didRequest = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: "keyboard.badge.ellipsis")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.cyan)
                    .frame(width: 56, height: 56)
                    .background(.cyan.opacity(0.13),
                                in: RoundedRectangle(cornerRadius: 18))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable Quick Paste")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("One permission. No Terminal required for first setup.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Clipboard can always save and copy items. To paste directly into another app, macOS must let Clipboard send a Command-V key event.")
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Label("Keyboard event posting", systemImage:
                    canPostEvents ? "checkmark.shield.fill" : "shield.lefthalf.filled")
                    .foregroundStyle(canPostEvents ? .green : .orange)
                Spacer()
                Text(canPostEvents ? "Allowed" : "Needs approval")
                    .foregroundStyle(canPostEvents ? .green : .secondary)
            }
            .font(.system(size: 13, weight: .semibold))
            .padding(14)
            .background(.thinMaterial,
                        in: RoundedRectangle(cornerRadius: 12))

            if canPostEvents {
                Label("Quick Paste is ready. You can now use the keyboard shortcut and click any clip to paste.", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.green)
            } else if didRequest {
                Text("If macOS did not show a permission prompt, open System Settings → Privacy & Security → Accessibility, check Clipboard, then return here and refresh. A previously denied permission or a different app signature may require additional troubleshooting.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Your approval is required. This feature cannot be enabled automatically or by bypassing macOS security.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 9) {
                if !canPostEvents {
                    Button("Request Paste Access") {
                        didRequest = true
                        _ = CGRequestPostEventAccess()
                        refresh()
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Open Privacy Settings") {
                        let url = URL(string:
                            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                        )!
                        NSWorkspace.shared.open(url)
                    }
                    .buttonStyle(.bordered)
                }
                Button("Refresh") { refresh() }
                    .buttonStyle(.bordered)
                Spacer()
                Button(canPostEvents ? "Done" : "Continue with Copy Only") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }

            if !axTrusted && !canPostEvents {
                Text("Accessibility and event posting have separate macOS permission checks. Only event posting is required to send Command-V.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(26)
        .frame(width: 610)
        .onAppear(perform: refresh)
    }

    private func refresh() {
        canPostEvents = CGPreflightPostEventAccess()
        axTrusted = AXIsProcessTrusted()
    }
}
