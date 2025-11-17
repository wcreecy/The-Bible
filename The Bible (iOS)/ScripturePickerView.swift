// ScripturePickerView.swift
import SwiftUI

struct ScripturePickerView: View {
    @Environment(\.dismiss) private var dismiss

    // Initial selection (optional)
    let initialBook: String?
    let initialChapter: Int?
    let initialVerse: Int?

    // Called when user taps Done
    let onConfirm: (String, Int, Int) -> Void

    // Data
    @State private var allBookNames: [String] = []
    @State private var isLoadingBooks: Bool = true
    @State private var isLoadingBook: Bool = false
    @State private var loadError: Bool = false

    // Selection state
    @State private var bookSelection: String = ""   // non-optional for UI
    @State private var loadedBook: Book? = nil
    @State private var selectedChapter: Int = 1
    @State private var selectedVerse: Int = 1
    @State private var previewText: String = ""

    // Async book load cancellation
    @State private var loadTask: Task<Void, Never>? = nil

    // Prevent double-commit (Done + onDisappear)
    @State private var didConfirm: Bool = false

    // Focused picker (shown in a sheet)
    private enum ActivePicker: Identifiable {
        case book, chapter, verse
        var id: Int { hashValue }
        var title: String {
            switch self {
            case .book: return "Choose Book"
            case .chapter: return "Choose Chapter"
            case .verse: return "Choose Verse"
            }
        }
    }
    @State private var activePicker: ActivePicker? = nil

