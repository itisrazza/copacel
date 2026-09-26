<div align="center"><img src="Copacel/AppIcon.icon/Assets/retrovault.svg" alt="" width="64" height="64"></div>
<h1 align="center">Copăcel</h1>
<div align="center">
  <img alt="CI" src="https://github.com/itisrazza/copacel/actions/workflows/ci.yml/badge.svg">
  <img alt="Licence: MIT" src="https://img.shields.io/badge/licence-MIT-blue.svg">
</div>

A macOS disk usage visualiser. Pick a folder or a volume and Copăcel scans it
concurrently, then shows what's taking up the space as a squarified treemap.

## Features

- **Treemap** — a squarified, recursive treemap of the scanned folder, coloured by
  file extension.
- **File list** — a sortable, hierarchical view of the same tree, with breadcrumb
  navigation as you drill into subfolders.
- **Extension legend** — deterministic per-extension colours; click one to highlight
  every file of that type across both the list and the treemap.
- **Volume selector** — the start screen lists mounted volumes (boot volume first,
  then internal, then removable) with used space and a usage bar, and updates live
  as drives are plugged in or ejected.
- **Reveal in Finder / Copy Path / Move to Trash** from a file's context menu.
- **Full Disk Access aware** — warns before a scan if the grant is missing, and afterwards
  lists exactly which folders were skipped. Distinguishes folders macOS protects (which the
  grant fixes) from ones ordinary permissions deny (which it doesn't), and marks each in the
  file list so an unreadable folder isn't mistaken for an empty one.
- **Accurate per-volume totals** — the scanner won't cross into another mounted
  volume (including a firmlinked Data volume like `/System/Volumes/Data`), so
  scanning a volume never double-counts content reachable by more than one path.

## Building

Requires macOS 15+, Xcode, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
xcodegen generate
open Copacel.xcodeproj
```

## Testing

The scanning, layout, and volume-listing logic lives in the `CopacelCore` Swift
package, independent of the UI, and is unit tested there:

```bash
swift test --package-path CopacelCore
```

## Architecture

- **`Copacel`** — the SwiftUI app. `ScanViewModel` drives all UI state; views are
  largely presentational, taking state and closures rather than owning logic.
- **`CopacelCore`** — a local Swift package with no SwiftUI/AppKit dependency,
  holding the directory scanner, treemap layout, extension stats, sorting, and
  volume enumeration — everything that can be tested without a UI.

## Releasing

See [RELEASING.md](RELEASING.md) for the branching model and the full release
process, from cutting a release branch through local signing to publishing on
GitHub.

## Licence

[MIT](LICENSE)
