import AppKit

@MainActor
final class SystemStatusItemHost: NSObject, NSMenuDelegate {
    private static let fallbackScreenWidth: CGFloat = 1728

    var onToggle: (@MainActor () -> Void)?
    var onAlternateToggle: (@MainActor () -> Void)?
    var onQuit: (@MainActor () -> Void)?

    private var toggleItem: NSStatusItem?
    private var primarySeparatorItem: NSStatusItem?
    private var alwaysHiddenSeparatorItem: NSStatusItem?
    private var pendingAlwaysHiddenEnabled = false
    private var pendingLayout: MenuBarLayout?
    private var isApplyScheduled = false
    private var pendingApplyTask: Task<Void, Never>?

    var hasValidOrdering: Bool {
        guard let toggleItem, let primarySeparatorItem else {
            return false
        }
        guard
            let toggleX = toggleItem.button?.window?.frame.origin.x,
            let primaryX = primarySeparatorItem.button?.window?.frame.origin.x
        else {
            return false
        }
        guard let alwaysHiddenSeparatorItem else {
            return toggleX >= primaryX
        }
        guard let alwaysHiddenX = alwaysHiddenSeparatorItem.button?.window?.frame.origin.x else {
            return false
        }
        return toggleX >= primaryX && primaryX >= alwaysHiddenX
    }

    var currentScreenWidth: CGFloat {
        toggleItem?.button?.window?.screen?.visibleFrame.width
            ?? NSScreen.main?.visibleFrame.width
            ?? Self.fallbackScreenWidth
    }

    func installStatusItems() {
        guard toggleItem == nil, primarySeparatorItem == nil else {
            return
        }

        let toggle = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        toggle.autosaveName = "curtain.toggle"

        let separator = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        separator.autosaveName = "curtain.primary-separator"

        if let button = toggle.button {
            button.image = toggleImage()
            button.target = self
            button.action = #selector(handleToggleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        if let button = separator.button {
            button.image = primarySeparatorImage()
            button.appearsDisabled = true
        }

        toggleItem = toggle
        primarySeparatorItem = separator
        schedulePendingApply()
    }

    func setPresentation(
        alwaysHiddenEnabled: Bool,
        layout: MenuBarLayout
    ) {
        pendingAlwaysHiddenEnabled = alwaysHiddenEnabled
        pendingLayout = layout
        schedulePendingApply()
    }

    @objc
    private func handleToggleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            onToggle?()
            return
        }

        if event.type == .rightMouseUp {
            presentContextMenu(from: sender)
            return
        }

        if event.modifierFlags.contains(.option) {
            onAlternateToggle?()
            return
        }

        onToggle?()
    }

    @objc
    private func quitApplication() {
        onQuit?()
    }

    private lazy var contextMenu: NSMenu = {
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(
            NSMenuItem(title: "Quit Curtain", action: #selector(quitApplication), keyEquivalent: "")
        )
        menu.items.forEach { $0.target = self }
        return menu
    }()

    private func presentContextMenu(from sender: NSStatusBarButton) {
        guard let toggleItem else { return }
        toggleItem.menu = contextMenu
        sender.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        toggleItem?.menu = nil
    }

    private func toggleImage() -> NSImage {
        let diameter: CGFloat = 5
        let size = NSSize(width: diameter, height: diameter)
        return NSImage(size: size, flipped: false) { rect in
            NSColor.white.setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
    }

    private func primarySeparatorImage() -> NSImage {
        separatorImage(dashPattern: nil)
    }

    private func alwaysHiddenSeparatorImage() -> NSImage {
        separatorImage(dashPattern: [2, 2])
    }

    private func separatorImage(dashPattern: [CGFloat]?) -> NSImage {
        let lineWidth: CGFloat = 2
        let size = NSSize(width: lineWidth, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            let path = NSBezierPath()
            path.move(to: NSPoint(x: lineWidth / 2, y: 2))
            path.line(to: NSPoint(x: lineWidth / 2, y: size.height - 2))
            path.lineWidth = lineWidth
            if let dashPattern {
                path.setLineDash(dashPattern, count: dashPattern.count, phase: 0)
            }
            NSColor.black.setStroke()
            path.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }

    private func schedulePendingApply() {
        guard !isApplyScheduled else { return }
        isApplyScheduled = true
        pendingApplyTask?.cancel()
        pendingApplyTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, !Task.isCancelled else { return }
            self.isApplyScheduled = false
            self.pendingApplyTask = nil
            self.applyPendingPresentation()
        }
    }

    private func applyPendingPresentation() {
        guard let primarySeparatorItem, let pendingLayout else {
            return
        }

        if pendingAlwaysHiddenEnabled {
            if alwaysHiddenSeparatorItem == nil {
                let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                item.autosaveName = "curtain.always-hidden-separator"
                item.button?.image = alwaysHiddenSeparatorImage()
                item.button?.appearsDisabled = true
                alwaysHiddenSeparatorItem = item
            }
        } else if let item = alwaysHiddenSeparatorItem {
            NSStatusBar.system.removeStatusItem(item)
            alwaysHiddenSeparatorItem = nil
        }

        primarySeparatorItem.length = pendingLayout.primarySeparatorLength

        guard hasValidOrdering else { return }

        alwaysHiddenSeparatorItem?.length = pendingLayout.alwaysHiddenSeparatorLength
    }
}
