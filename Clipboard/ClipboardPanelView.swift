import AppKit
import SwiftUI

struct ClipboardPanelView: View {
    @ObservedObject var model: ClipboardModel
    let onDismiss: () -> Void
    let onPaste: (ClipItem) -> Void
    let onPasteNext: () -> Void

    @FocusState private var searchFocused: Bool
    @State private var showingSettings = false
    @State private var showingCollectionAlert = false
    @State private var newCollectionName = ""
    @State private var newCollectionItem: ClipItem?

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

                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .liquidToolbar()
                .help("Privacy and history settings")

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
                Menu {
                    Button("All Types") { model.selectedKind = nil }
                    Divider()
                    ForEach(ClipKind.allCases, id: \.self) { kind in
                        Button(kind.title) { model.selectedKind = kind }
                    }
                } label: {
                    Label(model.selectedKind?.title ?? "All Types", systemImage: "line.3.horizontal.decrease")
                }
                .menuStyle(.borderlessButton)
                .frame(maxWidth: 120)

                Menu {
                    Button("All Collections") { model.selectedCollection = nil }
                    if !model.collections.isEmpty {
                        Divider()
                        ForEach(model.collections, id: \.self) { name in
                            Button(name) { model.selectedCollection = name }
                        }
                    }
                } label: {
                    Label(model.selectedCollection ?? "Collections", systemImage: "folder")
                        .lineLimit(1)
                }
                .menuStyle(.borderlessButton)
                .frame(maxWidth: 185)
                Spacer()
                Button {
                    model.togglePaused()
                } label: {
                    Label(model.isPaused ? "Paused · Enable" : "Monitoring On",
                          systemImage: model.isPaused ? "pause.circle" : "checkmark.shield")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(model.isPaused ? "Start recording clipboard history" : "Pause clipboard recording")
            }
            .font(.system(size: 12, weight: .semibold))

            if model.clips.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 33))
                        .foregroundStyle(.secondary)
                    Text(model.searchText.isEmpty ? "Your clipboard history will appear here" : "No matching clips")
                        .font(.system(size: 14, weight: .medium))
                    Text(model.isPaused
                         ? "Monitoring is paused. Enable it above to begin."
                         : "Copy text, links, images, or files in another app.")
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
                                onQueue: { model.addToPasteStack(item) },
                                onDelete: { model.delete(item) },
                                collections: model.collections,
                                onMove: { name in model.move(item, toCollection: name) },
                                onNewCollection: {
                                    newCollectionItem = item
                                    newCollectionName = ""
                                    showingCollectionAlert = true
                                }
                            )
                        }
                    }
                    .padding(.vertical, 5)
                }
                .scrollIndicators(.hidden)
            }

            HStack {
                Label("⌘⇧V to open · ⌘1…9 to paste", systemImage: "keyboard")
                Spacer()
                Text("\(model.clips.count) clips")
                Spacer()
                if !model.pasteStack.isEmpty {
                    Button {
                        onPasteNext()
                    } label: {
                        Label("Paste Next (\(model.pasteStack.count))", systemImage: "square.stack")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Button("Clear Stack") { model.clearPasteStack() }
                        .buttonStyle(.link)
                } else {
                    Text("Stored on this Mac")
                }
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
        .frame(minWidth: 680, maxWidth: .infinity, minHeight: 445, maxHeight: 445)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(.white.opacity(0.20), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .onExitCommand(perform: onDismiss)
        .onChange(of: model.panelPresentationID) { _, _ in
            searchFocused = true
        }
        .onChange(of: model.settingsPresentationID) { _, _ in
            showingSettings = true
        }
        .onKeyPress { press in
            guard press.phase == .down,
                  press.modifiers.contains(.command),
                  let digit = Int(press.characters),
                  (1...9).contains(digit),
                  model.clips.indices.contains(digit - 1)
            else { return .ignored }
            onPaste(model.clips[digit - 1])
            return .handled
        }
        .sheet(isPresented: $showingSettings) {
            ClipboardSettingsView(model: model)
        }
        .alert("New Collection", isPresented: $showingCollectionAlert) {
            TextField("Collection name", text: $newCollectionName)
            Button("Create") {
                if let newCollectionItem {
                    model.move(newCollectionItem, toCollection: newCollectionName)
                }
                newCollectionItem = nil
            }
            Button("Cancel", role: .cancel) { newCollectionItem = nil }
        } message: {
            Text("Give this collection a name, up to 60 characters.")
        }
    }
}

private struct ClipCard: View {
    let item: ClipItem
    let assetURL: URL?
    let onCopy: () -> Void
    let onPaste: () -> Void
    let onPin: () -> Void
    let onQueue: () -> Void
    let onDelete: () -> Void
    let collections: [String]
    let onMove: (String?) -> Void
    let onNewCollection: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: item.kind.symbol)
                    .foregroundStyle(.mint)
                Text(item.kind.title)
                    .fontWeight(.semibold)
                if let collection = item.collection {
                    Text(collection)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
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
                    Button("Add to Paste Stack", action: onQueue)
                    Divider()
                    Button(item.pinned ? "Unpin" : "Pin", action: onPin)
                    Menu("Move to Collection") {
                        Button("Unassigned") { onMove(nil) }
                        if !collections.isEmpty {
                            Divider()
                            ForEach(collections, id: \.self) { name in
                                Button(name) { onMove(name) }
                            }
                        }
                        Divider()
                        Button("New Collection…", action: onNewCollection)
                    }
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
            Section("Monitoring and Privacy") {
                Toggle("Pause clipboard monitoring", isOn: Binding(
                    get: { model.isPaused },
                    set: { _ in model.togglePaused() }
                ))
                Text("Clipboard history is stored locally, without at-rest encryption. Password-manager and private pasteboard exclusions are best-effort, not a guarantee.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("Ignore these app bundle IDs (one per line):")
                    .font(.callout.weight(.medium))
                TextEditor(text: $model.excludedAppsText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(height: 88)
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(.secondary.opacity(0.25))
                    }
                Text("Example: com.example.BankingApp. You can find the bundle ID of an installed app in Finder or its Info.plist.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Capture") {
                Toggle("Save images", isOn: $model.captureImages)
                Toggle("Save files and file selections", isOn: $model.captureFiles)
                Text("Copied text and links are always captured while monitoring is on. Image and file capture can be turned off.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Retention") {
                Stepper("Keep at most \(model.retentionCount) unpinned clips",
                        value: $model.retentionCount, in: 50...5000, step: 50)
                Stepper("Delete unpinned clips after \(model.retentionDays) days",
                        value: $model.retentionDays, in: 1...365)
                Text("Pinned clips are excluded from automatic cleanup. Updating these controls prunes old unpinned clips immediately.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Shortcuts") {
                Text("⌘⇧V opens the shelf. ⌘1 through ⌘9 paste a visible clip.")
                Text("Automatic paste requires macOS Accessibility permission; copying does not.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 615, height: 560)
    }
}
