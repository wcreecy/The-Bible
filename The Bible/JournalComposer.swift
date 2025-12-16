import Foundation
import SwiftUI
import Combine

@MainActor
final class JournalComposer: ObservableObject {
    @Published var isPresented: Bool = false
    @Published var initialBody: String? = nil
    @Published var verseRef: VerseRef? = nil
    @Published var showTagColors: Bool = false
    @Published var editingEntry: JournalEntry? = nil

    func present(initialBody: String? = nil, verseRef: VerseRef? = nil, showTagColors: Bool = false) {
        self.initialBody = initialBody
        self.verseRef = verseRef
        self.showTagColors = showTagColors
        self.editingEntry = nil
        self.isPresented = true
    }

    func dismiss() {
        self.isPresented = false
    }
    
    func presentForEditing(entry: JournalEntry) {
        self.editingEntry = entry
        self.initialBody = entry.body
        self.verseRef = entry.verseRef
        self.showTagColors = false
        self.isPresented = true
    }
}
