# Changelog

All notable changes to Radix will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and Radix uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.8.0] - 2026-08-20

### Added

- Added Cleanup Suggestions, a conservative scan-results workflow for finding regenerable build artifacts, dependencies, and caches.
- Added category-level confidence and consequence guidance so users can distinguish high-confidence build output from caches that merit review.
- Added explicit detection for Rust build artifacts, Xcode Derived Data, lockfile-backed Node dependencies, selected package-manager caches, application caches, Hugging Face model caches, and Mole caches.
- Added selection-based recoverable-space estimates and integration with the existing Discard Pile review flow.
- Added protected cleanup paths, initially preventing Codex runtime caches from being suggested.
- Limited Cleanup Suggestions to targets with at least 300 MB of recoverable space.
- Added a Full Disk Access preflight before startup-disk scans. Limited scans deliberately skip protected Desktop, Documents, and Downloads folders to avoid repeated macOS permission prompts.

### Safety

- Cleanup suggestions never remove files directly and continue to require explicit user review through the Discard Pile.
- Inaccessible, synthetic, auto-summarized, and symbolic-link nodes are excluded from cleanup suggestions.

Earlier release history is available on the [GitHub Releases page](https://github.com/colinvkim/Radix/releases).

[1.8.0]: https://github.com/colinvkim/Radix/compare/v1.7.0...v1.8.0
