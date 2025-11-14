import SwiftUI

struct ReaderFontToolbar: View {
    @Binding var readerFontSize: Double
    var body: some View {
        HStack {
            Button {
                readerFontSize = max(12, readerFontSize - 1)
            } label: {
                Image(systemName: "textformat.size.smaller")
            }
            .accessibilityLabel("Decrease font size")

            Button {
                readerFontSize = min(30, readerFontSize + 1)
            } label: {
                Image(systemName: "textformat.size.larger")
            }
            .accessibilityLabel("Increase font size")
        }
    }
}
