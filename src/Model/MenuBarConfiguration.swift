import Foundation

struct MenuBarConfiguration: Sendable {
    let alwaysHiddenEnabled: Bool

    let visibleSeparatorLength: CGFloat
    let hiddenLengthPadding: CGFloat
    let minimumHiddenLength: CGFloat
    let maximumHiddenLength: CGFloat

    static let standard = MenuBarConfiguration(
        alwaysHiddenEnabled: true,
        visibleSeparatorLength: 20,
        hiddenLengthPadding: 200,
        minimumHiddenLength: 500,
        maximumHiddenLength: 4000
    )
}
