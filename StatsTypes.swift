import Foundation

public enum BookFilter: String, CaseIterable, Identifiable {
    case all
    case ot
    case nt
    public var id: String { rawValue }
}
