import SwiftUI
import SwiftData

struct NotesView: View {
    var body: some View {
        NotesListView()
    }
}

struct NotesView_Previews: PreviewProvider {
    static var previews: some View {
        NotesView()
            .modelContainer(for: [ReaderSettings.self, ReadingProgress.self, Favorite.self, Bookmark.self, VerseNote.self], inMemory: true)
    }
}
