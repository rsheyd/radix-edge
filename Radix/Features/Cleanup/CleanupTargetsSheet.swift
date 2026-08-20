import SwiftUI

struct CleanupTargetsSheet: View {
    let snapshot: ScanSnapshot
    let addToDiscardPile: ([FileNodeRecord]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var targets: [CleanupTarget] = []
    @State private var selection = Set<CleanupTarget.ID>()
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Cleanup Targets")
                    .font(.title3.weight(.semibold))

                if !isLoading {
                    Text(summaryText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Text("These folders contain reproducible caches, dependencies, or build output. Review the suggestions before adding them to the Discard Pile.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            content

            Divider()

            HStack {
                if !targets.isEmpty {
                    Button(selection.count == targets.count ? "Deselect All" : "Select All") {
                        selection = selection.count == targets.count ? [] : Set(targets.map(\.id))
                    }
                }

                Spacer()

                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Add to Discard Pile") {
                    addToDiscardPile(targets.filter { selection.contains($0.id) }.map(\.node))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selection.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 860, height: 520)
        .task(id: snapshot.id) {
            isLoading = true
            let treeStore = snapshot.treeStore
            let classified = await Task.detached(priority: .userInitiated) {
                CleanupTargetClassifier.targets(in: treeStore)
            }.value
            guard !Task.isCancelled else { return }
            targets = classified
            selection = Set(classified.map(\.id))
            isLoading = false
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
                "No Cleanup Targets Found",
                systemImage: "checkmark.circle",
                description: Text("This scan did not include any folders that Radix can conservatively identify as rebuildable.")
            )
        } else {
            Table(targets, selection: $selection) {
                TableColumn("Name") { target in
                    Label(target.node.name, systemImage: "sparkles")
                        .lineLimit(1)
                }
                .width(min: 130, ideal: 170)

                TableColumn("Safety and consequences") { target in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(target.kind.title)
                                .fontWeight(.medium)
                            Text(target.kind.confidence.title)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(target.kind.confidence == .high ? Color.green : Color.orange)
                        }
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
                }
                .width(min: 280, ideal: 350)

                TableColumn("Path") { target in
                    Text(target.node.url.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(target.node.url.path)
                }
                .width(min: 220, ideal: 280)

                TableColumn("Size") { target in
                    Text(RadixFormatters.size(target.node.allocatedSize))
                        .monospacedDigit()
                }
                .width(min: 80, ideal: 90)
            }
        }
    }

    private var summaryText: String {
        let selectedTargets = targets.filter { selection.contains($0.id) }
        let totalSize = selectedTargets.reduce(Int64.zero) { $0 + $1.node.allocatedSize }
        let count = selectedTargets.count.formatted()
        return String(
            localized: "\(count) selected · \(RadixFormatters.size(totalSize)) recoverable",
            comment: "Summary of selected cleanup targets and their total recoverable size."
        )
    }
}
