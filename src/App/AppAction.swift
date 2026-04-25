enum AppAction {
    case menuBarToggleRequested
    case alwaysHiddenToggleRequested
    case screenParametersChanged
    case platformInstallationStarted
    case platformAwaitingOrderingValidation
    case platformPresentationApplied
    case platformRetryScheduled(attempt: Int)
    case platformDegraded
    case quitRequested
}
