import AppKit
import SwiftUI

struct ClipboardPanelView: View {
    @ObservedObject var model: ClipboardModel
    let onDismiss: () -> Void
    let onPaste: (ClipItem) -> Void

    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "square.on.square")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.mint)
                Text("Clipboard")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("History")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search your clipboard…", text: $model.searchText)
                        .textFieldStyle(.plain)
                        .focused($searchFocused)
                        .font(.system(size: 13))
                        .frame(width: 240)
                }
                .padding(.horizontal, 12)
                .frame(height: 36)
                .liquidToolbar()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .liquidToolbar()
                .help("Close")
            }

            HStack(spacing: 12) {
                Button {
                    model.pinnedOnly = false
                } label: {
                    Label("All Clips", systemImage: "square.stack.3d.up")
                }
                .buttonStyle(.plain)
                .foregroundStyle(model.pinnedOnly ? .secondary : .primary)

                Button {
                    model.pinnedOnly = true
                } label: {
                    Label("Pinned", systemImage: "pin.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(model.pinnedOnly ? .primary : .secondary)
                Spacer()
                Label(model.isPaused ? "Paused" : "Local only", systemImage: model.isPaused ? "pause.circle" : "lock.shield")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 12, weight: .semibold))

            if model.clips.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 33))
                        .foregroundStyle(.secondary)
                    Text(model.searchText.isEmpty ? "Your clipboard history will appear here" : "No matching clips")
                        .font(.system(size: 14, weight: .medium))
                    Text("Copy text, links, images, or files in another app.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 12) {
                        ForEach(model.clips) { item in
                            ClipCard(
                                item: item,
                                assetURL: model.assetURL(for: item),
                                onCopy: { _ = model.copy(item) },
                                onPaste: { onPaste(item) },
                                onPin: { model.togglePinned(item) },
                                onDelete: { model.delete(item) }
                            )
                        }
                    }
                    .padding(.vertical, 5)
                }
                .scrollIndicators(.hidden)
            }

            HStack {
                Label("⌘⇧V to open", systemImage: "keyboard")
                Spacer()
                Text("\(model.clips.count) clips")
                Spacer()
                Text("Stored on this Mac")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.tertiary)

            if let message = model.message {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                    Text(message).lineLimit(2)
                    Spacer(minLength: 0)
                    Button("Dismiss") { model.message = nil }
                        .buttonStyle(.link)
                }
                .font(.system(size: 11))
                .padding(8)
                .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
            }
        }
        .padding(22)
        .frame(width: 1050, height: 445)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.94))
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(.white.opacity(0.16), lineWidth: 1)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .onExitCommand(perform: onDismiss)
    }
}

private struct ClipCard: View {
    let item: ClipItem
    let assetURL: URL?
    let onCopy: () -> Void
    let onPaste: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: item.kind.symbol)
                    .foregroundStyle(.mint)
                Text(item.kind.title)
                    .fontWeight(.semibold)
                Spacer()
                if item.pinned {
                    Image(systemName: "pin.fill")
                        .foregroundStyle(.yellow)
                }
            }
            .font(.system(size: 12))

            Group {
                if item.kind == .image, let assetURL,
                   let image = NSImage(contentsOf: assetURL) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text(item.preview)
                        .font(.system(size: item.kind == .link ? 13 : 14, design: .rounded))
                        .lineLimit(7)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .frame(height: 143)

            HStack {
                Text(item.sourceApp)
                    .lineLimit(1)
                Spacer()
                Text(item.createdAt, style: .relative)
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)

            HStack(spacing: 7) {
                Button("Copy", action: onCopy)
                    .buttonStyle(.bordered)
                Button("Paste", action: onPaste)
                    .buttonStyle(.borderedProminent)
                    .tint(.mint)
                Spacer(minLength: 0)
                Menu {
                    Button(item.pinned ? "Unpin" : "Pin", action: onPin)
                    Divider()
                    Button("Delete", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 26)
            }
            .controlSize(.small)
        }
        .padding(14)
        .frame(width: 242, height: 257)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.90), in: RoundedRectangle(cornerRadius: 17))
        .overlay {
            RoundedRectangle(cornerRadius: 17)
                .strokeBorder(.white.opacity(0.07), lineWidth: 1)
        }
    }
}

private extension View {
    @ViewBuilder
    func liquidToolbar() -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

struct ClipboardSettingsView: View {
    @ObservedObject var model: ClipboardModel

    var body: some View {
        Form {
            Toggle("Pause clipboard monitoring", isOn: Binding(
                get: { model.isPaused },
                set: { _ in model.togglePaused() }
            ))
            Text("History is stored only on this Mac. Clipboard excludes concealed and transient pasteboard items and known password-manager apps.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Shortcut: Command + Shift + V")
            Text("Retention: 30 days and up to 1,000 unpinned clips.")
        }
        .padding(20)
        .frame(width: 520)
    }
}
