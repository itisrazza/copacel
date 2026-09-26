<div align="center"><img src="Copacel/AppIcon.icon/Assets/retrovault.svg" alt="" width="64" height="64"></div>
<h1 align="center">Copăcel</h1>
<div align="center">
  <img alt="CI" src="https://github.com/itisrazza/copacel/actions/workflows/ci.yml/badge.svg">
  <img alt="Platform: macOS 15+" src="https://img.shields.io/badge/platform-macOS%2015%2B-lightgrey.svg">
  <img alt="Licence: MIT" src="https://img.shields.io/badge/licence-MIT-blue.svg">
</div>

A macOS disk usage visualiser. Point it at your home folder, another folder, or a whole
volume, and Copăcel scans it concurrently, then shows where the space went — as a
squarified treemap, a sortable file list, and a ranking of the folders actually holding
the bulk of it.

![Copăcel scanning a home folder. A sortable file list fills the upper left, a legend
grouping files by kind sits to its right, and a squarified treemap coloured by file
extension fills the lower half of the window.](screenshot.png)

## Features

- **Treemap** — a squarified, recursive treemap of the scanned folder, coloured by file
  extension. Click a tile to select it, double-click to drill in.
- **File list** — a sortable, hierarchical view of the same tree, with breadcrumb
  navigation as you drill into subfolders. Clicking a treemap tile opens the list down to
  that file and scrolls it into view.
- **Clusters** — a ranking of the folders actually holding the space. A folder only counts
  as a cluster when its weight is spread across its contents, so you get the one subfolder
  that's 50 GB rather than every ancestor above it.
- **Legend, by kind or by extension** — group files into categories (disc and VM images,
  binaries and build output, archives, media, code) or break them out per extension.
  Clicking an entry highlights every matching tile in the treemap. Per-extension colours
  are deterministic, so the same extension looks the same across runs.
- **Start screen** — your home folder first, then mounted volumes (boot volume, then
  internal, then removable) with used space and a usage bar, updating live as drives are
  plugged in or ejected.
- **Reveal in Finder / Copy Path / Move to Trash** from a file's context menu.
- **Full Disk Access aware** — warns before a scan if the grant is missing, and afterwards
  lists exactly which folders were skipped. Distinguishes folders macOS protects (which the
  grant opens) from ones ordinary permissions deny (which it doesn't), and marks each in
  the file list so an unreadable folder isn't mistaken for an empty one.
- **Accurate totals** — the scanner won't cross into another mounted volume, including a
  firmlinked Data volume like `/System/Volumes/Data`, so scanning a volume never
  double-counts content reachable by more than one path. Per-directory totals agree with
  `du -skl`.

Scans of several million files are expected and handled; the treemap and the list stay
responsive while you explore one.

## Building

Requires macOS 15+, Xcode, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
xcodegen generate
open Copacel.xcodeproj
```

## Testing

The scanning, layout, clustering, categorisation, and volume-listing logic lives in the
`CopacelCore` Swift package, independent of the UI, and is unit tested there:

```bash
swift test --package-path CopacelCore
```

Some behaviour can't be reached from a unit test — whether the scanner treats a real mount
as a boundary needs a real mount. [`VerifyMountBoundary`](CopacelCore/Sources/VerifyMountBoundary)
is a manual check that sets one up with a disk image and tears it down again:

```bash
swift run --package-path CopacelCore VerifyMountBoundary
```

## Architecture

- **`Copacel`** — the SwiftUI app. `ScanViewModel` drives all UI state; views are largely
  presentational, taking state and closures rather than owning logic. Derived state —
  sorting, extension totals, clusters — is computed off the main actor so it doesn't stall
  the interface on a large tree.
- **`CopacelCore`** — a local Swift package with no SwiftUI/AppKit dependency, holding the
  directory scanner, treemap layout, clustering, extension and category stats, sorting, and
  volume enumeration — everything that can be tested without a UI.

## Releasing

See [RELEASING.md](RELEASING.md) for the branching model and the full release process, from
cutting a release branch through local signing to publishing on GitHub.

## How this was made

Copăcel is written almost entirely by an LLM, using [Claude
Code](https://claude.com/claude-code). I don't write Swift. I decide what the app should
do and how it should behave, review what comes back, and try it against my own files; the
model does the code generation.

## Licence

[MIT](LICENSE)
