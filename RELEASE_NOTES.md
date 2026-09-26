# Release Notes

Notes for the next release cut from *this* branch. Every `release/v*` branch (and
`main`) carries its own copy of this file, scoped to whatever ships next from that
branch — see [RELEASING.md](RELEASING.md) for the full process.

When a release is tagged, this file's content at that commit becomes the GitHub
Release body. Reset it to a fresh "Unreleased" section right after tagging.

## Unreleased

### Fixed

- **Scanning a volume no longer counts its contents two and three times.** A scan of
  `/` reported 1.3 TB on a 926 GiB volume: everything in the home folder was counted
  once under `/Users` and again under `/System/Volumes/Data`, with a third helping via
  `/.nofollow`. Totals now agree with `du` to the kilobyte, and the scan is about
  2.4× faster for not walking the disk repeatedly.
- Skipped folders are no longer all blamed on Full Disk Access. Folders macOS protects
  (which the grant opens) are now told apart from ones ordinary permissions deny
  (which it doesn't) — on a typical boot volume about a quarter fall in the latter group.

### Added

- **Clusters view** — ranks the folders actually holding the space, rather than making
  you drill for them. A folder only counts as a cluster when its weight is spread
  across its contents, so you get the one subfolder that's 50 GB, not the ancestor
  chain above it.
- **Home Folder** as a first-class scan target on the start screen, since a whole-volume
  scan buries your own files under system folders you can't reclaim.
- **Kind grouping in the legend** — rolls extensions up into categories, so a single
  kind spread across several extensions (disc and VM images across `.iso`, `.vmdk`,
  `.img`, `.wbfs`, `.qcow2`) shows up as one line instead of five scattered ones.
- Clicking a treemap tile now reveals it in the file list, opening the path down to it
  and scrolling it into view.
- The skipped-folders banner lists the folders it's talking about, with a reason for
  each, instead of only a count.
- Copăcel now checks for Full Disk Access before a scan rather than leaving you to find
  out from a banner once the results are already short.
- Folders that couldn't be read are marked in the file list, so an unreadable folder
  isn't mistaken for an empty one.

### Changed

- The treemap no longer recomputes its whole layout on every mouse movement, which made
  hovering and clicking crawl on large scans — roughly 18 fps on a home folder and
  3 fps on a full volume before, now unaffected by pointer movement.
- Sorting and per-extension totals are computed off the main thread, so sort-header
  clicks and drilling into folders no longer block the interface on large trees.
