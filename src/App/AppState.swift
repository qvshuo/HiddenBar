struct AppState {
    enum PlatformPhase: Equatable {
        case idle
        case installing
        case awaitingOrderingValidation
        case applied
        case retryScheduled(attempt: Int)
        case degraded
    }

    var configuration: MenuBarConfiguration = .standard
    var mode: MenuBarMode = .collapsed
    var alwaysHiddenVisible = false
    var isControllerRunning = false
    var isToggleDebounced = false
    var platformPhase: PlatformPhase = .idle
}
