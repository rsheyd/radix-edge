# Cleanup Suggestions Implementation Plan

Date: August 20, 2026

## Purpose

Finish the conservative Cleanup Suggestions feature as a coherent user-facing release, verify that Radix correctly reuses completed scans during sidebar navigation, and separately design bounded persistence for completed scans.

The phases are intentionally separated. Cleanup Suggestions is useful without persistent scan storage, while automatic persistence introduces independent privacy, freshness, storage-policy, and destructive-action concerns.

## Codex usage estimates

These estimates are percentage points of the Codex usage limit expected for each phase if implemented in a separate focused task. They are based on likely model/tool feedback cycles, including inspection, implementation, automated validation, manual QA, and probable repairs. Re-estimate before beginning each phase if the working tree or scope has changed.

| Phase | Estimated usage | Main uncertainty |
| --- | ---: | --- |
| Phase 1: Finish Cleanup Suggestions UX — **Complete** | 8–12% | SwiftUI iteration, six-locale string updates, and manual UI repair cycles |
| Phase 2: Verify scan reuse and add measured derived-result caching | 6–10% | Reproducing the reported Macintosh HD behavior and determining whether a cache change is actually needed |
| Phase 3: Persistent completed-scan caching | 12–18% | Retention policy, archive integration, restoration behavior, privacy controls, failure recovery, and end-to-end testing |

Phase 3 should begin with a narrower design and measurement pass, estimated at 3–5%, before committing to the full implementation. If that pass exposes archive-format changes, removable-volume identity work, or extensive settings UI, the implementation estimate should be revised upward.

## Phase 1: Finish the Cleanup Suggestions UX — Complete

Completed and pushed to the development fork's `main` branch on August 20, 2026 in commit `c2a7d33`. The delivered scope includes the refined selection and review workflow, six-locale UI updates, the 300 MB minimum, startup-disk access preflight, and Debug QA archive launcher.

Goal: make the current feature understandable and predictable for a first-time user, then ship it independently of broader caching work.

### Terminology and explanation

- Rename “Cleanup Targets” to “Cleanup Suggestions” throughout the UI, localization catalog, README, changelog, and relevant tests.
- Explain that suggestions are rebuildable or downloadable folders that still have consequences when removed.
- Explicitly state that adding folders to the Discard Pile does not delete anything and that deletion requires a separate review and confirmation.
- Prefer “Add to Cleanup Review” for the primary action. Introduce “Discard Pile” in the supporting explanation so the button describes the immediate user intent without hiding the existing product concept.

Suggested explanatory copy:

> Radix found folders that may be safe to rebuild or download again. Add selected folders to the Discard Pile for a separate review. Nothing is deleted yet.

### Selection and added-state behavior

- Keep the sheet open after adding selected suggestions.
- Pass the current `discardPileHiddenNodeIDs` into the sheet rather than creating another source of truth.
- Keep already-added rows visible, disable them, exclude them from selection commands, and label them as added to the Discard Pile.
- Initially select high-confidence suggestions only.
- Initially leave review-recommended and already-added suggestions unselected.
- Provide explicit **Select High Confidence**, **Select All**, and **Deselect All** commands. Selection commands must skip disabled rows.
- Ensure the selected count and recoverable-space total update after selection changes and after additions to the Discard Pile.
- Account for the existing cloud-storage confirmation path: do not show a row as successfully added until the authoritative Discard Pile state changes.

### Table layout

- Prioritize Name, Size, and Confidence at the default sheet width.
- Move Size directly after Name.
- Prefer a combined Name/Path column with the middle-truncated path as secondary text.
- Keep explanation and consequence together in a Details column.
- Increase the default width only if the prioritized layout still cannot remain readable.

### Testing and validation

- Extract only the minimum testable selection state needed; avoid a new general state layer.
- Cover initial high-confidence selection, review-recommended exclusion, already-added rows, each selection command, and recoverable-size totals.
- Run `swift test`, the deterministic Xcode Debug build, localization validation, and `git diff --check`.
- Manually verify the exact Debug bundle: open suggestions, change selections, add folders, confirm the sheet remains open, confirm row state changes, and verify the Discard Pile without deleting anything.
- Update `local-only/cleanup-suggestions-manual-qa-2026-08-20.md` with the observed result.

### Phase boundary

Do not add cleanup-classification caching merely because reopening currently repeats a traversal. First ship the interaction fixes unless measurement shows that classification is meaningfully slow on a large completed scan.

## Phase 2: Verify scan reuse and add measured derived-result caching

### Phase 1 follow-up: startup-disk access preflight

Implemented after Phase 1 manual feedback:

- Before scanning the startup disk without verified Full Disk Access, show one Radix preflight instead of allowing traversal to trigger successive macOS folder-access prompts.
- Reuse existing Full Disk Access, settings, and cancellation UI text.
- Offer **Scan with Limited Access**, which skips every user’s protected Desktop, Documents, and Downloads folders.
- Include the limited exclusions in scan options and sidebar cache keys so completed limited scans can be restored normally.
- Start complete startup-disk scans without a preflight when Full Disk Access is verified.

Goal: distinguish an actual sidebar-cache defect from expected restoration or scoping behavior, and optimize cleanup classification only where measurement supports it.

