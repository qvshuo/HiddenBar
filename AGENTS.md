# Hidden Bar — Agent Notes

macOS menu-bar utility that hides status icons. Single Xcode target, no external dependencies.

## Build

```bash
xcodebuild \
  -project "Hidden Bar.xcodeproj" \
  -scheme "Hidden Bar" \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build
```

- Release is the default configuration if unspecified.
- Ad-hoc signing (`CODE_SIGN_IDENTITY="-"`) is required; the project has no development team and no provisioning profile.

## Architecture

- **Entry point:** `src/App/HiddenBarApp.swift` — `@main` SwiftUI `App` with a hidden `MenuBarExtra` scene.
- **Real UI:** AppKit-based. `MenuBarAppDelegate` bootstraps `MenuBarStore`, which owns `MenuBarController` → `SystemStatusItemHost` → `NSStatusBar` items.
- **State management:** Redux-like cycle in `MenuBarStore` (`AppState` + `AppAction` → `reduce` → `Effect`).
- **Observation:** Uses `@Observable` + `withObservationTracking`; `MenuBarController` re-applies layout whenever `AppState` properties change.
- **Layout:** `MenuBarLayoutEngine` computes separator lengths based on screen width, mode (`expanded`/`collapsed`), and `MenuBarConfiguration`.

## Key Quirks

- `LSUIElement` is `true` (`src/Info.plist`) — no dock icon, no main window.
- The app installs **two or three** `NSStatusItem`s (toggle dot, primary separator, optional always-hidden separator) and manipulates their `length` to push other menu-bar icons off-screen.
- `SystemStatusItemHost` defers layout changes with `Task.yield()` to let AppKit finish item ordering.
- Toggle actions are debounced (`0.3 s`) in `MenuBarStore`.
- Initial retries (`0.3 → 3 s`) schedule re-layout until `hasValidOrdering` confirms the status items are positioned left-to-right.

## Tests

No test targets exist.

## CI / Release

`.github/workflows/build-and-release.yml`:
- Trigger: `workflow_dispatch` only (manual).
- Builds Release, reads version from the built `Info.plist`, packages `Hidden Bar.app` into a zip, and creates a GitHub release with that tag.

## Source Layout

```
src/
  App/
    HiddenBarApp.swift          # @main
    MenuBarAppDelegate.swift    # NSApplicationDelegate
    MenuBarStore.swift          # State store + reducer
    AppState.swift              # Mutable app state
    AppAction.swift             # Enum of user/system actions
  MenuBar/
    MenuBarController.swift     # Orchestrates host + layout engine
    SystemStatusItemHost.swift  # NSStatusItem creation / click handling
    MenuBarLayoutEngine.swift   # Pure layout math
  Model/
    MenuBarConfiguration.swift  # Collapse/expand constants
    MenuBarLayout.swift         # Computed separator lengths
    MenuBarMode.swift           # expanded / collapsed
    MenuBarPresentation.swift   # Effect payload for host
  Assets.xcassets/
  Info.plist
```

## Environment

- **Deployment target:** macOS 26.0
- **Swift version:** 6.0 (`SWIFT_STRICT_CONCURRENCY = complete`)
- **Xcode:** 26.x (objectVersion 56)
- **Bundle ID:** `art.anjing.HiddenBar`
- **Version:** `1.2.0`
