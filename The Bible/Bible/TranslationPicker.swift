import SwiftUI

/// The reader's toolbar control: the active translation's abbreviation, opening a menu of
/// the others. Hidden while only one translation is bundled.
struct TranslationToolbarMenu: View {
    private var bibleStore = BibleStore.shared
    private let translations = BibleTranslation.available

    var body: some View {
        if translations.count > 1 {
            Menu {
                Picker("Translation", selection: TranslationSelection.binding) {
                    ForEach(translations) { translation in
                        Text(translation.abbreviation)
                        Text(translation.name)
                    }
                }
            } label: {
                Text(bibleStore.translation.abbreviation)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
            .disabled(bibleStore.isSwitchingTranslation)
            .accessibilityLabel("Translation")
            .accessibilityValue(bibleStore.translation.name)
            .accessibilityHint("Choose the Bible translation to read")
        }
    }
}

/// The Settings row for choosing a translation.
struct TranslationSettingsPicker: View {
    private var bibleStore = BibleStore.shared
    private let translations = BibleTranslation.available

    var body: some View {
        Picker(selection: TranslationSelection.binding) {
            ForEach(translations) { translation in
                Text(translation.name).tag(translation)
            }
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Translation")
                    Text("Used in the reader, search, games, and widgets")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "character.book.closed")
                    .foregroundStyle(.tint)
            }
        }
        .disabled(bibleStore.isSwitchingTranslation || translations.count < 2)
        .accessibilityIdentifier("bibleTranslationPicker")
    }
}

private enum TranslationSelection {
    @MainActor
    static var binding: Binding<BibleTranslation> {
        Binding(
            get: { BibleStore.shared.translation },
            set: { BibleStore.shared.selectTranslation($0) }
        )
    }
}