### Cleanup classification cache

- Measure archive import and cleanup classification separately against the private Macintosh HD QA fixture so the two costs are not conflated.
- If classification is materially slow, persist its small derived result across app relaunches and Debug rebuilds; an in-memory-only cache would not improve the primary QA loop.
- Key the result by a stable snapshot content identity, an explicit cleanup-rule version, and all output-affecting policy such as the 300 MB minimum.
- Store only the classified target identifiers and kinds, not another copy of the file tree.
- Keep Discard Pile membership out of cached classification results; layer it on as presentation state.
- Invalidate when snapshot contents, classifier rules, thresholds, or archive compatibility change.
- Do not build a general multi-scan cleanup cache without evidence that it is needed.
- Do not add a synthetic Debug-only cleanup snapshot yet. Reconsider it only if archive import remains a significant bottleneck after classification caching, or if UI work needs deterministic edge cases that the real fixture cannot provide.

### Cache testing

- Record cold import time, cold classification time, warm classification time in the same launch, and warm classification time after relaunch/rebuild.
- Verify that cached targets resolve to the imported tree before presentation and that missing identifiers are ignored safely.
- Cover invalidation for changed snapshot content, cleanup-rule version, and minimum-size policy.
- Continue using the real private Macintosh HD fixture for periodic integration and performance checks; use focused unit fixtures for classifier correctness.

### Macintosh HD/sidebar investigation

- Scan Macintosh HD to completion, select Home, return to Macintosh HD, and record whether Radix restores, scopes, or starts a filesystem scan.
- Repeat for an ordinary folder, after a scan-option change, and after enough scans to exercise the cache budget.
- Trace `ScanCacheKey`, active/displayed cache-key state, and completed-snapshot retention for any unexpected rescan.
- Preserve the existing behavior in which unchanged target/options pairs restore exact snapshots and child locations can be scoped from a cached parent.
- If unchanged Macintosh HD → Home → Macintosh HD navigation rescans, treat it as a bug in cache keying, retention, or restoration rather than introducing another cache.
- Add focused regression tests for any defect found.

### Freshness communication

- Verify whether the existing “Last Updated” presentation clearly communicates that a restored result is not live.
- Prefer clearer wording or a restored-state indicator before adding new timestamp state.
- Keep an explicit Rescan action available.

### Validation

- Run focused sidebar-cache and scan-coordinator tests, then the full core suite and deterministic app build.
- Compare cold and warm Cleanup Suggestions timings against the same private QA archive and record the result.
- Repeat the navigation matrix against the exact Debug bundle and distinguish restoration/scoping progress from real filesystem scanning.

## Phase 3: Persistent completed-scan caching

Goal: restore recent completed scans after app relaunch while keeping storage bounded and stale data clearly identified.

### Design pass before implementation

- Confirm the product policy for retention, privacy explanation, target identity, imported archives, backup exclusion, settings, and cache clearing.
- Measure representative `.radixscan` archive sizes and import/export latency.
- Decide how much of `ScanArchiveService` can be reused without exposing automatic cache management as user-authored archive behavior.
- Define eligibility and invalidation for scan options, exclusion settings, archive compatibility, and target identity.

### Recommended bootstrap

- Keep only the latest eligible scan for each target/options key.
- Bound the cache by both total bytes and entry count; start with the two or three most recently used local targets.
- Store entries in the application caches directory with normal macOS file protection and exclude them from backups where appropriate.
- Exclude imported `.radixscan` snapshots initially.
- Persist capture time and display explicit stale-result language.
- Keep automatic scan caches distinct from cached or regenerated Cleanup Suggestions.
- Provide a Clear Cached Scans control and decide whether automatic persistence needs an opt-out.
- Evict incompatible, corrupt, obsolete, missing-target, or over-budget entries safely.
- Never let restoration silently authorize destructive actions. Revalidate live path identity and existing deletion safety rules before file mutation.

### Validation

- Test normal relaunch restoration, corrupt and incompatible entries, option mismatches, missing or renamed targets, removable volumes, budget eviction, cache clearing, and interrupted writes.
- Verify that cache writes remain off the main actor and do not degrade scan responsiveness.
- Run archive, scan, cache, localization, and full core tests plus deterministic Debug and Release builds.
- Manually verify restoration, freshness messaging, explicit rescan, settings, and safe destructive-action gating.

## Work that should remain separate

- Keep `docs/radix-core-gui-cli-proposal.md` out of Cleanup Suggestions commits. It is a separate architectural discussion.
- Treat progressive disclosure for the inspector, Discard Pile, toolbar, and warnings as a separate workspace-design effort after Cleanup Suggestions ships.
- Confirm version `1.8.0`, build `13`, and permanent adoption of `CHANGELOG.md` before preparing the release commit. Once decided, document the project-specific versioning and changelog rule in `AGENTS.md`.
- Do not commit `local-only/`, Google Docs sync metadata, reference screenshots, or `.DS_Store`.

## Recommended sequence

1. Implement, test, manually verify, and commit Phase 1 as one coherent feature.
2. Run the Phase 2 measurement and reproduction matrix; implement only defects or optimizations supported by the results.
3. Conduct the Phase 3 design pass and revise its implementation estimate before writing the persistence layer.
