import SwiftUI

/// Reusable native editor. No content is sent outside the application.
struct ClipboardClipEditorView: View {
    let item: ClipItem
    let onSave: (String?, String?, Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var content: String
    @State private var asSnippet: Bool
    @State private var showDiscardConfirmation = false

    private var editable: Bool {
        [.text, .link, .richText].contains(item.kind)
    }

    init(item: ClipItem, onSave: @escaping (String?, String?, Bool) -> Void) {
        self.item = item
        self.onSave = onSave
        _title = State(initialValue: item.displayName ?? "")
        _content = State(initialValue: item.body ?? "")
        _asSnippet = State(initialValue: item.collection == "Snippets")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("Edit Clipboard Item", systemImage: "pencil.and.scribble")
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                Text(item.kind.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Form {
                TextField("Display title (optional)", text: $title)
                    .textFieldStyle(.roundedBorder)
                if editable {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Content")
                            .font(.subheadline.weight(.medium))
                        TextEditor(text: $content)
                            .font(.system(size: 13, design: .monospaced))
                            .frame(height: 175)
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(.secondary.opacity(0.25))
                            }
                        Text("Editing rich text converts it to plain text.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Toggle("Save as a pinned Snippet", isOn: $asSnippet)
                } else {
                    Text("This content can be renamed, but cannot be changed in the editor.")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            HStack {
                Text("Content stays encrypted in local history.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(
                        title.trimmingCharacters(in: .whitespacesAndNewlines),
                        editable ? content : nil,
                        editable && asSnippet
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(
                    title.count > 120 ||
                    (editable && content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                )
            }
        }
        .padding(22)
        .frame(width: 540, height: editable ? 455 : 285)
    }
}

struct ClipboardNewSnippetView: View {
    let onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var content = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("New Snippet", systemImage: "text.book.closed")
                .font(.system(size: 21, weight: .semibold))
            Text("Create reusable text that stays pinned even when clipboard history expires.")
                .font(.callout)
                .foregroundStyle(.secondary)
            TextField("Snippet name", text: $title)
                .textFieldStyle(.roundedBorder)
            TextEditor(text: $content)
                .font(.system(size: 13, design: .monospaced))
                .frame(height: 195)
                .overlay {
                    RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(.secondary.opacity(0.25))
                }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save Snippet") {
                    onSave(title, content)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(
                    title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    title.count > 120 ||
                    content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
        .padding(22)
        .frame(width: 530, height: 420)
    }
}
