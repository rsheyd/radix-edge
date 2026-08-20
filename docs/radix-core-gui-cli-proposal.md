# Discussion: RadixCore, Radix GUI, and a Possible CLI

## Purpose

This document is a conversation starter for the maintainer. It is not a proposal to begin a large restructuring immediately.

Radix is currently a native macOS application backed by a SwiftPM library target named `RadixCore`. Recent work on conservative cleanup suggestions highlighted that much of Radix's useful behavior could also support a terminal workflow: scan a path, identify large or rebuildable content, and return human-readable or structured results without opening the GUI.

The question is whether it would be useful to make the architectural boundaries more explicit:

```text
RadixCore
├── Radix GUI
└── radix-cli
```

This could remain one repository and one release project. “Splitting out” does not necessarily mean separate repositories, packages, or maintainers.

## Current Context

Radix already has several foundations that make this idea plausible:

- `Package.swift` defines a dependency-free `RadixCore` library.
- The scanner, scan snapshots, file tree, comparisons, archives, formatting, and safety models are mostly separate from SwiftUI views.
- `swift test` validates the core independently of the Xcode application build.
- The cleanup-target classifier can inspect a completed scan without performing deletion.
- The GUI already separates discovery from destructive action by routing selected items through the Discard Pile.

The current package boundary is broader than a portable engine boundary, however. It explicitly includes application coordination and view models such as `AppModel`, along with macOS-specific system integration. Before adding another interface, it would be worth deciding what “core” is intended to mean.

## Possible Responsibilities

### RadixCore

RadixCore could own behavior that should be consistent across interfaces:

- File-system scanning and progress events
- Scan targets, snapshots, warnings, and tree storage
- Incremental rescans
- Cleanup-target classification and safety metadata
- Scan comparison and archive formats
- Size formatting or neutral output values
- No deletion without an explicit request from a caller

Ideally, RadixCore would not know about SwiftUI, toolbar state, sheets, or terminal formatting.

### Radix GUI

The existing macOS app would continue to own:

- SwiftUI views and visualizations
- Window, selection, navigation, and presentation state
- Discard Pile interaction
- Quick Look, Finder, and application-opening actions
- Settings, onboarding, localization, and Sparkle updates
- macOS permission guidance

The product could continue to be called Radix. “Radix GUI” is useful as an architectural label but probably does not need to become its public name.

### radix-cli

A first CLI could be deliberately small, English-only, and read-only:

```bash
radix scan PATH
radix scan PATH --json
radix cleanup-targets PATH
radix cleanup-targets PATH --json
```

Its responsibilities could include:

- Argument validation
- Terminal progress and cancellation
- Human-readable tables
- Stable JSON output
- Meaningful exit codes
- Reporting permission limitations and scan warnings

Deletion, interactive selection, shell completion, and additional localization could wait until real usage shows they are worthwhile.

## Potential Benefits

### One source of truth

The GUI and CLI could share scan semantics, cleanup rules, warnings, and archive compatibility. This avoids maintaining two scanners that gradually disagree about disk usage or safety.

### Automation

JSON output would let scripts, scheduled jobs, and other tools use Radix's scanner without scraping a GUI. A read-only CLI could also fit naturally into diagnostics and support workflows.

### Easier testing and debugging

A terminal entry point could make it quicker to reproduce scanner behavior against a particular directory, capture output, compare runs, and test performance without launching the application.

### Broader usefulness without duplicating the product

The GUI remains the best interface for visual exploration and careful cleanup. The CLI serves users who already know the path or question they want to investigate. It does not need terminal versions of the sunburst, treemap, inspector, or every app feature.

### Clearer architectural boundaries

Making interface-neutral behavior genuinely reusable could reduce coupling between scan logic and application coordination. Even if a CLI never becomes a major product, the boundary work could make the existing app easier to maintain.

## Costs and Risks

- A second interface creates documentation, testing, compatibility, and release work.
- Stable JSON becomes an API that needs versioning discipline.
- Moving existing types across target boundaries could produce a large refactor with little immediate user value.
- Some scanner behavior is inherently macOS-specific, so “core” should not automatically imply cross-platform support.
- A CLI that can delete files would require careful confirmation, identity verification, race handling, and safety guarantees comparable to the GUI.
- Supporting several languages in terminal output may add complexity without much early benefit.
- Naming and installation need thought: whether the executable is `radix`, `radix-cli`, bundled with the app, or installed separately.

## Suggested Low-Risk Path

1. Agree on the intended boundary of RadixCore before moving files.
2. Add a small internal executable target in the existing repository.
3. Implement only `scan` and `cleanup-targets`, with text and JSON output.
4. Keep the CLI English-only and strictly read-only at first.
5. Use it on real tasks and measure whether it improves diagnostics or automation.
6. Add interactive or destructive operations only if repeated use demonstrates a clear need.
7. Consider separate packaging or repositories only if release cadence, platform support, or ownership actually diverges.

This treats the CLI as an experiment built on the existing product, rather than committing Radix to maintaining two full applications.

## Questions for the Maintainer

- Was `RadixCore` intended to become a reusable engine, or mainly to make the application testable with SwiftPM?
- Which current services and models feel appropriately “core,” and which belong to the macOS app layer?
- Would a read-only CLI help with Radix development, support, benchmarking, or user workflows?
- Is stable JSON output something the project would be willing to maintain?
- Should the CLI share the app's macOS 14 minimum, or would an older deployment target be valuable?
- Would adding an executable target complicate signing, distribution, or Sparkle packaging?
- Is English-only acceptable for an initial developer-oriented CLI?
- What evidence or prototype would make the architectural refactor worth doing?

## Proposed Decision

The immediate decision does not need to be “build a CLI.” A smaller decision would be:

> Do we want RadixCore to become a clearly supported, interface-neutral boundary that could power both the existing app and a future read-only CLI?

If the answer is no, the current structure may already be the right tradeoff. If the answer is yes, a narrow CLI prototype would be a practical way to test the boundary before undertaking a broader reorganization.
