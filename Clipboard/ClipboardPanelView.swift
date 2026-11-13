import AppKit
import SwiftUI
import ApplicationServices
import UniformTypeIdentifiers

enum ClipboardCardTapBehavior: Equatable {
    case pasteToPreviousApp
    case selectForManagement
}

enum ClipboardPanelPresentation: Equatable {
    case shelf
    case management

    var cardTapBehavior: ClipboardCardTapBehavior {
        switch self {
        case .shelf: return .pasteToPreviousApp
        case .management: return .selectForManagement
        }
    }
}

struct ClipboardPanelView: View {
    @ObservedObject var model: ClipboardModel
    let presentation: ClipboardPanelPresentation
    let onDismiss: () -> Void
    let onPaste: (ClipItem) -> Void
    let onPastePlain: (ClipItem) -> Void
    let onPasteNext: () -> Void
    let onDensityChange: (ClipboardShelfDensity) -> Void

    @FocusState private var searchFocused: Bool
    @State private var showingSettings = false
    @State private var showingCollectionAlert = false
    @State private var newCollectionName = ""
    @State private var newCollectionItem: ClipItem?
    @State private var editingClip: ClipItem?
    @State private var creatingSnippet = false
    @State private var tagSheet: ClipboardTagSheet?
    @AppStorage("clipboard.shelfDensity") private var densityRaw = "comfortable"

