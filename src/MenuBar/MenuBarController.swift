import AppKit
import Observation

@MainActor
final class MenuBarController {
    private static let initialRetryIntervals: [Duration] = [.seconds(0.3), .seconds(0.6), .seconds(1.0), .seconds(2.0), .seconds(3.0)]

    var onToggleRequested: (@MainActor () -> Void)?
    var onAlwaysHiddenToggleRequested: (@MainActor () -> Void)?
    var onScreenParametersChanged: (@MainActor () -> Void)?
    var onInstallationStarted: (@MainActor () -> Void)?
    var onAwaitingOrderingValidation: (@MainActor () -> Void)?
    var onPresentationApplied: (@MainActor () -> Void)?
    var onRetryScheduled: (@MainActor (Int) -> Void)?
    var onDegraded: (@MainActor () -> Void)?
    var onQuitRequested: (@MainActor () -> Void)?

    @ObservationIgnored
    private let state: MenuBarStore
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
            self.onInstallationStarted?()
            self.host.installStatusItems()
            self.applyCurrentMode()
            self.scheduleInitialRetries()
        }
    }

    func stop() {
        observationTask?.cancel()
        observationTask = nil
        observationGeneration += 1
        screenChangeTask?.cancel()
        screenChangeTask = nil
        cancelPendingRetries()
        host.removeStatusItems()
        host.onToggle = nil
        host.onAlternateToggle = nil
        host.onQuit = nil
        onToggleRequested = nil
        onAlwaysHiddenToggleRequested = nil
        onScreenParametersChanged = nil
        onInstallationStarted = nil
        onAwaitingOrderingValidation = nil
        onPresentationApplied = nil
        onRetryScheduled = nil
        onDegraded = nil
        onQuitRequested = nil
        didStart = false
    }

    func applyCurrentMode() {
        let presentation = currentPresentation(screenWidth: host.currentScreenWidth)
        host.setPresentation(
            mode: presentation.mode,
            alwaysHiddenEnabled: presentation.alwaysHiddenEnabled,
            layout: presentation.layout
        )

        if host.hasValidOrdering {
            onPresentationApplied?()
        } else {
            onAwaitingOrderingValidation?()
        }
    }

    private func currentPresentation(screenWidth: CGFloat) -> MenuBarPresentation {
        let layout = layoutEngine.makeLayout(
            mode: state.appState.mode,
            alwaysHiddenVisible: state.appState.alwaysHiddenVisible,
            configuration: state.appState.configuration,
            screenWidth: screenWidth
        )

        return MenuBarPresentation(
            mode: state.appState.mode,
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
                _ = self.state.appState.configuration
                _ = self.state.appState.mode
                _ = self.state.appState.alwaysHiddenVisible
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

        for (index, interval) in Self.initialRetryIntervals.enumerated() {
            let task = Task { @MainActor [weak self] in
                try? await Task.sleep(for: interval)
                guard let self, !Task.isCancelled else { return }
                guard !self.host.hasValidOrdering else { return }
                self.onRetryScheduled?(index + 1)
                self.applyCurrentMode()

                if index == Self.initialRetryIntervals.count - 1, !self.host.hasValidOrdering {
                    self.onDegraded?()
                }
            }
            retryTasks.append(task)
        }
    }

    private func cancelPendingRetries() {
        retryTasks.forEach { $0.cancel() }
        retryTasks.removeAll()
    }
}
