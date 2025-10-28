//
//  ContentView.swift
//  The Bible
//
//  Shows the Books list on launch.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            BooksView(books: BibleData.books)
                .navigationTitle("Books")
        }
    }
}

#Preview {
    ContentView()
}