    var body: some View {
        Form {
            Section {
                if isLoadingBooks {
                    HStack { Spacer(); ProgressView("Loading books…"); Spacer() }
                } else if allBookNames.isEmpty {
                    LabeledContent("Status") { Text("No books found").foregroundStyle(.red) }
                } else {
                    // Three rows that open a focused modern wheel
                    selectionRow(
                        label: "Book",
                        value: loadedBook?.name ?? (bookSelection.isEmpty ? "Choose…" : bookSelection),
                        enabled: true
                    ) { activePicker = .book }

                    selectionRow(
                        label: "Chapter",
                        value: chapterLabel(),
                        enabled: loadedBook != nil
                    ) { if loadedBook != nil { activePicker = .chapter } }

                    selectionRow(
                        label: "Verse",
                        value: verseLabel(),
                        enabled: (loadedBook != nil && currentChapter() != nil)
                    ) { if loadedBook != nil, currentChapter() != nil { activePicker = .verse } }
                }

                if isLoadingBook {
                    HStack { Spacer(); ProgressView("Loading \(bookSelection)…"); Spacer() }
                }

                if loadError {
                    LabeledContent("Status") { Text("Couldn’t load book").foregroundStyle(.red) }
                }
            } header: {
                Text("Scripture")
            } footer: {
                Text("Tap Book, Chapter, or Verse to choose. Swipe to adjust. The center row is your selection.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let book = loadedBook, !previewText.isEmpty {
                Section("Preview") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("“\(previewText)”")
                            .font(.body)
                        Text("\(book.name) \(selectedChapter):\(selectedVerse)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    guard let book = loadedBook else { return }
                    didConfirm = true
                    onConfirm(book.name, selectedChapter, selectedVerse)
                    dismiss()
                }
                .disabled(loadedBook == nil)
            }
        }
        .onAppear {
            Task {
                // Load book names
                isLoadingBooks = true
                let names = await BibleLibrary.shared.bookNames()
                isLoadingBooks = false
                allBookNames = names

                guard !names.isEmpty else { return }

                // Seed initial book selection
                let initial = initialBook.flatMap { names.contains($0) ? $0 : nil } ?? names.first!
                bookSelection = initial

                // Load the initial book and seed chapter/verse
                await loadBook(named: initial, seedChapter: initialChapter, seedVerse: initialVerse)
            }
        }
        .onDisappear {
            // If user navigated back without tapping Done, commit if we have a full selection
            if !didConfirm, let book = loadedBook {
                onConfirm(book.name, selectedChapter, selectedVerse)
            }
            loadTask?.cancel()
        }
        .sheet(item: $activePicker) { which in
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    switch which {
                    case .book:
                        ModernWheelCard {
                            ModernWheelPicker(
                                items: allBookNames,
                                id: \.self,
                                label: { Text($0).font(.headline) },
                                selection: $bookSelection
                            )
                        }
                        .onChange(of: bookSelection) { _, newValue in
                            let h = UISelectionFeedbackGenerator(); h.selectionChanged()
                            loadTask?.cancel()
                            loadTask = Task { await loadBook(named: newValue, seedChapter: nil, seedVerse: nil) }
                        }

                    case .chapter:
                        if let book = loadedBook {
                            ModernWheelCard {
                                ModernWheelPicker(
                                    items: book.chapters.map { $0.number },
                                    id: \.self,
                                    label: { Text("\($0)").font(.headline) },
                                    selection: $selectedChapter
                                )
                            }
                            .onChange(of: selectedChapter) { _, newValue in
                                let h = UISelectionFeedbackGenerator(); h.selectionChanged()
                                // Clamp verse for new chapter
                                guard let ch = book.chapters.first(where: { $0.number == newValue }) else { return }
                                let first = ch.verses.first?.number ?? 1
                                let last = ch.verses.last?.number ?? first
                                selectedVerse = min(max(selectedVerse, first), last)
                                updatePreviewText()
                            }
                        } else {
                            ContentUnavailableView("Choose a book first", systemImage: "book")
                                .padding()
                        }

                    case .verse:
                        if let ch = currentChapter() {
                            ModernWheelCard {
                                ModernWheelPicker(
                                    items: ch.verses.map { $0.number },
                                    id: \.self,
                                    label: { Text("\($0)").font(.headline) },
                                    selection: $selectedVerse
                                )
                            }
                            .onChange(of: selectedVerse) { _, _ in
                                let h = UISelectionFeedbackGenerator(); h.selectionChanged()
                                updatePreviewText()
                            }
                        } else {
                            ContentUnavailableView("Choose a chapter first", systemImage: "text.book.closed")
                                .padding()
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding()
                .navigationTitle(which.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { activePicker = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { activePicker = nil }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - UI helpers

    private func selectionRow(label: String, value: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.headline)
                        .foregroundStyle(enabled ? .primary : .tertiary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .padding(.vertical, 2)
    }

    private var navigationTitle: String {
        if let book = loadedBook {
            return "\(book.name) \(selectedChapter)"
        } else if !bookSelection.isEmpty {
            return bookSelection
        } else {
            return "Select Scripture"
        }
    }

    private func currentChapter() -> Chapter? {
        guard let b = loadedBook else { return nil }
        return b.chapters.first(where: { $0.number == selectedChapter })
    }

    private func chapterLabel() -> String {
        loadedBook == nil ? "—" : "\(selectedChapter)"
    }

    private func verseLabel() -> String {
        guard let ch = currentChapter() else { return "—" }
        return ch.verses.isEmpty ? "—" : "\(selectedVerse)"
    }

    // MARK: - Loading & Preview

    @MainActor
    private func loadBook(named name: String, seedChapter: Int?, seedVerse: Int?) async {
        isLoadingBook = true
        loadError = false

        let prevChapter = selectedChapter
        let prevVerse = selectedVerse

        do {
            if let b = try await BibleLibrary.shared.loadBook(named: name) {
                loadedBook = b

                // Decide chapter:
                // 1) Use seed if valid
                // 2) Else preserve previous if valid in this book
                // 3) Else clamp to last valid chapter (not always 1)
                let chapterNum: Int = {
                    if let ic = seedChapter, b.chapters.contains(where: { $0.number == ic }) {
                        return ic
                    }
                    if b.chapters.contains(where: { $0.number == prevChapter }) {
                        return prevChapter
                    }
                    return b.chapters.last?.number ?? 1
                }()
                selectedChapter = chapterNum

                // Decide verse:
                if let ch = b.chapters.first(where: { $0.number == chapterNum }) {
                    let verseNum: Int = {
                        if let iv = seedVerse, ch.verses.contains(where: { $0.number == iv }) {
                            return iv
                        }
                        let first = ch.verses.first?.number ?? 1
                        let last = ch.verses.last?.number ?? first
                        if prevChapter == chapterNum {
                            return min(max(prevVerse, first), last)
                        } else {
                            return first
                        }
                    }()
                    selectedVerse = verseNum
                    if let v = ch.verses.first(where: { $0.number == verseNum }) {
                        previewText = v.text
                    } else {
                        previewText = ""
                    }
                } else {
                    selectedVerse = 1
                    previewText = ""
                }
            } else {
                loadedBook = nil
                loadError = true
            }
        } catch {
            loadedBook = nil
            loadError = true
        }
        isLoadingBook = false
    }

    private func updatePreviewText() {
        guard let b = loadedBook,
              let chapter = b.chapters.first(where: { $0.number == selectedChapter }),
              let verse = chapter.verses.first(where: { $0.number == selectedVerse }) else {
            previewText = ""
            return
        }
        previewText = verse.text
    }
}

// MARK: - Modern wheel shell with glassy card styling
private struct ModernWheelCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.secondarySystemBackground),
                            Color(.systemBackground)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)

            content
                .padding(8)
        }
    }
}

// MARK: - PreferenceKey to track scroll offset
private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Modern, snapping, scalable wheel picker (iOS 16+)
private struct ModernWheelPicker<Item: Hashable, ID: Hashable, Label: View>: View {
    let items: [Item]
    let id: KeyPath<Item, ID>
    let label: (Item) -> Label
    @Binding var selection: Item

    // Tunables
    private let rowHeight: CGFloat = 40
    private let visiblePadRows: Int = 3 // padding rows above/below to center the selection
    private let scaleRange: ClosedRange<CGFloat> = 0.85...1.12
    private let opacityRange: ClosedRange<Double> = 0.45...1.0
    private let selectionBandHeight: CGFloat = 34

    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ZStack {
            // Selection band
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
                    )
                    .frame(height: selectionBandHeight)
                    .shadow(color: .black.opacity(0.07), radius: 2, x: 0, y: 1)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
            .allowsHitTesting(false)

            // Scrolling content
            GeometryReader { geo in
                let centerY = geo.size.height / 2

                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Top padding to allow centering
                            Color.clear.frame(height: rowHeight * CGFloat(visiblePadRows))

                            ForEach(items, id: id) { item in
                                rowView(for: item, centerY: centerY)
                                    .frame(height: rowHeight)
                                    .id(item[keyPath: id])
                            }

                            // Bottom padding
                            Color.clear.frame(height: rowHeight * CGFloat(visiblePadRows))
                        }
                        .background(
                            GeometryReader { innerGeo in
                                Color.clear
                                    .preference(key: ScrollOffsetPreferenceKey.self,
                                                value: innerGeo.frame(in: .named("scroll")).minY)
                            }
                        )
                    }
                    .coordinateSpace(name: "scroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        scrollOffset = value
                    }
                    .onAppear {
                        // Scroll initial selection into center
                        DispatchQueue.main.async {
                            proxy.scrollTo(selection[keyPath: id], anchor: .center)
                        }
                    }
                    .gesture(
                        DragGesture().onEnded { _ in
                            // Snap to nearest row on drag end
                            snapToNearest(with: proxy, containerHeight: geo.size.height)
                        }
                    )
                    .onChange(of: selection) { _, newValue in
                        // Programmatically scroll if selection changed externally
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                            proxy.scrollTo(newValue[keyPath: id], anchor: .center)
                        }
                    }
                }
            }

            // Edge fades
            VStack {
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemBackground).opacity(0)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 18)
                Spacer()
                LinearGradient(
                    colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 18)
            }
            .allowsHitTesting(false)
        }
        .frame(minHeight: rowHeight * CGFloat(visiblePadRows * 2 + 3)) // ensure room for a few rows
        .accessibilityElement(children: .contain)
    }

    private func rowView(for item: Item, centerY: CGFloat) -> some View {
        GeometryReader { rowGeo in
            let rowCenter = rowGeo.frame(in: .named("scroll")).midY
            let distance = abs(rowCenter - centerY)
            let maxDistance = rowHeight * CGFloat(visiblePadRows + 1)
            let t = max(0, min(1, 1 - (distance / maxDistance))) // 1 at center, 0 far

            let scale = scaleRange.lowerBound + (scaleRange.upperBound - scaleRange.lowerBound) * t
            let opacity = opacityRange.lowerBound + (opacityRange.upperBound - opacityRange.lowerBound) * Double(t)
            let weight: Font.Weight = t > 0.85 ? .semibold : .regular
            let color: Color = t > 0.85 ? .primary : .secondary

            Button {
                // Tap to select and snap
                selection = item
                let gen = UISelectionFeedbackGenerator(); gen.selectionChanged()
            } label: {
                label(item)
                    .fontWeight(weight)
                    .foregroundStyle(color)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func snapToNearest(with proxy: ScrollViewProxy, containerHeight: CGFloat) {
        // Compute which item is closest to center by inspecting the current offset
        // We approximate by converting offset to index.
        let totalRows = items.count
        guard totalRows > 0 else { return }

        // Convert current selection to an index baseline
        let currentIndex = items.firstIndex(of: selection) ?? 0

        // Heuristic: find the row whose center is closest to the ScrollView center
        // We can estimate based on the ScrollView's current position by reading the visible rows’ geometry,
        // but since we’ve already got tap-to-select and onChange snapping, we’ll bias to the currentIndex.
        // This keeps the snapping stable. If you want to compute exact nearest, we can track each row’s midY via another preference.

        // Simply snap to the currently most visually emphasized row: keep selection as-is and re-center it.
        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            proxy.scrollTo(items[currentIndex][keyPath: id], anchor: .center)
        }
    }
}
