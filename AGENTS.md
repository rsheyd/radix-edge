# AGENTS.md

## Project

Radix is a native macOS 14+ disk-space analyzer built with Swift 6.2,
SwiftUI, and Xcode 26+.

Preserve these product guarantees:

- Scanning remains responsive and does not block the UI.
- Files are never modified or removed without an explicit user action.
- Visualizations and the file browser remain primary navigation surfaces.

Prefer SwiftUI for UI. Use AppKit only when required for macOS system integration.

## Architecture and task routing

- Scanner or data behavior: `Radix/Services/`, `Radix/Models/`
- Tree and indexing: `Radix/Models/FileTreeStore.swift`
- App coordination, navigation, or selection: `Radix/ViewModels/AppModel.swift`
- Search and sorting: `Radix/Services/FileBrowserModel.swift`
- Sunburst or treemap layout: the corresponding geometry/chart model in
  `Radix/Services/`
- Feature UI: `Radix/Features/`
- Tests: `RadixCoreTests/`

`Package.swift` defines the non-UI `RadixCore` target. When adding or moving a
non-UI Swift file, update its explicit source list. The Xcode project builds
the complete app.

## File map

- Cleanup Suggestions implementation plan: `docs/cleanup-suggestions-implementation-plan.md`
- Debug QA scan-fixture guide: `local-only/debug-qa-scan-fixture.md`
- RadixCore/GUI/CLI discussion memo: `docs/radix-core-gui-cli-proposal.md`

## Change guidelines

- Follow the existing architecture when it remains a good fit; change ownership
  or boundaries when that produces a clearer implementation.
- Add focused tests when behavior changes, especially for scanner, tree, path,
  archive, comparison, geometry, search, and formatting behavior.
- Add new user-facing text to the appropriate `.xcstrings` catalog for every
  supported locale: `en`, `de`, `es`, `fr`, `it`, and `zh-Hans`.
- Avoid new dependencies unless clearly justified. `RadixCore` has none.
- Sparkle is managed through Xcode Swift Package Manager; never vendor it.
- Use current documentation for version-sensitive Apple or external APIs.

## Validation

Validate in proportion to the change. For code that affects core behavior, run:

    swift test

For app integration or UI changes, build the complete app into a deterministic
DerivedData location:

    xcodebuild -project Radix.xcodeproj -scheme Radix \
      -configuration Debug -destination 'platform=macOS' \
      -derivedDataPath .build/xcode-derived-data build

For routine manual testing with Computer Use:

- Stop any other running Radix instances, then launch this checkout's exact
  Debug bundle:

      open -n .build/xcode-derived-data/Build/Products/Debug/Radix.app

- Use the full absolute path to that bundle for every Computer Use `app`
  argument. Require exactly one running Radix instance before testing; the
  `open -n` command deliberately starts a new instance.
- Never target the app as `Radix` or `com.colinkim.Radix`. Installed, archived,
  release, and DerivedData builds share that identity, so generic lookup can
  launch the wrong copy, including `/Applications/Radix.app`.
- For repeatable Cleanup Suggestions QA, follow
  `local-only/debug-qa-scan-fixture.md`. The Debug-only arguments are:

      --qa-scan /absolute/path/to/fixture.radixscan
      --qa-open-cleanup-suggestions

  Scan archives can contain private filesystem metadata and must remain
  untracked. These arguments are unavailable in Release builds.

When the test specifically requires LLDB, scheme launch arguments, sanitizers,
or other Xcode diagnostics, start the shared scheme from the command line
instead of clicking Xcode's Run button with Computer Use:

    xed -b Radix.xcodeproj
    xcrun xcdebug -s Radix -B -b

`xcdebug -B` performs the scheme's Build and Run action and attaches Xcode's
debugger; the `-b` options leave Xcode in the background.

Use small, focused Conventional Commits and Conventional Commit PR titles.

## Design guidance

- Prefer coherent implementations that preserve correctness, clarity, and
  performance; introduce or extend abstractions based on which better fits the
  concrete change.
- Keep state and persistence scoped to real consumers, while allowing broader
  ownership when coordination requires it.
- For performance-sensitive work, investigate repeated traversal, allocation,
  I/O, and main-actor work, and measure when practical.
