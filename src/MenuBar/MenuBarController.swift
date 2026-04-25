import AppKit
import Observation

@MainActor
final class MenuBarController {
    private static let initialRetryIntervals: [Duration] = [.seconds(0.3), .seconds(0.6), .seconds(1.0), .seconds(2.0), .seconds(3.0)]

    var onToggleRequested: (@MainActor () -> Void)?
    var onAlwaysHiddenToggleRequested: (@MainActor () -> Void)?
    var onScreenParametersChanged: (@MainActor () -> Void)?
    var onQuitRequested: (@MainActor () -> Void)?

    @ObservationIgnored
    private weak var state: MenuBarStore?
    private let host: SystemStatusItemHost
    private let layoutEngine: MenuBarLayoutEngine
    private var didStart = false
    private var retryTasks: [Task<Void, Never>] = []
    private var observationTask: Task<Void, Never>?
    private var screenChangeTask: Task<Void, Never>?
    private var observationGeneration = 0

    init(
        state: MenuBarStore,
        host: SystemStatusItemHost = SystemStatusItemHost(),
        layoutEngine: MenuBarLayoutEngine = MenuBarLayoutEngine()
    ) {
        self.state = state
        self.host = host
        self.layoutEngine = layoutEngine
    }

    func start() {
        guard !didStart else { return }
        didStart = true

        observeState()
        observeScreenChanges()

        host.onToggle = { [weak self] in
            self?.onToggleRequested?()
        }

        host.onAlternateToggle = { [weak self] in
            self?.onAlwaysHiddenToggleRequested?()
        }

        host.onQuit = { [weak self] in
            self?.onQuitRequested?()
        }

        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self else { return }
            self.host.installStatusItems()
            self.applyCurrentMode()
            self.scheduleInitialRetries()
        }
    }

    func applyCurrentMode() {
        guard let presentation = currentPresentation(screenWidth: host.currentScreenWidth) else {
            return
        }

        host.setPresentation(
            alwaysHiddenEnabled: presentation.alwaysHiddenEnabled,
            layout: presentation.layout
        )

        if host.hasValidOrdering {
            cancelPendingRetries()
        }
    }

    private func currentPresentation(screenWidth: CGFloat) -> MenuBarPresentation? {
        guard let state else { return nil }

        let layout = layoutEngine.makeLayout(
            mode: state.appState.mode,
            alwaysHiddenVisible: state.appState.alwaysHiddenVisible,
            configuration: state.appState.configuration,
            screenWidth: screenWidth
        )

        return MenuBarPresentation(
            alwaysHiddenEnabled: state.appState.configuration.alwaysHiddenEnabled,
            layout: layout
        )
    }

    private func observeState() {
        observationTask?.cancel()
        observationGeneration += 1
        let generation = observationGeneration
        observationTask = Task { @MainActor [weak self] in
            guard let self else { return }

            withObservationTracking {
                guard let state = self.state else { return }
                _ = state.appState.configuration
                _ = state.appState.mode
                _ = state.appState.alwaysHiddenVisible
            } onChange: { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self, self.didStart, self.observationGeneration == generation else { return }
                    self.applyCurrentMode()
                    self.observeState()
                }
            }
        }
    }

    private func observeScreenChanges() {
        screenChangeTask?.cancel()
        screenChangeTask = Task { @MainActor [weak self] in
            let notifications = NotificationCenter.default.notifications(
                named: NSApplication.didChangeScreenParametersNotification
            )

            for await _ in notifications {
                guard let self, !Task.isCancelled else { return }
                self.onScreenParametersChanged?()
            }
        }
    }

    private func scheduleInitialRetries() {
        cancelPendingRetries()

        for interval in Self.initialRetryIntervals {
            let task = Task { @MainActor [weak self] in
                try? await Task.sleep(for: interval)
                guard let self, !Task.isCancelled else { return }
                guard !self.host.hasValidOrdering else { return }
                self.applyCurrentMode()
            }
            retryTasks.append(task)
        }
    }

    private func cancelPendingRetries() {
        retryTasks.forEach { $0.cancel() }
        retryTasks.removeAll()
    }
}
