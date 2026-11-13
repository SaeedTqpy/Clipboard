import SwiftUI

extension ClipTagColor {
    var tint: Color {
        switch self {
        case .green: return Color(red: 0.56, green: 0.87, blue: 0.47)
        case .turquoise: return Color(red: 0.20, green: 0.83, blue: 0.79)
        case .blue: return Color(red: 0.40, green: 0.68, blue: 0.98)
        case .violet: return Color(red: 0.71, green: 0.57, blue: 0.99)
        case .pink: return Color(red: 0.99, green: 0.55, blue: 0.76)
        case .coral: return Color(red: 0.99, green: 0.48, blue: 0.44)
        case .amber: return Color(red: 1.00, green: 0.76, blue: 0.38)
        case .gray: return Color(red: 0.72, green: 0.75, blue: 0.80)
        }
    }
}

extension ClipKind {
    var ribbonColor: Color {
        switch self {
        case .text: return Color(red: 0.38, green: 0.72, blue: 0.99)
        case .link: return Color(red: 0.33, green: 0.83, blue: 0.60)
        case .richText: return Color(red: 0.70, green: 0.60, blue: 0.97)
        case .color: return Color(red: 0.98, green: 0.72, blue: 0.38)
        case .image: return Color(red: 0.99, green: 0.50, blue: 0.63)
        case .file: return Color(red: 0.35, green: 0.82, blue: 0.87)
        }
    }
}

struct ClipTagPill: View {
    let tag: ClipTag
    let selected: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(tag.color.tint)
                .frame(width: 7, height: 7)
            Text(tag.name)
                .lineLimit(1)
                .font(.system(size: 10, weight: .semibold))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .foregroundStyle(.primary)
        .background(tag.color.tint.opacity(selected ? 0.33 : 0.16), in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(tag.color.tint.opacity(selected ? 0.96 : 0.35),
                              lineWidth: selected ? 1.4 : 0.7)
        }
        .accessibilityLabel("Tag \(tag.name), color \(tag.color.title)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct ClipboardTagEditorView: View {
    let editing: ClipTag?
    let onSave: (String, ClipTagColor) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var color: ClipTagColor

    init(editing: ClipTag?, onSave: @escaping (String, ClipTagColor) -> Void) {
        self.editing = editing
        self.onSave = onSave
        _name = State(initialValue: editing?.name ?? "")
        _color = State(initialValue: editing?.color ?? .green)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 19) {
            Label(editing == nil ? "New Colored Tag" : "Edit Colored Tag",
                  systemImage: "tag.fill")
                .font(.system(size: 20, weight: .semibold))
            TextField("Tag name", text: $name)
                .textFieldStyle(.roundedBorder)
            Text("COLOR")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                ForEach(ClipTagColor.allCases) { shade in
                    Button {
                        color = shade
                    } label: {
                        Circle()
                            .fill(shade.tint)
                            .frame(width: 27, height: 27)
                            .overlay {
                                Circle().strokeBorder(.primary.opacity(0.85),
                                                      lineWidth: color == shade ? 2.5 : 0)
                                    .padding(-4)
                            }
                    }
                    .buttonStyle(.plain)
                    .help(shade.title)
                    .accessibilityLabel(shade.title + " color")
                    .accessibilityAddTraits(color == shade ? .isSelected : [])
                }
            }
            Text(editing == nil
                 ? "New tags are applied to this clip. Reuse them from other cards."
                 : "Updating a tag also changes its label and color on other clips.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(editing == nil ? "Create Tag" : "Save Tag") {
                    onSave(name.trimmingCharacters(in: .whitespacesAndNewlines), color)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(
                    name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    name.count > 28
                )
            }
        }
        .padding(24)
        .frame(width: 438)
    }
}