    private var effectiveDensity: ClipboardShelfDensity {
        let preferred = ClipboardShelfDensity(rawValue: densityRaw) ?? .comfortable
        return presentation == .shelf
            ? ClipboardShelfDensity.effective(
                preferred: preferred, screenHeight: model.shelfScreenHeight
            )
            : preferred
    }


    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            filterRail
            if presentation == .management || model.shelfScreenHeight >= 660 {
                tagRail
            }
            clipsCarousel
            if presentation == .management || model.shelfScreenHeight >= 580 {
                footer
            }
            if model.pasteDiagnostic != "P0 · No paste attempted since launch." {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundStyle(.mint)
                    Text(model.pasteDiagnostic)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("Copy diagnostics") { model.copyPasteDiagnostic() }
                        .buttonStyle(.link)
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 5)
            }
            if let message = model.message {
                HStack(spacing: 9) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.orange)
                    Text(message)
                        .lineLimit(2)
                        .font(.system(size: 11))
                    Spacer(minLength: 0)
                    Button("Dismiss") { model.message = nil }
                        .buttonStyle(.link)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(.orange.opacity(0.10),
                            in: RoundedRectangle(cornerRadius: 13))
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

    private var header: some View {
        HStack(spacing: 13) {
            Image(systemName: "square.on.square.fill")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 43, height: 43)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color(red: 0.19, green: 0.85, blue: 0.82),
                                     Color(red: 0.23, green: 0.42, blue: 0.93)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.white.opacity(0.54), lineWidth: 1)
                        .allowsHitTesting(false)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text("Clipboard")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .tracking(-0.35)
                Text(presentation == .shelf ? "QUICK PASTE" : "HISTORY MANAGER")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.3)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 16)
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("Search text, links, apps, tags…", text: $model.searchText)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .font(.system(size: 13))
                    .frame(minWidth: 140)
                if !model.searchText.isEmpty {
                    Button {
                        model.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear search")
                }
            }
            .padding(.horizontal, 14)
            .frame(
                width: presentation == .shelf
                    ? (model.shelfScreenWidth < 850 ? 196 : 320)
                    : 265,
                height: 40
            )
            .liquidToolbar()
            headerActionButtons
        }
    }

    @ViewBuilder
    private var headerActionButtons: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: 7) {
                headerActions
            }
        } else {
            headerActions
        }
    }

    private var headerActions: some View {
        HStack(spacing: 8) {
            Button { creatingSnippet = true } label: {
                Image(systemName: "plus.square.on.square")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 39, height: 39)
            }
            .buttonStyle(.plain)
            .liquidToolbar()
            .help("New reusable snippet")

            Button { showingSettings = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 39, height: 39)
            }
            .buttonStyle(.plain)
            .liquidToolbar()
            .help("Clipboard settings")

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 39, height: 39)
            }
            .buttonStyle(.plain)
            .liquidToolbar()
            .help("Dismiss")
        }
    }

    private var filterRail: some View {
        HStack(spacing: 12) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    Button {
                        model.pinnedOnly = false
                    } label: {
                        Label("All Clips", systemImage: "square.stack.3d.up")
                    }
                    .modifier(ClipboardFilterChrome(selected: !model.pinnedOnly))

                    Button {
                        model.pinnedOnly = true
                    } label: {
                        Label("Pinned", systemImage: "pin.fill")
                    }
                    .modifier(ClipboardFilterChrome(selected: model.pinnedOnly))

                    Menu {
                        Button("All Content Types") { model.selectedKind = nil }
                        ForEach(ClipKind.allCases, id: \.self) { kind in
                            Button(kind.title) { model.selectedKind = kind }
                        }
                        Divider()
                        Menu("Source Application") {
                            Button("All Applications") {
                                model.selectedSourceApp = nil
                            }
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
                    .modifier(ClipboardFilterChrome(
                        selected: model.selectedKind != nil ||
                            model.selectedSourceApp != nil ||
                            model.historyPeriod != .all
                    ))

                    Menu {
                        Button("All Collections") {
                            model.selectedCollection = nil
                        }
                        ForEach(model.collections, id: \.self) { name in
                            Button(name) { model.selectedCollection = name }
                        }
                    } label: {
                        Label(model.selectedCollection ?? "Collections",
                              systemImage: "folder")
                            .lineLimit(1)
                    }
                    .modifier(ClipboardFilterChrome(
                        selected: model.selectedCollection != nil
                    ))

                    Menu {
                        Button("Comfortable Cards") {
                            densityRaw = ClipboardShelfDensity.comfortable.rawValue
                            onDensityChange(.comfortable)
                        }
                        Button("Compact Cards") {
                            densityRaw = ClipboardShelfDensity.compact.rawValue
                            onDensityChange(.compact)
                        }
                    } label: {
                        Label(effectiveDensity.title, systemImage: "rectangle.3.group")
                    }
                    .modifier(ClipboardFilterChrome(selected: false))
                    .help("Card density")
                }
                .padding(.vertical, 3)
            }
            .scrollIndicators(.hidden)

            Button { model.togglePaused() } label: {
                Label(
                    model.isPaused ? "Paused" : "Monitoring",
                    systemImage: model.isPaused
                        ? "pause.circle.fill" : "checkmark.shield.fill"
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(model.isPaused ? .orange : .mint)
            .padding(.horizontal, 13)
            .frame(height: 35)
            .liquidToolbar()
            .fixedSize()
        }
        .font(.system(size: 12, weight: .semibold))
    }

    private var tagRail: some View {
        HStack(spacing: 11) {
            Text("TAGS")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    Button {
                        model.selectedTagID = nil
                    } label: {
                        Text("All Tags")
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 14)
                            .frame(height: 27)
                    }
                    .buttonStyle(.plain)
                    .background(
                        model.selectedTagID == nil
                            ? Color.accentColor.opacity(0.18)
                            : Color.primary.opacity(0.06),
                        in: Capsule()
                    )
                    ForEach(model.tags) { tag in
                        Button {
                            model.selectedTagID =
                                model.selectedTagID == tag.id ? nil : tag.id
                        } label: {
                            ClipTagPill(
                                tag: tag,
                                selected: model.selectedTagID == tag.id
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Edit \(tag.name)…") { tagSheet = .edit(tag) }
                        }
                    }
                    if model.tags.isEmpty {
                        Text("Organize snippets with colored tags")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
        .frame(height: 31)
    }

    @ViewBuilder
    private var clipsCarousel: some View {
        if model.clips.isEmpty {
            VStack(spacing: 9) {
                Image(systemName: "square.stack.3d.up.slash")
                    .font(.system(size: 30))
                    .foregroundStyle(.mint)
                Text(model.searchText.isEmpty
                     ? "Your clipboard, beautifully organized"
                     : "No matching clips")
                    .font(.system(size: 15, weight: .semibold))
                Text("Copy text, files, links or images in another app.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .center, spacing: effectiveDensity.cardSpacing) {
                        ForEach(model.clips) { item in
                            ClipCard(
                                item: item,
                                density: effectiveDensity,
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
                                onPrimaryClick: {
                                    switch presentation.cardTapBehavior {
                                    case .pasteToPreviousApp: onPaste(item)
                                    case .selectForManagement:
                                        model.selectedClipID = item.id
                                    }
                                },
                                primaryClickPastes: presentation == .shelf,
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
                    .padding(.horizontal, 4)
                    .padding(.vertical, 11)
                }
                .scrollIndicators(.hidden)
                .onChange(of: model.selectedClipID) { _, id in
                    if let id {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Label("↑↓ Navigate · ↵ Paste · ⌘1–9 Quick", systemImage: "keyboard")
            Spacer(minLength: 8)
            Label("\(model.clips.count) clips", systemImage: "square.stack")
            Spacer(minLength: 8)
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
                Label("On-device · Private", systemImage: "lock.shield")
            }
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 5)
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

/// Uses a single system glass canvas instead of a fake opaque black panel.
/// Dock clearance is *inside* the shelf: the full-screen bottom edge remains
/// connected to the Dock while the content and controls stay unobscured.
private struct ClipboardPanelChrome: ViewModifier {
    let presentation: ClipboardPanelPresentation
    let bottomContentInset: CGFloat

    func body(content: Content) -> some View {
        Group {
            if presentation == .shelf {
                content
                    .padding(.horizontal, 23)
                    .padding(.top, 16)
                    .padding(.bottom, max(15, bottomContentInset + 8))
                    .frame(minWidth: 300, maxWidth: .infinity,
                           minHeight: 300, maxHeight: .infinity)
                    .background {
                        ClipboardGlassBackdrop()
                    }
                    .clipShape(ClipboardTopRoundedShape(radius: 27))
            } else {
                content
                    .padding(20)
                    .frame(minWidth: 720, maxWidth: .infinity,
                           minHeight: 460, maxHeight: .infinity)
                    .background(.regularMaterial,
                                in: RoundedRectangle(cornerRadius: 19))
            }
        }
    }
}

/// An actual macOS 26 Liquid Glass effect combined with a restrained adaptive
/// material, not a flat color imitation. On macOS 15 this falls back to the
/// supported system vibrancy material. Decorative layers never steal clicks.
private struct ClipboardGlassBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    private var shape: ClipboardTopRoundedShape {
        ClipboardTopRoundedShape(radius: 27)
    }

    var body: some View {
        ZStack {
            shape.fill(.ultraThinMaterial)
            if #available(macOS 26, *) {
                shape
                    .fill(.white.opacity(0.012))
                    .glassEffect(
                        .regular.tint(Color(red: 0.26, green: 0.64, blue: 0.83)
                            .opacity(0.075)),
                        in: shape
                    )
            }
            shape.fill(
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color(red: 0.18, green: 0.24, blue: 0.35).opacity(0.30),
                           Color(red: 0.07, green: 0.13, blue: 0.21).opacity(0.10),
                           Color.clear]
                        : [Color.white.opacity(0.34),
                           Color(red: 0.80, green: 0.90, blue: 1.0).opacity(0.13),
                           Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            shape.stroke(
                LinearGradient(
                    colors: [.white.opacity(0.54), .white.opacity(0.16),
                             .white.opacity(0.05)],
                    startPoint: .top, endPoint: .bottom
                ), lineWidth: 1
            )
        }
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [.white.opacity(colorScheme == .dark ? 0.17 : 0.48),
                         .white.opacity(0.02), .clear],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 27)
            .clipShape(shape)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ClipboardFilterChrome: ViewModifier {
    let selected: Bool

    func body(content: Content) -> some View {
        content
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 16)
            .frame(height: 35)
            .foregroundStyle(selected ? .primary : .secondary)
            .background {
                Capsule()
                    .fill(selected
                          ? Color.accentColor.opacity(0.17)
                          : Color.primary.opacity(0.055))
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                selected ? Color.accentColor.opacity(0.36)
                                         : Color.white.opacity(0.14),
                                lineWidth: 1
                            )
                    }
                    .allowsHitTesting(false)
            }
            .buttonStyle(.plain)
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
    let density: ClipboardShelfDensity
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
    let onPrimaryClick: () -> Void
    let primaryClickPastes: Bool
    let tags: [ClipTag]
    let onApplyTag: (ClipTag) -> Void
    let onRemoveTag: (String) -> Void
    let onCreateTag: () -> Void
    let collections: [String]
    let onMove: (String?) -> Void
    let onNewCollection: () -> Void

    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let radius: CGFloat = 21

    private var appearsToBeCode: Bool {
        item.preview.contains("\n") &&
            (item.preview.contains("{") ||
             item.preview.contains("SELECT ") ||
             item.preview.contains("const ") ||
             item.preview.contains("def "))
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onPrimaryClick) {
                VStack(alignment: .leading, spacing: 0) {
                    typeRibbon
                    VStack(alignment: .leading, spacing: 7) {
                        previewContent
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .frame(
                                height: density.previewHeight,
                                alignment: .topLeading
                            )
                            .clipped()

                        cardTags
                            .frame(height: 24)

                        cardMetadata
                            .frame(height: 20)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 13)
                    .padding(.bottom, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: radius))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                primaryClickPastes
                    ? "Paste \(item.displayName ?? item.preview) into previous application"
                    : "Select \(item.displayName ?? item.preview)"
            )
            .accessibilityHint(
                primaryClickPastes
                    ? "Copies and pastes once, then closes the quick shelf"
                    : "Selects the clip without pasting"
            )
            .help(
                primaryClickPastes
                    ? "Click this preview to paste into the previous app"
                    : "Select clip"
            )

            Spacer(minLength: 0)
            actionRow
        }
        .frame(width: density.cardWidth, height: density.cardHeight)
        .background {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(.thinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(item.kind.ribbonColor.opacity(hovering ? 0.075 : 0.034))
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(
                    isSelected
                        ? item.kind.ribbonColor.opacity(0.88)
                        : Color.white.opacity(hovering ? 0.36 : 0.16),
                    lineWidth: isSelected ? 1.8 : 1
                )
                .allowsHitTesting(false)
        }
        .shadow(
            color: .black.opacity(hovering ? 0.19 : 0.10),
            radius: hovering ? 23 : 13,
            y: hovering ? 10 : 5
        )
        .scaleEffect(hovering && !reduceMotion ? 1.012 : 1)
        .offset(y: hovering && !reduceMotion ? -3 : 0)
        .animation(
            reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.84),
            value: hovering
        )
        .onHover { hovering = $0 }
        .accessibilityElement(children: .contain)
    }

    private var typeRibbon: some View {
        HStack(spacing: 9) {
            Image(systemName: item.kind.symbol)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 24, height: 24)
                .background(
                    item.kind.ribbonColor.opacity(0.18),
                    in: RoundedRectangle(cornerRadius: 7)
                )
            Text(item.kind.title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(0.7)
            Spacer(minLength: 4)
            if item.pinned {
                Label("PINNED", systemImage: "pin.fill")
                    .font(.system(size: 10, weight: .semibold))
            } else {
                Text("RECENT")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 15)
        .frame(height: 43)
        .background {
            LinearGradient(
                colors: [
                    item.kind.ribbonColor.opacity(0.26),
                    item.kind.ribbonColor.opacity(0.07)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .overlay(alignment: .top) {
            item.kind.ribbonColor.opacity(0.88)
                .frame(height: 3)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        if item.kind == .color,
           let rgba = ClipColor.hexValue(item.body ?? item.preview) {
            VStack(alignment: .leading, spacing: 9) {
                RoundedRectangle(cornerRadius: 11)
                    .fill(Color(
                        red: rgba.red, green: rgba.green,
                        blue: rgba.blue
                    ).opacity(rgba.alpha))
                    .frame(height: density.previewHeight - 40)
                    .overlay {
                        RoundedRectangle(cornerRadius: 11)
                            .strokeBorder(.primary.opacity(0.15))
                    }
                Text(item.body ?? item.preview)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
            }
        } else if item.kind == .image {
            ClipboardThumbnailView(source: thumbnailSource)
                .frame(maxWidth: .infinity)
                .frame(height: density.previewHeight - 2)
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .overlay(alignment: .bottomTrailing) {
                    if item.recognizedText != nil {
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 12, weight: .medium))
                            .padding(7)
                            .background(.regularMaterial, in: Circle())
                            .padding(6)
                    }
                }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                if let title = item.displayName {
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .lineLimit(1)
                }
                if item.kind == .link,
                   let host = URL(string: item.preview)?.host {
                    Label(host, systemImage: "globe")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(item.kind.ribbonColor)
                        .lineLimit(1)
                }
                Text(item.preview)
                    .font(
                        appearsToBeCode
                            ? .system(size: 12, weight: .medium, design: .monospaced)
                            : .system(size: 13, weight: .medium)
                    )
                    .lineSpacing(3)
                    .lineLimit(item.displayName == nil ? 7 : 5)
                    .multilineTextAlignment(.leading)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .topLeading
                    )
                    .textSelection(.disabled)
            }
        }
    }

    @ViewBuilder
    private var cardTags: some View {
        if !item.tags.isEmpty {
            HStack(spacing: 5) {
                ForEach(item.tags.prefix(2)) { tag in
                    ClipTagPill(tag: tag, selected: false)
                }
                if item.tags.count > 2 {
                    Text("+\(item.tags.count - 2)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        } else if let collection = item.collection {
            Label(collection, systemImage: "folder")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } else {
            Text(" ")
                .font(.caption)
                .accessibilityHidden(true)
        }
    }

    private var cardMetadata: some View {
        HStack(spacing: 7) {
            Image(systemName: "app.fill")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(item.sourceApp)
                .lineLimit(1)
            Spacer(minLength: 4)
            Image(systemName: "clock")
                .font(.system(size: 10))
            Text(item.createdAt, style: .relative)
                .lineLimit(1)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            Button(action: onCopy) {
                Label("Copy", systemImage: "doc.on.doc")
                    .frame(minWidth: 65)
            }
            .buttonStyle(.bordered)
            .help("Copy without automatic paste")

            Button(action: onPaste) {
                Label("Paste", systemImage: "arrow.down.to.line")
                    .frame(minWidth: 75)
            }
            .buttonStyle(.borderedProminent)
            .tint(item.kind.ribbonColor)
            .help("Paste into the previous application")

            Spacer(minLength: 0)
            moreActionsMenu
        }
        .controlSize(.regular)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.primary.opacity(0.032))
    }

    private var moreActionsMenu: some View {
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
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 31, height: 29)
        }
        .accessibilityLabel(
            "More actions for \(item.displayName ?? item.preview)"
        )
        .menuStyle(.borderlessButton)
        .help("Organize, pin, edit or delete")
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
    @State private var signingAndPermissionSummary = "Press Refresh to inspect the running app's TCC identity."

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
            Section("Paste Diagnostics") {
                Text(model.pasteDiagnostic)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                Text(signingAndPermissionSummary)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                HStack {
                    Button("Refresh TCC & Signing Status") {
                        signingAndPermissionSummary = ClipboardPermissionAudit.summary()
                    }
                    Button("Copy Paste Diagnostics") { model.copyPasteDiagnostic() }
                    Button("Request Event Posting Access") {
                        // Apple exposes a separate permission for synthetic
                        // keystrokes: this must not be hidden under an AX button.
                        _ = CGRequestPostEventAccess()
                        signingAndPermissionSummary = ClipboardPermissionAudit.summary()
                    }
                    Button("Request Accessibility Access") {
                        let options = [
                            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
                        ] as CFDictionary
                        _ = AXIsProcessTrustedWithOptions(options)
                        signingAndPermissionSummary = ClipboardPermissionAudit.summary()
                    }
                }
                Text("If Accessibility is TRUE but Event Posting is FALSE, macOS is denying the separate PostEvent TCC service, which sends Command-V. Use Request Event Posting Access above. If it remains false, quit Clipboard, reset only PostEvent for its bundle ID using the command below, then reopen this exact /Applications app, request approval and relaunch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 9) {
                    Text("tccutil reset PostEvent dev.clipboard.app")
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                    Button("Copy Command") {
                        let board = NSPasteboard.general
                        board.clearContents()
                        _ = board.setString(
                            "tccutil reset PostEvent dev.clipboard.app",
                            forType: .string
                        )
                        model.onClipboardWrite?()
                    }
                }
                Text("Do not run the reset command with sudo or reset all macOS privacy permissions. PostEvent is not Input Monitoring. A newly granted permission may require quitting and reopening Clipboard.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Shows where the last paste attempt stopped. Diagnostics contain no copied text or images. A sent Command+V is not proof that the target accepted it.")
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
