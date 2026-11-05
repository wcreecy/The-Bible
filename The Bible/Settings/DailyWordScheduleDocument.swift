#if DEBUG
import SwiftUI
import UniformTypeIdentifiers

struct DailyWordScheduleDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    private let data: Data

    init(configuration: WordleDailyScheduleConfiguration) {
        data = (try? WordleDailySchedule.encodedConfiguration(configuration)) ?? Data()
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
#endif
