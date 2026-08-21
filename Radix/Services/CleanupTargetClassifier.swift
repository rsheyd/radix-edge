import Foundation

nonisolated enum CleanupTargetConfidence: String, Sendable {
    case high
    case reviewRecommended

    var title: String {
        switch self {
        case .high:
            String(localized: "High confidence")
        case .reviewRecommended:
            String(localized: "Review recommended")
        }
    }
}

nonisolated enum CleanupTargetKind: String, CaseIterable, Sendable {
    case rustBuildArtifacts
    case xcodeDerivedData
    case nodeDependencies
    case userCache
    case packageManagerCache
    case huggingFaceModelCache
    case moleCache

    var title: String {
        switch self {
        case .rustBuildArtifacts:
            String(localized: "Rust build artifacts")
        case .xcodeDerivedData:
            String(localized: "Xcode Derived Data")
        case .nodeDependencies:
            String(localized: "Node dependencies")
        case .userCache:
            String(localized: "Application cache")
        case .packageManagerCache:
            String(localized: "Package manager cache")
        case .huggingFaceModelCache:
            String(localized: "Hugging Face model cache")
        case .moleCache:
            String(localized: "Mole cache")
        }
    }

    var explanation: String {
        switch self {
        case .rustBuildArtifacts:
            String(localized: "Cargo recreates this folder the next time the project builds.")
        case .xcodeDerivedData:
            String(localized: "Xcode recreates these indexes and build products as needed.")
        case .nodeDependencies:
            String(localized: "The package manager can restore these dependencies from the project lockfile.")
        case .userCache:
            String(localized: "The application can recreate this cached data, though its next launch may be slower.")
        case .packageManagerCache:
            String(localized: "Development tools recreate this download and build cache as needed.")
        case .huggingFaceModelCache:
            String(localized: "Hugging Face downloads cached models again when they are needed.")
        case .moleCache:
            String(localized: "Mole recreates this cache as needed.")
        }
    }

    var confidence: CleanupTargetConfidence {
        switch self {
        case .rustBuildArtifacts, .xcodeDerivedData, .nodeDependencies, .packageManagerCache:
            .high
        case .userCache, .huggingFaceModelCache, .moleCache:
            .reviewRecommended
        }
    }

    var consequence: String {
        switch self {
        case .rustBuildArtifacts:
            String(localized: "The next build must recompile the project.")
        case .xcodeDerivedData:
            String(localized: "Xcode must rebuild and reindex affected projects.")
        case .nodeDependencies:
            String(localized: "The dependencies must be installed again.")
        case .userCache:
            String(localized: "Quit the associated app first. Its next launch may be slower.")
        case .packageManagerCache:
            String(localized: "Packages may need to be downloaded again.")
        case .huggingFaceModelCache:
            String(localized: "Models must be downloaded again and will be unavailable offline until then.")
        case .moleCache:
            String(localized: "Quit Mole first. Its next operation may be slower.")
        }
    }
}

nonisolated struct CleanupTarget: Identifiable, Equatable, Sendable {
    let node: FileNodeRecord
    let kind: CleanupTargetKind

    var id: FileNodeRecord.ID { node.id }
}

nonisolated enum CleanupSuggestionSelection {
    static func highConfidenceIDs(
        in targets: [CleanupTarget],
        excluding unavailableIDs: Set<CleanupTarget.ID> = []
    ) -> Set<CleanupTarget.ID> {
        Set(targets.lazy.filter {
            $0.kind.confidence == .high && !unavailableIDs.contains($0.id)
        }.map(\.id))
    }

    static func availableIDs(
        in targets: [CleanupTarget],
        excluding unavailableIDs: Set<CleanupTarget.ID> = []
    ) -> Set<CleanupTarget.ID> {
        Set(targets.lazy.filter { !unavailableIDs.contains($0.id) }.map(\.id))
    }

    static func reconcile(
        _ selection: Set<CleanupTarget.ID>,
        targets: [CleanupTarget],
        excluding unavailableIDs: Set<CleanupTarget.ID> = []
    ) -> Set<CleanupTarget.ID> {
        selection.intersection(availableIDs(in: targets, excluding: unavailableIDs))
    }
}

nonisolated enum CleanupTargetClassifier {
    static let minimumSuggestedSize: Int64 = 300_000_000

    static func targets(in treeStore: FileTreeStore) -> [CleanupTarget] {
        let nodes = treeStore.nodesByID.values
        let markerNames: Set<String> = [
            "Cargo.toml", "package-lock.json", "pnpm-lock.yaml", "yarn.lock", "bun.lock", "bun.lockb"
        ]
        let markerPaths = Set(nodes.lazy.filter { markerNames.contains($0.name) }.map { normalizedPath($0.url.path) })

        return nodes.compactMap { node in
            classify(node, markerPaths: markerPaths)
        }
        .filter { $0.node.allocatedSize >= minimumSuggestedSize }
        .sorted {
            if $0.node.allocatedSize != $1.node.allocatedSize {
                return $0.node.allocatedSize > $1.node.allocatedSize
            }
            return $0.node.url.path.localizedStandardCompare($1.node.url.path) == .orderedAscending
        }
    }

    private static func classify(
        _ node: FileNodeRecord,
        markerPaths: Set<String>
    ) -> CleanupTarget? {
        guard node.isDirectory,
              !node.isSymbolicLink,
              !node.isSynthetic,
              !node.isAutoSummarized,
              node.isAccessible else {
            return nil
        }

        let path = normalizedPath(node.url.path)
        let parent = normalizedPath(node.url.deletingLastPathComponent().path)
        guard !isProtected(path) else { return nil }

        if node.name == "target",
           markerPaths.contains(parent + "/Cargo.toml") {
            return CleanupTarget(node: node, kind: .rustBuildArtifacts)
        }

        if isDirectChild(path, of: "Library/Developer/Xcode/DerivedData") {
            return CleanupTarget(node: node, kind: .xcodeDerivedData)
        }

        if node.name == "node_modules",
           ["package-lock.json", "pnpm-lock.yaml", "yarn.lock", "bun.lock", "bun.lockb"]
            .contains(where: { markerPaths.contains(parent + "/" + $0) }) {
            return CleanupTarget(node: node, kind: .nodeDependencies)
        }

        if isDirectChild(path, of: "Library/Caches") {
            return CleanupTarget(node: node, kind: .userCache)
        }

        if isKnownPackageManagerCache(path) {
            return CleanupTarget(node: node, kind: .packageManagerCache)
        }

        if path.hasSuffix("/.cache/huggingface") {
            return CleanupTarget(node: node, kind: .huggingFaceModelCache)
        }

        if path.hasSuffix("/.cache/mole") {
            return CleanupTarget(node: node, kind: .moleCache)
        }

        return nil
    }

    private static func isDirectChild(_ path: String, of suffix: String) -> Bool {
        let marker = "/" + suffix + "/"
        guard let range = path.range(of: marker, options: [.backwards]) else { return false }
        return !path[range.upperBound...].contains("/")
    }

    private static func isKnownPackageManagerCache(_ path: String) -> Bool {
        let suffixes = [
            "/.cargo/registry",
            "/.npm/_cacache",
            "/.cache/pip",
            "/.cache/uv",
            "/Library/Caches/Homebrew"
        ]
        return suffixes.contains { path.hasSuffix($0) }
    }

    private static func isProtected(_ path: String) -> Bool {
        let protectedSuffixes = ["/.cache/codex-runtimes"]
        return protectedSuffixes.contains { suffix in
            path.hasSuffix(suffix) || path.contains(suffix + "/")
        }
    }

    private static func normalizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }
}
