import Foundation

public enum BookFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case ot = "OT"
    case nt = "NT"
    public var id: String { rawValue }
}
