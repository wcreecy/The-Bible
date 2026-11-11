import SwiftUI
import Observation

/// Study text whose passage references are tappable previews.
struct LinkedScriptureText: View {
    let text: String

    @Environment(\.scriptureContextBook) private var contextBook

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(PassageReferenceParser.linkified(text, contextBook: contextBook))
    }
}

@MainActor
@Observable
final class StudySheetDismissal {
    var isPresented = false

    func dismiss() {
        isPresented = false
    }
}

extension EnvironmentValues {
    /// The book that study text is about, so references such as "(3:9)" can link into it.
    @Entry var scriptureContextBook: String?

    /// The stable state object that closes a containing study sheet, when there is one.
    @Entry var studySheetDismissal: StudySheetDismissal?

}

extension View {
    /// Adds a Done button that closes the enclosing study sheet, when there is one.
    func studySheetDoneButton(placement: ToolbarItemPlacement = .cancellationAction) -> some View {
        modifier(StudySheetDoneButtonModifier(placement: placement))
    }
}

private struct StudySheetDoneButtonModifier: ViewModifier {
    let placement: ToolbarItemPlacement

    @Environment(\.studySheetDismissal) private var studySheetDismissal

    func body(content: Content) -> some View {
        content.toolbar {
            if let studySheetDismissal {
                ToolbarItem(placement: placement) {
                    Button("Done", action: studySheetDismissal.dismiss)
                }
            }
        }
    }
}

/// A wrapping row of tappable reference chips. `book` and `chapter` fill in entries that
/// omit them; entries that still cannot be read are shown as plain labels.
struct PassageReferenceChips: View {
    let references: [String]
    var book: String?
    var chapter: Int?

    private enum Chip: Identifiable {
        case passage(PassageReference)
        case text(String)

        var id: String {
            switch self {
            case .passage(let reference): "passage-\(reference.id)"
            case .text(let text): "text-\(text)"
            }
        }
    }

    private var chips: [Chip] {
        var seen = Set<String>()
        return references.flatMap { text -> [Chip] in
            let parsed = PassageReferenceParser.parseList(text, book: book, chapter: chapter)
            let entries = parsed.isEmpty ? [Chip.text(text)] : parsed.map(Chip.passage)
            return entries.filter { seen.insert($0.id).inserted }
        }
    }

    var body: some View {
        PassageFlowLayout(spacing: 8) {
            ForEach(chips) { chip in
                switch chip {
                case .passage(let reference):
                    Link(destination: reference.url) {
                        Label(reference.displayTitle, systemImage: "book")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                    }
                    .accessibilityHint("Shows a preview of the passage")
                case .text(let text):
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                }
            }
        }
    }
}

extension View {
    /// Shows a scripture preview sheet when a passage link inside this view is tapped.
    func scripturePassagePreviews() -> some View {
        modifier(ScripturePassagePreviewModifier())
    }
}

private struct ScripturePassagePreviewModifier: ViewModifier {
    @State private var selectedPassage: PassageReference?

    func body(content: Content) -> some View {
        content
            .environment(\.openURL, OpenURLAction { url in
                guard let reference = PassageReference(url: url) else { return .systemAction }
                selectedPassage = reference
                return .handled
            })
            .sheet(item: $selectedPassage) { reference in
                ScripturePassageSheet(reference: reference)
            }
    }
}

/// Wraps its children onto as many rows as needed, left to right.
private struct PassageFlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: bounds.minY + row.y),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let proposedWidth = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if proposedWidth > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row(y: current.y + current.height + spacing)
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
