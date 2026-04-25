import Foundation

struct MenuBarLayoutEngine: Sendable {
    func makeLayout(
        mode: MenuBarMode,
        alwaysHiddenVisible: Bool,
        configuration: MenuBarConfiguration,
        screenWidth: CGFloat
    ) -> MenuBarLayout {
        let collapseLength = max(
            configuration.minimumHiddenLength,
            min(screenWidth + configuration.hiddenLengthPadding, configuration.maximumHiddenLength)
        )

        let primarySeparatorLength: CGFloat
        switch mode {
        case .collapsed:
            primarySeparatorLength = collapseLength
        case .expanded:
            primarySeparatorLength = configuration.visibleSeparatorLength
        }

        let alwaysHiddenSeparatorLength: CGFloat
        if !configuration.alwaysHiddenEnabled {
            alwaysHiddenSeparatorLength = 0
        } else if alwaysHiddenVisible {
            alwaysHiddenSeparatorLength = configuration.visibleSeparatorLength
        } else {
            alwaysHiddenSeparatorLength = collapseLength
        }

        return MenuBarLayout(
            primarySeparatorLength: primarySeparatorLength,
            alwaysHiddenSeparatorLength: alwaysHiddenSeparatorLength
        )
    }
}
