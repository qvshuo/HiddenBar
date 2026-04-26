<p align="center">
  <img width="200" height="200" src="src/Assets.xcassets/AppIcon.appiconset/icon_512@2x.png">
</p>

# Hidden Bar

A modern, lightweight macOS utility that hides menu bar icons.

This project is a modern rewrite of [dwarvesf/hidden](https://github.com/dwarvesf/hidden).

## Installation

### Download the latest release

Download the pre-built app from [GitHub Releases](https://github.com/qvshuo/HiddenBar/releases/latest), unzip, and move it to your **Applications** folder.

Before launching the app, run:

```bash
xattr -cr "/Applications/Hidden Bar.app"
```

### Build from source

Open `Hidden Bar.xcodeproj` in Xcode and build.

## Usage

- **Hide menu bar items**
  1. Hold **⌘ Command** and drag the icons you want to hide to the **left** of the separator line.
  2. Click the **dot icon** to toggle their visibility.

  <p align="center">
    <img src="img/hide-items.gif">
  </p>

- **Toggle always-hidden items**

  Hold **⌥ Option** and click the dot icon to show or hide items in the always-hidden section.

  <p align="center">
    <img src="img/always-hidden.gif">
  </p>

- **Auto-hide**

  Expanded items automatically collapse after 15 seconds.

## Requirements

macOS 26.0 or later.

## License

MIT
