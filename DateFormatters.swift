import Foundation

enum DateFormatters {
    static let shortDateTime: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df
    }()

    static func shortDateTimeString(_ date: Date?) -> String {
        guard let date else { return "—" }
        return shortDateTime.string(from: date)
    }
}
