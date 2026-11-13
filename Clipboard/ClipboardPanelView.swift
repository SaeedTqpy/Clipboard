import AppKit
import SwiftUI
import ApplicationServices
import UniformTypeIdentifiers

enum ClipboardPanelPresentation: Equatable {
    case shelf
    case management
}

struct ClipboardPanelView: View {
    @ObservedObject var model: ClipboardModel
    let presentation: ClipboardPanelPresentation
    let onDismiss: () -> Void
    let onPaste: (ClipItem) -> Void
    let onPastePlain: (ClipItem) -> Void
    let onPasteNext: () -> Void

    @FocusState private var searchFocused: Bool
    @State private var showingSettings = false
    @State private var showingCollectionAlert = false
    @State private var newCollectionName = ""
    @State private var newCollectionItem: ClipItem?
    @State private var editingClip: ClipItem?
    @State private var creatingSnippet = false
    @State private var tagSheet: ClipboardTagSheet?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                        .frame(minWidth: 110, maxWidth: 240)
                }
                .padding(.horizontal, 12)
                .frame(height: 36)
                .liquidToolbar()

                Button {
                    creatingSnippet = true
                } label: {
                    Image(systemName: "plus.square.on.square")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .liquidToolbar()
                .help("Create a reusable snippet")

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

            HStack(spacing: 10) {
                ScrollView(.horizontal) {
                    HStack(spacing: 16) {
                        Button {
                            model.pinnedOnly = false
                        } label: {
                            Label("All Clips", systemImage: "square.stack.3d.up")
                        }
                        .foregroundStyle(model.pinnedOnly ? .secondary : .primary)

                        Button {
                            model.pinnedOnly = true
                        } label: {
                            Label("Pinned", systemImage: "pin.fill")
                        }
                        .foregroundStyle(model.pinnedOnly ? .secondary : .primary)

                        Menu {
                            Button("All Content Types") { model.selectedKind = nil }
                            ForEach(ClipKind.allCases, id: \.self) { kind in
                                Button(kind.title) { model.selectedKind = kind }
                            }
                            Divider()
                            Menu("Source Application") {
                                Button("All Applications") { model.selectedSourceApp = nil }
                                ForEach(model.sourceApps, id: \.self) { app in
                                    Button(app) { model.selectedSourceApp = app }
                                }
                            }
                            Menu("Date") {
                                ForEach(ClipboardHistoryPeriod.allCases) { period in
                                    Button(period.rawValue) { model.historyPeriod = period }
                                }
                            }
                            Button("Reset Filters") {
                                model.selectedKind = nil
                                model.selectedSourceApp = nil
                                model.historyPeriod = .all
                                model.selectedCollection = nil
                                model.selectedTagID = nil
                                model.pinnedOnly = false
                            }
                        } label: {
                            Label(model.selectedKind?.title ?? "Filters",
                                  systemImage: "line.3.horizontal.decrease")
                        }
                        .frame(maxWidth: 130)

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
                        .frame(maxWidth: 190)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
                Button {
                    model.togglePaused()
                } label: {
                    Label(model.isPaused ? "Paused · Enable" : "Monitoring On",
                          systemImage: model.isPaused ? "pause.circle" : "checkmark.shield")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .fixedSize()
                .help(model.isPaused ? "Start recording clipboard history" : "Pause clipboard recording")
            }
            .font(.system(size: 11, weight: .semibold))

            HStack(spacing: 9) {
                Text("TAGS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal) {
                    HStack(spacing: 7) {
                        Button {
                            model.selectedTagID = nil
                        } label: {
                            Text("All")
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 5)
                                .background(
                                    model.selectedTagID == nil
                                        ? Color.accentColor.opacity(0.21)
                                        : Color.primary.opacity(0.06),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)

                        ForEach(model.tags) { tag in
                            Button {
                                model.selectedTagID =
                                    model.selectedTagID == tag.id ? nil : tag.id
                            } label: {
                                ClipTagPill(tag: tag, selected: model.selectedTagID == tag.id)
                            }
                            .buttonStyle(.plain)
                            .fixedSize()
                            .contextMenu {
                                Button("Edit \(tag.name)…") { tagSheet = .edit(tag) }
                            }
                        }

                        if model.tags.isEmpty {
                            Text("Add a colored tag from a card's menu")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 3)
                }
                .scrollIndicators(.hidden)
            }
            .frame(height: 28)

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
                ScrollViewReader { scrollProxy in
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 12) {
                            ForEach(model.clips) { item in
                                ClipCard(
                                    item: item,
                                    isSelected: item.id == model.selectedClipID,
                                    thumbnailSource: model.thumbnailSource(for: item),
                                    onCopy: { _ = model.copy(item) },
                                    onPaste: { onPaste(item) },
                                    onPastePlain: { onPastePlain(item) },
                                    onPin: { model.togglePinned(item) },
                                    onQueue: { model.addToPasteStack(item) },
                                    onDelete: { model.delete(item) },
                                    onEdit: { editingClip = item },
                                    onSaveSnippet: {
                                        model.saveAsSnippet(
                                            item, title: item.displayName ?? item.preview
                                        )
                                    },
                                    onCopyRecognizedText: {
                                        model.copyRecognizedText(item)
                                    },
                                    onSelect: { model.selectedClipID = item.id },
                                    tags: model.tags,
                                    onApplyTag: { tag in model.attachTag(tag, to: item) },
                                    onRemoveTag: { id in model.detachTag(id, from: item) },
                                    onCreateTag: { tagSheet = .create(item) },
                                    collections: model.collections,
                                    onMove: { name in model.move(item, toCollection: name) },
                                    onNewCollection: {
                                        newCollectionItem = item
                                        newCollectionName = ""
                                        showingCollectionAlert = true
                                    }
                                )
                                .id(item.id)
                            }
                        }
                        .padding(.vertical, 5)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: model.selectedClipID) { _, id in
                        if let id {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                scrollProxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                }
            }

            HStack {
                Label("↑↓ select · ↵ paste · ⌥↵ plain · ⌘1…9 quick",
                      systemImage: "keyboard")
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
        .modifier(ClipboardPanelChrome(
            presentation: presentation,
            bottomContentInset: presentation == .shelf ? model.shelfBottomInset : 0
        ))
        .onExitCommand(perform: onDismiss)
        .onChange(of: presentation == .shelf
                      ? model.panelPresentationID
                      : model.managerPresentationID) { _, _ in
            searchFocused = true
        }
        .onChange(of: model.settingsPresentationID) { _, _ in
            if presentation == .management {
                showingSettings = true
            }
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
        .sheet(item: $editingClip) { item in
            ClipboardClipEditorView(item: item) { title, content, asSnippet in
                model.edit(item, title: title, text: content, asSnippet: asSnippet)
            }
        }
        .sheet(isPresented: $creatingSnippet) {
            ClipboardNewSnippetView { title, content in
                model.createSnippet(title: title, body: content)
            }
        }
        .sheet(item: $tagSheet) { route in
            switch route {
            case .create(let item):
                ClipboardTagEditorView(editing: nil) { name, color in
                    model.attachTag(ClipTag(name: name, color: color), to: item)
                }
            case .edit(let tag):
                ClipboardTagEditorView(editing: tag) { name, color in
                    model.editTag(tag, name: name, color: color)
                }
            }
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

/// Unlike a floating window, the quick shelf has two square bottom corners,
/// no detached shadow, and material that meets the physical screen edge.
private struct ClipboardTopRoundedShape: Shape {
    var radius: CGFloat = 20

    func path(in rect: CGRect) -> Path {
        let r = min(radius, rect.width / 2, rect.height / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + r))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - r, y: rect.minY),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + r),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

private struct ClipboardPanelChrome: ViewModifier {
    let presentation: ClipboardPanelPresentation
    let bottomContentInset: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        switch presentation {
        case .shelf:
            content
                .padding(.horizontal, 19)
                .padding(.top, 12)
                .padding(.bottom, max(12, bottomContentInset + 10))
                .frame(minWidth: 300, maxWidth: .infinity,
                       minHeight: 280, maxHeight: .infinity)
                .background(.regularMaterial, in: ClipboardTopRoundedShape())
                .overlay {
                    ClipboardTopRoundedShape()
                        .stroke(.white.opacity(0.24), lineWidth: 1)
                }
                .clipShape(ClipboardTopRoundedShape())
        case .management:
            content
                .padding(20)
                .frame(minWidth: 640, maxWidth: .infinity,
                       minHeight: 420, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
        }
    }
}

private enum ClipboardTagSheet: Identifiable {
    case create(ClipItem)
    case edit(ClipTag)

    var id: String {
        switch self {
        case .create(let item): return "new:" + item.id
        case .edit(let tag): return "edit:" + tag.id
        }
    }
}

private struct ClipCard: View {
    let item: ClipItem
    let isSelected: Bool
    let thumbnailSource: ClipboardThumbnailSource?
    let onCopy: () -> Void
    let onPaste: () -> Void
    let onPastePlain: () -> Void
    let onPin: () -> Void
    let onQueue: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    let onSaveSnippet: () -> Void
    let onCopyRecognizedText: () -> Void
    let onSelect: () -> Void
    let tags: [ClipTag]
    let onApplyTag: (ClipTag) -> Void
    let onRemoveTag: (String) -> Void
    let onCreateTag: () -> Void
    let collections: [String]
    let onMove: (String?) -> Void
    let onNewCollection: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: item.kind.symbol)
                Text(item.kind.title.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                Spacer()
                Text(item.pinned ? "PINNED" : "RECENT")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .opacity(0.76)
                if item.pinned { Image(systemName: "pin.fill") }
            }
            .foregroundStyle(Color.black.opacity(0.89))
            .padding(.horizontal, 13)
            .frame(height: 34)
            .background(item.kind.ribbonColor)

            VStack(alignment: .leading, spacing: 6) {
                if let title = item.displayName {
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Group {
                    if item.kind == .color,
                       let rgba = ClipColor.hexValue(item.body ?? item.preview) {
                        VStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 9)
                                .fill(Color(red: rgba.red, green: rgba.green, blue: rgba.blue)
                                        .opacity(rgba.alpha))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 9)
                                        .strokeBorder(.primary.opacity(0.14))
                                }
                            Text(item.body ?? item.preview)
                                .font(.system(size: 11, design: .monospaced))
                        }
                    } else if item.kind == .image {
                        ClipboardThumbnailView(source: thumbnailSource)
                            .overlay(alignment: .bottomTrailing) {
                                if item.recognizedText != nil {
                                    Image(systemName: "text.viewfinder")
                                        .padding(4)
                                        .background(.regularMaterial, in: Circle())
                                }
                            }
                    } else {
                        Text(item.preview)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .lineLimit(item.displayName == nil ? 6 : 4)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity,
                                   alignment: .topLeading)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: item.displayName == nil ? 78 : 61)

                if !item.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(item.tags.prefix(2)) { tag in
                            ClipTagPill(tag: tag, selected: false)
                        }
                        if item.tags.count > 2 {
                            Text("+\(item.tags.count - 2)")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(height: 21)
                } else if let collection = item.collection {
                    Label(collection, systemImage: "folder")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(height: 21)
                } else {
                    Spacer(minLength: 21)
                        .frame(height: 21)
                }

                HStack {
                    Text(item.sourceApp)
                        .lineLimit(1)
                    Spacer()
                    Text(item.createdAt, style: .relative)
                        .lineLimit(1)
                }
                .font(.system(size: 9))
                .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Button("Copy", action: onCopy)
                        .buttonStyle(.bordered)
                        .help("Copy this clip to the system pasteboard")
                    Button("Paste", action: onPaste)
                        .buttonStyle(.borderedProminent)
                        .tint(item.kind.ribbonColor)
                        .foregroundStyle(.black)
                        .help("Paste into the previous application")
                    Spacer(minLength: 0)
                    Menu {
                        Button("Edit / Rename…", systemImage: "pencil", action: onEdit)
                        if [.text, .link, .richText, .color].contains(item.kind) {
                            Button("Save as Snippet", systemImage: "text.book.closed",
                                   action: onSaveSnippet)
                        }
                        if item.recognizedText != nil {
                            Button("Copy Text from Image", systemImage: "text.viewfinder",
                                   action: onCopyRecognizedText)
                        }
                        Divider()
                        Menu("Colored Tags") {
                            ForEach(tags) { tag in
                                if !item.tags.contains(where: { $0.id == tag.id }) {
                                    Button(tag.name) { onApplyTag(tag) }
                                }
                            }
                            Button("New Color Tag…", action: onCreateTag)
                            if !item.tags.isEmpty {
                                Divider()
                                ForEach(item.tags) { tag in
                                    Button("Remove \(tag.name)") { onRemoveTag(tag.id) }
                                }
                            }
                        }
                        Button("Add to Paste Stack", action: onQueue)
                        if [.richText, .text, .link, .color].contains(item.kind) {
                            Button("Paste as Plain Text", action: onPastePlain)
                        }
                        Divider()
                        Button(item.pinned ? "Unpin" : "Pin", action: onPin)
                        Menu("Move to Collection") {
                            Button("Unassigned") { onMove(nil) }
                            ForEach(collections, id: \.self) { name in
                                Button(name) { onMove(name) }
                            }
                            Divider()
                            Button("New Collection…", action: onNewCollection)
                        }
                        Divider()
                        Button("Delete", role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .accessibilityLabel("More actions for \(item.displayName ?? item.preview)")
                    .menuStyle(.borderlessButton)
                    .frame(width: 27)
                }
                .controlSize(.small)
            }
            .padding(11)
        }
        .frame(width: 230, height: 224)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.93),
                    in: RoundedRectangle(cornerRadius: 15))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .strokeBorder(
                    isSelected ? item.kind.ribbonColor : .white.opacity(0.15),
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .shadow(color: isSelected ? item.kind.ribbonColor.opacity(0.12) : .clear,
                radius: 12)
        .contentShape(RoundedRectangle(cornerRadius: 15))
        .onTapGesture(perform: onSelect)
        .accessibilityElement(children: .contain)
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
    @State private var showingRecentClear = false
    @State private var recentClearMinutes = 15

    private var runningApplications: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    var body: some View {
        Form {
            if model.databaseUnavailable {
                Section("Storage Recovery") {
                    Text("Clipboard could not open its encrypted history. Your existing files have not been deleted.")
                        .foregroundStyle(.orange)
                    Button("Preserve Old History and Create Fresh Storage…") {
                        confirmDatabaseRecovery()
                    }
                    Text("The old database and image assets are moved to a recovery folder instead of being deleted. Recovery does not decrypt data if the Keychain key is lost.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Monitoring and Privacy") {
                Toggle("Pause clipboard monitoring", isOn: Binding(
                    get: { model.isPaused },
                    set: { _ in model.togglePaused() }
                ))
                Text("Clipboard history is encrypted on this Mac with a Keychain-backed key. Secret and password-manager exclusions are best-effort, not a guarantee.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("Ignore these app bundle IDs (one per line):")
                    .font(.callout.weight(.medium))
                Menu("Choose a Running App to Ignore") {
                    ForEach(runningApplications, id: \.processIdentifier) { application in
                        Button(application.localizedName ?? application.bundleIdentifier ?? "App") {
                            guard let identifier = application.bundleIdentifier else { return }
                            let values = ClipboardPrivacy.normalizedBundleIDs(
                                from: model.excludedAppsText + "\n" + identifier
                            )
                            model.excludedAppsText = values.joined(separator: "\n")
                        }
                    }
                }
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
                Toggle("Recognize text inside images (on-device OCR)", isOn: $model.recognizeImages)
                Text("Image recognition runs locally using Apple's Vision framework. It may use extra CPU and battery power.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
            Section("History Cleanup") {
                Menu("Clear Recent Unpinned Clips…") {
                    Button("Last 5 minutes") {
                        recentClearMinutes = 5
                        showingRecentClear = true
                    }
                    Button("Last 15 minutes") {
                        recentClearMinutes = 15
                        showingRecentClear = true
                    }
                    Button("Last 1 hour") {
                        recentClearMinutes = 60
                        showingRecentClear = true
                    }
                    Button("Last 24 hours") {
                        recentClearMinutes = 1440
                        showingRecentClear = true
                    }
                }
                Text("This does not delete pinned clips or snippets. Destructive changes require confirmation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Encrypted Backups") {
                Text("Export a portable backup protected with a password. No unencrypted export file is written to disk.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Export Encrypted Backup…") { exportBackup() }
                    Button("Restore Backup…") { importBackup() }
                }
                Text("Keep the password safe. Without it, a backup cannot be restored. Restoring merges clips with the existing history.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("System Integration") {
                Toggle("Launch Clipboard at login", isOn: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { model.setLaunchAtLogin($0) }
                ))
                Text("macOS may ask for approval under System Settings → General → Login Items. Unsigned development builds may not register successfully.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Keyboard Shortcuts") {
                Picker("Open Clipboard", selection: Binding(
                    get: { model.hotkeyPreset },
                    set: { model.setHotkeyPreset($0) }
                )) {
                    ForEach(ClipboardHotkeyPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                Text("↑↓ select a clip · Return paste · Option+Return paste plain · ⌘P pin · ⌘1–9 quick paste.")
                Text("If a shortcut is already used by another application, Clipboard keeps the previous working shortcut.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Automatic paste requires macOS Accessibility permission; copying does not.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Request Accessibility Permission") {
                    let options = [
                        kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
                    ] as CFDictionary
                    _ = AXIsProcessTrustedWithOptions(options)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 615, height: 600)
        .confirmationDialog(
            "Delete recent unpinned clips?",
            isPresented: $showingRecentClear,
            titleVisibility: .visible
        ) {
            Button("Delete Recent History", role: .destructive) {
                model.clearRecent(minutes: recentClearMinutes)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Clips newer than the selected cutoff are deleted. Pinned items and Snippets are kept.")
        }
    }

    private func confirmDatabaseRecovery() {
        let alert = NSAlert()
        alert.messageText = "Move the existing history into recovery storage?"
        alert.informativeText = "Clipboard will preserve the complete existing database and assets in a separate folder, then create a new empty encrypted history. This does NOT restore damaged entries."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Preserve and Reset")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        model.quarantineAndResetStorage()
    }

    private func exportBackup() {
        guard let password = ClipboardPasswordDialog.ask(confirm: true) else { return }
        let panel = NSSavePanel()
        panel.title = "Save encrypted Clipboard backup"
        panel.nameFieldStringValue = "Clipboard-\(Date().formatted(date: .numeric, time: .omitted)).clipbackup"
        panel.allowedContentTypes = [UTType(filenameExtension: "clipbackup") ?? .data]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        model.exportEncryptedBackup(password: password, to: url)
    }

    private func importBackup() {
        let panel = NSOpenPanel()
        panel.title = "Open encrypted Clipboard backup"
        panel.allowedContentTypes = [UTType(filenameExtension: "clipbackup") ?? .data]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let password = ClipboardPasswordDialog.ask(confirm: false) else { return }

        let confirm = NSAlert()
        confirm.messageText = "Restore encrypted backup?"
        confirm.informativeText = "This will merge backup entries with your current clipboard history. Pinned entries will be preserved."
        confirm.alertStyle = .informational
        confirm.addButton(withTitle: "Restore")
        confirm.addButton(withTitle: "Cancel")
        guard confirm.runModal() == .alertFirstButtonReturn else { return }
        model.importEncryptedBackup(from: url, password: password)
    }
}

/// System secure fields: passwords are never put in app settings or logs.
private enum ClipboardPasswordDialog {
    static func ask(confirm: Bool) -> String? {
        let alert = NSAlert()
        alert.messageText = confirm ? "Choose a backup password" : "Enter backup password"
        alert.informativeText = confirm
            ? "Use at least 12 characters. This password is necessary to restore on another Mac."
            : "Enter the password that was used when this backup was exported."
        let first = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 350, height: 24))
        first.placeholderString = "Backup password"
        let stack = NSStackView(views: [first])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.frame = NSRect(x: 0, y: 0, width: 350, height: confirm ? 56 : 24)

        var second: NSSecureTextField?
        if confirm {
            let confirmation = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 350, height: 24))
            confirmation.placeholderString = "Confirm backup password"
            stack.addArrangedSubview(confirmation)
            second = confirmation
        }
        alert.accessoryView = stack
        alert.addButton(withTitle: confirm ? "Continue" : "Unlock")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let password = first.stringValue
        guard password.count >= (confirm ? 12 : 1),
              !password.contains("\0"),
              second == nil || second?.stringValue == password else {
            let warning = NSAlert()
            warning.messageText = "Invalid backup password"
            warning.informativeText = confirm
                ? "Use at least 12 characters and enter the same password twice."
                : "Enter the password associated with your backup."
            warning.runModal()
            return nil
        }
        return password
    }
}
