# Curtain Agent Guide

## Project Overview
macOS menu bar utility to hide/show menu bar icons. Swift 6, macOS 26+, Apple Silicon only. Single Xcode project.

## Build & Run
```bash
# Build (release, no signing)
xcodebuild -project "Curtain.xcodeproj" -scheme "Curtain" -configuration Release -derivedDataPath DerivedData CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build

# App location after build
DerivedData/Build/Products/Release/Curtain.app
```

## Architecture
- **Entry**: `CurtainApp.swift` — SwiftUI `@main` with `MenuBarAppDelegate` adaptor
- **State**: `AppState` + `AppAction` (Redux-like)
- **Store**: `MenuBarStore` (singleton, `@Observable`, `@MainActor`)
- **Controller**: `MenuBarController` (AppKit, manages `NSStatusItem` + layout engine)
- **Model**: `MenuBarMode` (collapsed/expanded), `MenuBarLayout`, `MenuBarConfiguration`, `MenuBarPresentation`

## Key Conventions
- **No tests** in project
- **Swift 6 strict concurrency** enabled (`SWIFT_STRICT_CONCURRENCY = complete`)
- **Manual code signing** (`CODE_SIGN_STYLE = Manual`, identity `-` for CI)
- **LSUIElement = true** (menu bar only, no Dock icon)
- **Version/Build**: `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in Xcode config

## CI (GitHub Actions)
- Trigger: `workflow_dispatch` (manual)
- Runs on `macos-latest`
- Builds unsigned, packages `.zip`, creates GitHub Release

## Development
- Open `Curtain.xcodeproj` in Xcode
- Debug config: `DEBUG=1`, no optimization
- Release config: whole-module optimization, `-O`

## Gotchas
- Must run `xattr -cr "/Applications/Curtain.app"` after installing downloaded build (quarantine)
- No Swift Package Manager — Xcode project only
- No external dependencies (stdlib + AppKit + SwiftUI + Observation only)
