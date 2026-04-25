import AppKit
import Observation

@MainActor
@Observable
final class MenuBarStore {
    static let shared = MenuBarStore()

    private static let toggleDebounceInterval: Duration = .seconds(0.3)

    var appState = AppState()

    @ObservationIgnored
    private lazy var controller = MenuBarController(state: self)
    @ObservationIgnored
    private var toggleDebounceTask: Task<Void, Never>?
    @ObservationIgnored
    private var didBootstrap = false

    init() {
        controller.onToggleRequested = { [weak self] in
            self?.send(.menuBarToggleRequested)
        }

        controller.onAlwaysHiddenToggleRequested = { [weak self] in
            self?.send(.alwaysHiddenToggleRequested)
        }

        controller.onScreenParametersChanged = { [weak self] in
            self?.send(.screenParametersChanged)
        }

        controller.onInstallationStarted = { [weak self] in
            self?.send(.platformInstallationStarted)
        }

        controller.onAwaitingOrderingValidation = { [weak self] in
            self?.send(.platformAwaitingOrderingValidation)
        }

        controller.onPresentationApplied = { [weak self] in
            self?.send(.platformPresentationApplied)
        }

        controller.onRetryScheduled = { [weak self] attempt in
            self?.send(.platformRetryScheduled(attempt: attempt))
        }

        controller.onDegraded = { [weak self] in
            self?.send(.platformDegraded)
        }

        controller.onQuitRequested = { [weak self] in
            self?.send(.quitRequested)
        }
    }

    func send(_ action: AppAction) {
        let effect = reduce(action)

        switch effect {
        case .none:
            break
        case .scheduleToggleDebounceReset:
            scheduleToggleDebounceReset()
        case .applyCurrentMode:
            controller.applyCurrentMode()
        case .quit:
            NSApp.terminate(nil)
        }
    }

    func bootstrapIfNeeded() {
        guard !didBootstrap else { return }
        didBootstrap = true
        startControllerIfNeeded()
    }

    private func reduce(_ action: AppAction) -> Effect {
        switch action {
        case .quitRequested:
            return .quit

        case .menuBarToggleRequested:
            guard appState.isControllerRunning else { return .none }
            guard !appState.isToggleDebounced else { return .none }

            appState.isToggleDebounced = true
            appState.mode.toggle()
            return .scheduleToggleDebounceReset

        case .alwaysHiddenToggleRequested:
            guard appState.isControllerRunning else { return .none }
            appState.alwaysHiddenVisible.toggle()
            return .none

        case .screenParametersChanged:
            guard appState.isControllerRunning else { return .none }
            return .applyCurrentMode

        case .platformInstallationStarted:
            appState.platformPhase = .installing
            return .none

        case .platformAwaitingOrderingValidation:
            guard appState.isControllerRunning else { return .none }
            appState.platformPhase = .awaitingOrderingValidation
            return .none

        case .platformPresentationApplied:
            guard appState.isControllerRunning else { return .none }
            appState.platformPhase = .applied
            return .none

        case let .platformRetryScheduled(attempt):
            guard appState.isControllerRunning else { return .none }
            switch appState.platformPhase {
            case .awaitingOrderingValidation, .retryScheduled:
                appState.platformPhase = .retryScheduled(attempt: attempt)
            default:
                return .none
            }
            return .none

        case .platformDegraded:
            guard appState.isControllerRunning else { return .none }
            appState.platformPhase = .degraded
            return .none
        }
    }

    private func startControllerIfNeeded() {
        guard !appState.isControllerRunning else { return }
        appState.platformPhase = .installing
        controller.start()
        appState.isControllerRunning = true
    }

    private func scheduleToggleDebounceReset() {
        toggleDebounceTask?.cancel()
        toggleDebounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.toggleDebounceInterval)
            guard let self, !Task.isCancelled else { return }
            self.appState.isToggleDebounced = false
            self.toggleDebounceTask = nil
        }
    }

    enum Effect {
        case none
        case scheduleToggleDebounceReset
        case applyCurrentMode
        case quit
    }
}
