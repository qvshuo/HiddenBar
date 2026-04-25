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
    private var pendingMode: MenuBarMode = .collapsed
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
        toggle.autosaveName = "hiddenbar.toggle"

        let separator = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        separator.autosaveName = "hiddenbar.primary-separator"

        if let button = toggle.button {
            button.image = collapseImage()
            button.target = self
            button.action = #selector(handleToggleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        if let button = separator.button {
            button.image = separatorImage()
            button.appearsDisabled = true
        }

        toggleItem = toggle
        primarySeparatorItem = separator
        schedulePendingApply()
    }

    func setPresentation(
        mode: MenuBarMode,
        alwaysHiddenEnabled: Bool,
        layout: MenuBarLayout
    ) {
        pendingMode = mode
        pendingAlwaysHiddenEnabled = alwaysHiddenEnabled
        pendingLayout = layout
        schedulePendingApply()
    }

    func removeStatusItems() {
        pendingApplyTask?.cancel()
        pendingApplyTask = nil
        isApplyScheduled = false
        pendingLayout = nil

        if let toggleItem {
            toggleItem.menu = nil
            NSStatusBar.system.removeStatusItem(toggleItem)
            self.toggleItem = nil
        }

        if let primarySeparatorItem {
            NSStatusBar.system.removeStatusItem(primarySeparatorItem)
            self.primarySeparatorItem = nil
        }

        if let alwaysHiddenSeparatorItem {
            NSStatusBar.system.removeStatusItem(alwaysHiddenSeparatorItem)
            self.alwaysHiddenSeparatorItem = nil
        }
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
            NSMenuItem(title: "Quit Hidden Bar", action: #selector(quitApplication), keyEquivalent: "q")
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

    private func collapseImage() -> NSImage? {
        let image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Collapse Hidden Bar")
        image?.isTemplate = true
        return image
    }

    private func expandImage() -> NSImage? {
        let image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Expand Hidden Bar")
        image?.isTemplate = true
        return image
    }

    private func separatorImage() -> NSImage {
        let size = NSSize(width: 2, height: 18)
        let image = NSImage(size: size)
        image.isTemplate = true

        image.lockFocus()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 0.5, y: 2))
        path.line(to: NSPoint(x: 0.5, y: size.height - 2))
        path.lineWidth = 1
        NSColor.black.setStroke()
        path.stroke()
        image.unlockFocus()

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
        guard let toggleItem, let primarySeparatorItem, let pendingLayout else {
            return
        }

        toggleItem.button?.image = pendingMode == .collapsed ? expandImage() : collapseImage()

        if pendingAlwaysHiddenEnabled {
            if alwaysHiddenSeparatorItem == nil {
                let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                item.autosaveName = "hiddenbar.always-hidden-separator"
                item.button?.image = separatorImage()
                item.button?.appearsDisabled = true
                alwaysHiddenSeparatorItem = item
            }
        } else if let item = alwaysHiddenSeparatorItem {
            NSStatusBar.system.removeStatusItem(item)
            alwaysHiddenSeparatorItem = nil
        }

        guard hasValidOrdering else { return }

        primarySeparatorItem.length = pendingLayout.primarySeparatorLength
        alwaysHiddenSeparatorItem?.length = pendingLayout.alwaysHiddenSeparatorLength
    }
}
