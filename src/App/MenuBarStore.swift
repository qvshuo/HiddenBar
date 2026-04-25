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
    private var isToggleDebounced = false
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
            guard !isToggleDebounced else { return .none }

            isToggleDebounced = true
            appState.mode.toggle()
            return .scheduleToggleDebounceReset

        case .alwaysHiddenToggleRequested:
            appState.alwaysHiddenVisible.toggle()
            return .applyCurrentMode

        case .screenParametersChanged:
            return .applyCurrentMode
        }
    }

    private func startControllerIfNeeded() {
        controller.start()
    }

    private func scheduleToggleDebounceReset() {
        toggleDebounceTask?.cancel()
        toggleDebounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.toggleDebounceInterval)
            guard let self, !Task.isCancelled else { return }
            self.isToggleDebounced = false
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
