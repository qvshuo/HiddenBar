import AppKit
import Observation

@MainActor
@Observable
final class MenuBarStore {
    static let shared = MenuBarStore()

    private static let toggleDebounceInterval: Duration = .seconds(0.3)
    private static let autoHideInterval: Duration = .seconds(30)

    var appState = AppState()

    @ObservationIgnored
    private lazy var controller = MenuBarController(state: self)
    @ObservationIgnored
    private var toggleDebounceTask: Task<Void, Never>?
    @ObservationIgnored
    private var autoHideTask: Task<Void, Never>?
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
        let effects = reduce(action)

        for effect in effects {
            switch effect {
            case .none:
                break
            case .scheduleToggleDebounceReset:
                scheduleToggleDebounceReset()
            case .scheduleAutoHide:
                scheduleAutoHide()
            case .cancelAutoHide:
                cancelAutoHide()
            case .applyCurrentMode:
                controller.applyCurrentMode()
            case .quit:
                NSApp.terminate(nil)
            }
        }
    }

    func bootstrapIfNeeded() {
        guard !didBootstrap else { return }
        didBootstrap = true
        startControllerIfNeeded()
    }

    private func reduce(_ action: AppAction) -> [Effect] {
        switch action {
        case .quitRequested:
            return [.cancelAutoHide, .quit]

        case .menuBarToggleRequested:
            guard !isToggleDebounced else { return [.none] }

            isToggleDebounced = true
            appState.mode.toggle()

            if appState.mode == .expanded {
                return [.scheduleToggleDebounceReset, .scheduleAutoHide]
            } else {
                return [.scheduleToggleDebounceReset, .cancelAutoHide]
            }

        case .alwaysHiddenToggleRequested:
            appState.alwaysHiddenVisible.toggle()

            if appState.mode == .expanded {
                return [.applyCurrentMode, .scheduleAutoHide]
            } else {
                return [.applyCurrentMode]
            }

        case .screenParametersChanged:
            return [.applyCurrentMode]

        case .autoHideTimerFired:
            guard appState.mode == .expanded else {
                return [.cancelAutoHide]
            }

            appState.mode = .collapsed
            return [.applyCurrentMode, .cancelAutoHide]
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

    private func scheduleAutoHide() {
        autoHideTask?.cancel()
        autoHideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.autoHideInterval)
            guard let self, !Task.isCancelled else { return }
            self.autoHideTask = nil
            self.send(.autoHideTimerFired)
        }
    }

    private func cancelAutoHide() {
        autoHideTask?.cancel()
        autoHideTask = nil
    }

    enum Effect {
        case none
        case scheduleToggleDebounceReset
        case scheduleAutoHide
        case cancelAutoHide
        case applyCurrentMode
        case quit
    }
}
