import SwiftUI

struct CleanupTargetsSheet: View {
    let snapshot: ScanSnapshot
    let addedTargetIDs: Set<CleanupTarget.ID>
    let addToDiscardPile: ([FileNodeRecord]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var targets: [CleanupTarget] = []
    @State private var selection = Set<CleanupTarget.ID>()
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Cleanup Suggestions")
                    .font(.title3.weight(.semibold))

                if !isLoading {
                    Text(summaryText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Text("Radix found folders that may be safe to rebuild or download again. Add selected folders to the Discard Pile for a separate review. Nothing is deleted yet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            content

            Divider()

            HStack {
                if !targets.isEmpty {
                    Button("Select High Confidence") {
                        selection = CleanupSuggestionSelection.highConfidenceIDs(
                            in: targets,
                            excluding: addedTargetIDs
                        )
                    }

                    Button("Select All") {
                        selection = CleanupSuggestionSelection.availableIDs(
                            in: targets,
                            excluding: addedTargetIDs
                        )
                    }

                    Button("Deselect All") {
                        selection = []
                    }
                }

                Spacer()

                Button("Done", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Add to Cleanup Review") {
                    addToDiscardPile(targets.filter { selection.contains($0.id) }.map(\.node))
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selection.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 920, height: 540)
        .task(id: snapshot.id) {
            isLoading = true
            let treeStore = snapshot.treeStore
            let classified = await Task.detached(priority: .userInitiated) {
                CleanupTargetClassifier.targets(in: treeStore)
            }.value
            guard !Task.isCancelled else { return }
            targets = classified
            selection = CleanupSuggestionSelection.highConfidenceIDs(
                in: classified,
                excluding: addedTargetIDs
            )
            isLoading = false
        }
        .onChange(of: addedTargetIDs) {
            selection = CleanupSuggestionSelection.reconcile(
                selection,
                targets: targets,
                excluding: addedTargetIDs
            )
        }
        .onChange(of: selection) {
            let reconciled = CleanupSuggestionSelection.reconcile(
                selection,
                targets: targets,
                excluding: addedTargetIDs
            )
            if selection != reconciled {
                selection = reconciled
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            VStack(spacing: 10) {
                ProgressView()
                Text("Finding rebuildable files…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if targets.isEmpty {
            ContentUnavailableView(
                "No Cleanup Suggestions Found",
                systemImage: "checkmark.circle",
                description: Text("This scan did not include any folders that Radix can conservatively identify as rebuildable.")
            )
        } else {
            Table(targets, selection: $selection) {
                TableColumn("Name") { target in
                    VStack(alignment: .leading, spacing: 2) {
                        Label(target.node.name, systemImage: "sparkles")
                            .lineLimit(1)
                        Text(target.node.url.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(target.node.url.path)
                        if addedTargetIDs.contains(target.id) {
                            Label("Added to Discard Pile", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .opacity(addedTargetIDs.contains(target.id) ? 0.65 : 1)
                }
                .width(min: 220, ideal: 270)

                TableColumn("Size") { target in
                    Text(RadixFormatters.size(target.node.allocatedSize))
                        .monospacedDigit()
                        .foregroundStyle(addedTargetIDs.contains(target.id) ? .secondary : .primary)
                }
                .width(min: 80, ideal: 90)

                TableColumn("Confidence") { target in
                    Text(target.kind.confidence.title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(target.kind.confidence == .high ? Color.green : Color.orange)
                        .opacity(addedTargetIDs.contains(target.id) ? 0.65 : 1)
                }
                .width(min: 115, ideal: 130)

                TableColumn("Details") { target in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(target.kind.title)
                            .fontWeight(.medium)
                        Text(target.kind.explanation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        Text(target.kind.consequence)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 3)
                    .opacity(addedTargetIDs.contains(target.id) ? 0.65 : 1)
                }
                .width(min: 320, ideal: 380)
            }
        }
    }

    private var summaryText: String {
        let selectedTargets = targets.filter { selection.contains($0.id) }
        let totalSize = selectedTargets.reduce(Int64.zero) { $0 + $1.node.allocatedSize }
        let count = selectedTargets.count.formatted()
        return String(
            localized: "\(count) selected · \(RadixFormatters.size(totalSize)) recoverable",
            comment: "Summary of selected cleanup suggestions and their total recoverable size."
        )
    }
}
