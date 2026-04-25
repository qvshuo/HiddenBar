import Foundation

enum MenuBarMode: Sendable, Equatable {
    case expanded
    case collapsed

    mutating func toggle() {
        self = self == .expanded ? .collapsed : .expanded
    }
}