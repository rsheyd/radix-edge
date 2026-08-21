# Smart Cleanup Recommendations: Product and Architecture Roadmap

Date: August 20, 2026

## Purpose

Evolve Cleanup Suggestions from a small set of conservative folder matches into a useful answer to the recurring user question:

> I am low on disk space. What are the best things I can do to recover enough space today?

This document records the product direction, safety boundary, architecture, and staged implementation approach. It builds on [GitHub issue #38](https://github.com/colinvkim/Radix/issues/38), the maintainer's preference for a curated CleanMyMac- or Mole-style knowledge base, and the first shipped Cleanup Suggestions implementation.

It does not authorize a broad rewrite or an LLM integration. Each implementation phase should be scoped, estimated, and reviewed separately.

## Current State

`CleanupTargetClassifier` currently recognizes a deliberately narrow set of rebuildable or downloadable folders:

- Rust `target` directories with a nearby Cargo manifest
- Xcode Derived Data children
- `node_modules` directories with a nearby lockfile
- Direct children of a user's `Library/Caches`
- Selected package-manager caches
- The Hugging Face model cache
- The Mole cache

Suggestions smaller than 300 MB are omitted. Known Codex runtimes are protected. Results are routed through the Discard Pile for separate review rather than deleted immediately.

This is a sound safety foundation, but it primarily answers “which known rebuildable folders can Radix identify?” It does not yet answer the broader low-space question because it lacks sufficient rule coverage, generic review candidates, goal-oriented planning, and durable user preferences.

## Capacity Reconciliation and Unattributed Space

A whole-disk scan must distinguish between space attributed to traversed files and space reported as consumed by the APFS container. These are not interchangeable measurements.

The August 20, 2026 Macintosh HD QA snapshot exposed a material example:

- APFS container capacity: 245.1 GB
- APFS available capacity at snapshot time: 8.8 GB
- Implied container usage: 236.3 GB
- Allocated size attributed by the Radix file tree: 186.0 GB
- Difference not attributed by the file tree: approximately 50.3 GB

A read-only `diskutil` investigation shortly afterward showed the same container at 237.0 GB used and 8.1 GB free, divided across these APFS volumes:

- Data: 189.5 GB
- System: 16.2 GB
- Preboot: 18.1 GB
- Recovery: 2.6 GB
- VM: 9.7 GB

At least 30.4 GB was therefore consumed by the Preboot, Recovery, and VM volumes outside the ordinary Data-volume file tree. The mounted root namespace also exposes some System-volume content, so System usage cannot be added mechanically to a root traversal without checking for overlap. APFS metadata, clones, volume sharing, inaccessible content, and snapshot-retained blocks can further prevent exact path attribution.

The System volume had three non-purgeable macOS update snapshots. One was explicitly reported as limiting the APFS container's minimum size. `diskutil` did not provide an independently additive byte size for each snapshot, so Radix must not claim that the snapshots alone account for a particular number of gigabytes. The unusually large Preboot volume and retained update snapshots nevertheless identify macOS update state as an important part of this machine's system-managed usage.

Radix already keeps APFS capacity separate from the scanned tree because container-wide usage cannot safely become a synthetic child of one mounted volume. The missing product behavior is to explain and quantify that separation clearly.

For complete volume scans, Radix should present a capacity reconciliation summary containing:

- Total capacity, available capacity, and APFS container usage
- File-tree allocated size and the time at which it was measured
- The numerical difference between container usage and file-tree attribution
- A clear **System-managed and unattributed** label for that difference
- Known APFS volume roles and their consumed capacity when available
- Snapshot count, purgeability, and update-snapshot warnings when available
- Scan warnings, inaccessible-item counts, and active exclusions that limit attribution
- An explanation that APFS volume and snapshot values may overlap the mounted namespace and are not automatically cleanup candidates

Capacity reconciliation should be evidence, not a deletion mechanism. System, Preboot, Recovery, VM, and update snapshots must not be routed to the Discard Pile. Recommended actions should use supported macOS workflows, such as completing or restarting a pending system update, reviewing macOS Storage Settings, or allowing macOS to manage VM and purgeable storage. Radix should never delete APFS snapshots or system-volume data directly.

The snapshot archive should preserve enough capacity context to diagnose discrepancies later. Consider recording a versioned, privacy-conscious APFS accounting summary at scan completion, while keeping live-only identifiers or details out of exported archives unless needed and disclosed.

### Observed recovery and product opportunity

After the investigation, the user restarted the Mac, completed the prepared macOS update, and restarted again. Available capacity increased from 8.8 GB at snapshot time to approximately 36 GB: an observed recovery of roughly 27 GB without deleting personal files or application data.

This makes system-maintenance guidance a high-priority cleanup recommendation rather than an advanced diagnostic detail. In this real case it recovered more space than nearly every individual file-level suggestion.

When Radix detects a material capacity-attribution gap together with evidence of abnormal system-managed storage, it should consider presenting a recommendation similar to:

> **Complete macOS maintenance**
>
> Radix found a large difference between scanned files and APFS-reported usage. System update and virtual-memory storage may be contributing. Finish any pending macOS update and restart before deleting personal files.

The presentation should include:

- The amount currently labeled system-managed and unattributed
- A deliberately non-numeric recovery estimate such as **Potential recovery unknown; macOS decides what can be released**
- Safe actions to open Software Update, restart, and rescan
- A statement that Radix will not delete system volumes, VM files, or update snapshots
- Appropriate uncertainty when update state cannot be confirmed through supported APIs

Radix should not recommend a restart solely because unattributed space exists. Stronger evidence may include unusually large VM or Preboot usage, update-related snapshots, staged update state, or a recent update awaiting completion. Detection must use supported macOS APIs where possible; parsing localized `diskutil` output or depending on private update-directory layouts would be fragile across supported macOS releases.

The follow-up scan is part of the feature, not merely validation. Radix should preserve the earlier capacity measurement and report the observed outcome, for example:

> **macOS maintenance recovered 27 GB**
>
> Available space increased from 8.8 GB to 36 GB since the previous scan.

This before-and-after result should distinguish changes in available capacity from files explicitly moved through Radix. It should also account for normal background fluctuation and avoid assigning all change to the recommendation when the interval included unrelated user actions.

## Product Principles

### The curated recommendation engine is the product

Radix should remain useful without network access, an account, an API key, or AI-capable hardware. Deterministic detectors should identify known cleanup opportunities and explain the evidence behind every result.

An LLM may eventually improve explanation or prioritization, but it must not become the source of truth for safety, permitted actions, or deletion.

### Do not promise absolute safety

Avoid labels such as “Safe to clean.” Even recreatable data can have meaningful consequences when the user is offline, a project is active, or an owning application expects to manage the data itself.

Prefer categories that describe evidence and required judgment:

- **Rebuildable:** expected to be recreated, with the cost of rebuilding stated
- **Redownloadable:** recoverable from a remote source, with offline consequences stated
- **Review recommended:** a plausible opportunity supported by specific evidence
- **Large item to investigate:** important to surface, but with no claim that it is disposable
- **Protected:** known sensitive data that Radix does not recommend removing

### Explain every recommendation

Each result should communicate:

- Why it appeared
- Potentially recoverable allocated space
- Confidence or review category
- What happens if it is removed
- Whether it can be rebuilt or downloaded again
- The appropriate action: delete, use the owning tool, archive, move, or inspect
- Any prerequisites, such as quitting an application or retaining network access

Evidence should be concrete. For example, “Matched `node_modules` beside `pnpm-lock.yaml`; pnpm can reinstall it” is more useful and defensible than a generic claim that a folder is safe.

### Preserve explicit user control

Discovery and destructive action must remain separate. Nothing is modified or removed without an explicit user action and the existing deletion-safety checks. A recommendation must never silently authorize deletion.

### Keep privacy local by default

Scan metadata can reveal usernames, projects, applications, and personal interests. Deterministic analysis should remain on-device. Any future external analysis must be opt-in and clearly preview the minimized structured metadata that would leave the Mac.

## Desired User Experience

The Cleanup Suggestions sheet should grow into a focused **Free Up Space** workflow without displacing Radix's visualizations and file browser as primary navigation surfaces.

The user should be able to choose a recovery goal, such as 10 GB. Radix can then assemble a plan that distinguishes:

- Rebuildable or redownloadable space
- Additional opportunities requiring review
- Large personal or unfamiliar items worth investigating

The plan should stop implying urgency once it identifies enough plausible space. It must avoid double-counting overlapping parent and child suggestions.

Users should be able to record local preferences such as:

- Do not suggest this folder again
- Suggest this again only above a chosen size
- This project is active
- I need this model available offline
- Remind me again after a chosen interval

These explicit preferences are likely to improve recurring use more reliably than inferred personalization.

## Recommendation Engine Architecture

### Versioned rule registry

Replace the monolithic classifier branching with a registry of independently testable rules. A conceptual rule includes:

```swift
CleanupRule {
    id
    ruleVersion
    supportedOSRange
    detector
    category
    evidence
    consequence
    recommendedAction
    exclusions
}
```

The exact Swift representation should follow concrete implementation needs rather than this sketch. Important properties are stable rule identity, explicit versioning, applicability, evidence, consequences, and exclusions.

Separate rules into three families:

1. **Tool and application rules:** build products, package caches, model stores, and other application-owned data.
2. **macOS rules:** version-sensitive Apple-managed locations with a higher evidentiary bar.
3. **Generic review heuristics:** large or old items that deserve attention without a deletion claim.

Rule applicability should account for supported macOS versions. macOS-managed storage locations should not be assumed equivalent from macOS 14 through later releases. Cross-version project artifacts may use broader ranges when their semantics are stable.

### Structured recommendation output

Detectors should produce recommendation records rather than only a node and kind. The record should be sufficient for both the GUI and a possible future read-only CLI:

- Stable rule and node identities
- Recommendation category
- Evidence and consequence identifiers or structured values
- Recommended action type
- Potential recoverable size
- Applicability and warning metadata
- Parent/child overlap information or enough identity to calculate it later

Presentation state such as Discard Pile membership and user dismissal should remain outside detector results.

### Prefer owning-tool cleanup

Not every recommendation should become “Add to Discard Pile.” Some targets are better handled by their owner:

- Open the application's storage settings
- Open macOS Storage Settings
- Reveal the item in Finder
- Show or copy a documented terminal command
- Archive or move the item
- Add the item to the Discard Pile

Docker data, unavailable simulators, package-manager state, and other application-managed storage may have invariants that raw deletion bypasses. Initially, Radix should explain or copy third-party cleanup commands rather than execute them.

## Initial Coverage Priorities

Choose rules from observed real scans and prioritize expected recoverable space, confidence, and maintenance cost. Strong early candidates include:

- Xcode archives, simulator/device support, unavailable simulators, and oversized Derived Data
- Homebrew caches and old downloads
- npm, pnpm, Yarn, Cargo, Gradle, Maven, pip, uv, CocoaPods, and SwiftPM artifacts
- Docker and Podman storage, with owning-tool cleanup guidance
- Old disk images, installer packages, and archives in Downloads
- iPhone and iPad backups
- Large application logs and diagnostic reports
- Local AI model and runtime stores, with offline and redownload consequences
- Trash and well-understood abandoned application leftovers
- Large files in Downloads
- Large unexplained folders as investigation-only results

Use context-sensitive thresholds rather than applying the current 300 MB minimum universally. A moderately sized installer in Downloads may be actionable while the same threshold across every application cache may create noise.

Mail, Messages, cloud storage, virtual machines, models, and application support data should generally begin as review-only or owning-tool recommendations unless a narrow rule has strong evidence.

## Duplicate Detection Boundary

Duplicate detection is related but should remain a separate feature and issue. Reliable implementation requires content hashing, cancellation and progress, hard-link and APFS-clone handling, false-positive-safe grouping, and a dedicated review experience.

The recommendation model may reserve space for future duplicate groups, but duplicate scanning should not be bundled into the next Cleanup Suggestions expansion.

## LLM Boundary

Do not make LLM integration a planned dependency of the core roadmap. First measure the residual problems left after deterministic rules, generic heuristics, explanations, and user preferences are working.

If a later prototype is justified, appropriate uses include:

- Explaining an unfamiliar folder in plain language
- Grouping structured recommendations into a comprehensible plan
- Answering “why is this here?” or “what might break?”
- Suggesting investigation steps for otherwise unclassified large items

The required boundary is:

```text
Filesystem scan
    -> deterministic detectors and safety policy
    -> structured recommendations with evidence
    -> optional LLM explanation or ranking
    -> Radix review UI
    -> explicit user-controlled action
```

An LLM must never assign authoritative safety, override a protected rule, permit deletion, or inspect arbitrary file contents by default. Any integration should be optional, clearly labeled advisory, given minimized structured input, and gracefully unavailable on unsupported systems. Anti-AI users should receive the complete deterministic product with no model initialization or unexplained data flow.

Apple on-device models may avoid API cost, but they do not remove the need for a curated knowledge base or solve OS and hardware availability. Do not raise Radix's deployment or hardware requirements for the core cleanup experience.

## Staged Roadmap

### Stage 1: Generalize the current classifier

- Introduce an extensible, version-aware registry.
- Preserve the existing seven rules, thresholds, ordering, protection, UI behavior, and tests.
- Keep the first architectural change bounded and independently reviewable.

### Stage 2: Expand curated coverage

- Add small rule-family changes prioritized from real scans.
- Include evidence, consequences, exclusions, and recommended actions with every rule.
- Use owning-tool workflows where raw deletion is inappropriate.
- Add all user-facing text to every supported locale.

### Stage 3: Add generic review heuristics

- Surface old large files, installers, archives, applications, and unexplained large folders.
- Avoid describing heuristic results as removable.
- Add context-sensitive thresholds and noise controls.

The scanner currently records modification dates but may require carefully bounded metadata changes for richer age-based results. Measure scan-time, memory, archive-format, and privacy effects before collecting more metadata.

### Stage 4: Build goal-oriented cleanup plans

- Let the user choose or adjust a recovery target.
- Rank recommendations by recoverable space, confidence, consequence, and user preferences.
- Put supported system-maintenance recommendations ahead of file deletion when evidence suggests they may resolve immediate pressure.
- Prevent overlapping recommendations from inflating totals.
- Distinguish delete, owning-tool cleanup, archive, move, and investigate actions.

### Stage 5: Add local feedback and personalization

- Support dismissal, thresholds, active-project exclusions, offline requirements, and revisit dates.
- Keep preferences local and understandable.
- Define invalidation when paths, scan identities, or rule versions change.

### Stage 6: Evaluate against real scans

- Record which recommendations were useful, misleading, or missing.
- Measure total identified space by category and the user's eventual action.
- Reconcile file-tree allocation against APFS container usage and record material unattributed differences.
- Verify that volume-role and snapshot explanations do not double-count capacity or imply unsafe deletion.
- Use private fixtures for performance and integration testing without committing filesystem metadata.
- Maintain focused synthetic tests for rule correctness and safety boundaries.

### Stage 7: Reconsider optional AI

- Identify a specific unmet user problem rather than adding AI generically.
- Prototype only if expected value exceeds compatibility, privacy, testing, and maintenance costs.
- Keep the deterministic engine and safety policy authoritative.

## Recommended Next Contribution

The next maintainer-friendly change should be:

> Replace `CleanupTargetClassifier`'s monolithic classification branching with an extensible, version-aware rule registry while preserving current behavior.

Follow it with small PRs for individual rule families. This matches the maintainer's requested curated direction, makes safety review manageable, and avoids committing the project to a speculative large feature or AI framework.

Before implementation, confirm the intended registry shape with the maintainer on issue #38. Update the issue to note that Cleanup Suggestions now supplies the conservative core of the original proposal and that the registry is an evolution of that feature rather than a competing feature.

## Open Product Decisions

- Should the user-facing feature remain named Cleanup Suggestions or become Free Up Space while preserving the existing sheet during transition?
- Which first rule family produces the most value on representative scans?
- Which recommendations may enter the Discard Pile, and which must use an owning-tool or investigation action?
- How should Radix source and review claims about third-party cleanup behavior?
- What macOS-specific evidence is required before enabling a system rule on a new OS version?
- Where should dismissal and threshold preferences be stored, and how should they follow renamed paths?
- Should recoverable-space goals be presets, free-form values, or inferred from current free space with user confirmation?
- What evidence would justify an LLM prototype after the deterministic stages?
- Which APFS accounting details can Radix obtain through supported APIs without requiring elevated privileges or exposing unstable implementation details?
- How should archived capacity summaries represent values that overlap or are not independently additive?
- What evidence is strong enough to recommend completing an update or restarting without creating repetitive or generic advice?
- How should Radix attribute before-and-after free-space changes when other activity occurred between scans?

## Non-Goals for the Near Term

- Automatic deletion
- Executing arbitrary third-party cleanup commands
- Treating LLM output as a safety decision
- Sending scan metadata externally by default
- Raising the core app's deployment target for AI
- Bundling duplicate detection into the registry refactor
- Building an exhaustive macOS cleanup database in one change
