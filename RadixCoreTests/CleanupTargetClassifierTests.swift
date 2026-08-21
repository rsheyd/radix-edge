import XCTest
@testable import RadixCore

final class CleanupTargetClassifierTests: XCTestCase {
    func testFindsOnlyConservativeRebuildableTargets() {
        let rootURL = URL(fileURLWithPath: "/Users/test")
        let cargoManifest = file(rootURL.appending(path: "project/Cargo.toml"))
        let rustTarget = directory(rootURL.appending(path: "project/target"), size: 600_000_000)
        let unrelatedTarget = directory(rootURL.appending(path: "notes/target"), size: 500_000_000)
        let packageLock = file(rootURL.appending(path: "web/package-lock.json"))
        let nodeModules = directory(rootURL.appending(path: "web/node_modules"), size: 400_000_000)
        let cache = directory(rootURL.appending(path: "Library/Caches/example.app"), size: 300_000_000)

        let children = [cargoManifest, rustTarget, unrelatedTarget, packageLock, nodeModules, cache]
        let root = FileNodeRecord.directory(
            id: rootURL.path,
            url: rootURL,
            name: "test",
            children: children,
            lastModified: nil,
            isPackage: false,
            isAccessible: true
        )
        let store = FileTreeStore(root: root, childrenByID: [root.id: children])

        let targets = CleanupTargetClassifier.targets(in: store)

        XCTAssertEqual(targets.map(\.node.id), [rustTarget.id, nodeModules.id, cache.id])
        XCTAssertEqual(targets.map(\.kind), [.rustBuildArtifacts, .nodeDependencies, .userCache])
    }

    func testRejectsUnsafeOrIncompleteNodes() {
        let rootURL = URL(fileURLWithPath: "/Users/test")
        let inaccessibleCache = FileNodeRecord(
            id: rootURL.appending(path: "Library/Caches/private").path,
            url: rootURL.appending(path: "Library/Caches/private"),
            name: "private",
            isDirectory: true,
            isSymbolicLink: false,
            allocatedSize: 400_000_000,
            logicalSize: 400_000_000,
            descendantFileCount: 1,
            lastModified: nil,
            isPackage: false,
            isAccessible: false,
            isSelfAccessible: true,
            isSynthetic: false,
            isAutoSummarized: false
        )
        let root = FileNodeRecord.directory(
            id: rootURL.path,
            url: rootURL,
            name: "test",
            children: [inaccessibleCache],
            lastModified: nil,
            isPackage: false,
            isAccessible: true
        )

        let store = FileTreeStore(root: root, childrenByID: [root.id: [inaccessibleCache]])
        XCTAssertTrue(CleanupTargetClassifier.targets(in: store).isEmpty)
    }

    func testFindsExplicitModelAndToolCachesButProtectsCodexRuntimes() {
        let rootURL = URL(fileURLWithPath: "/Users/test")
        let huggingFace = directory(rootURL.appending(path: ".cache/huggingface"), size: 500_000_000)
        let mole = directory(rootURL.appending(path: ".cache/mole"), size: 400_000_000)
        let codexRuntimes = directory(rootURL.appending(path: ".cache/codex-runtimes"), size: 900_000_000)
        let protectedChild = directory(
            rootURL.appending(path: ".cache/codex-runtimes/Library/Caches/runtime-helper"),
            size: 800_000_000
        )
        let children = [huggingFace, mole, codexRuntimes, protectedChild]
        let root = FileNodeRecord.directory(
            id: rootURL.path,
            url: rootURL,
            name: "test",
            children: children,
            lastModified: nil,
            isPackage: false,
            isAccessible: true
        )
        let store = FileTreeStore(root: root, childrenByID: [root.id: children])

        let targets = CleanupTargetClassifier.targets(in: store)

        XCTAssertEqual(targets.map(\.kind), [.huggingFaceModelCache, .moleCache])
        XCTAssertEqual(targets.map(\.kind.confidence), [.reviewRecommended, .reviewRecommended])
        XCTAssertFalse(targets.contains { $0.node.id == codexRuntimes.id })
        XCTAssertFalse(targets.contains { $0.node.id == protectedChild.id })
    }

    func testCategoryMetadataDistinguishesHighConfidenceFromReviewRecommended() {
        XCTAssertEqual(CleanupTargetKind.rustBuildArtifacts.confidence, .high)
        XCTAssertEqual(CleanupTargetKind.packageManagerCache.confidence, .high)
        XCTAssertEqual(CleanupTargetKind.userCache.confidence, .reviewRecommended)
        XCTAssertFalse(CleanupTargetKind.huggingFaceModelCache.consequence.isEmpty)
    }

    func testOmitsSuggestionsSmallerThan300Megabytes() {
        let rootURL = URL(fileURLWithPath: "/Users/test")
        let belowMinimum = directory(
            rootURL.appending(path: "Library/Caches/small.app"),
            size: 299_999_999
        )
        let atMinimum = directory(
            rootURL.appending(path: "Library/Caches/large.app"),
            size: 300_000_000
        )
        let root = FileNodeRecord.directory(
            id: rootURL.path,
            url: rootURL,
            name: "test",
            children: [belowMinimum, atMinimum],
            lastModified: nil,
            isPackage: false,
            isAccessible: true
        )
        let store = FileTreeStore(root: root, childrenByID: [root.id: [belowMinimum, atMinimum]])

        XCTAssertEqual(CleanupTargetClassifier.targets(in: store).map(\.node.id), [atMinimum.id])
    }

    func testCleanupSuggestionSelectionStartsWithAvailableHighConfidenceTargets() {
        let highConfidence = cleanupTarget("/cleanup/high", kind: .rustBuildArtifacts)
        let unavailableHighConfidence = cleanupTarget("/cleanup/added", kind: .nodeDependencies)
        let reviewRecommended = cleanupTarget("/cleanup/review", kind: .userCache)
        let targets = [highConfidence, unavailableHighConfidence, reviewRecommended]

        let selection = CleanupSuggestionSelection.highConfidenceIDs(
            in: targets,
            excluding: [unavailableHighConfidence.id]
        )

        XCTAssertEqual(selection, [highConfidence.id])
    }

    func testCleanupSuggestionSelectionCommandsSkipUnavailableTargets() {
        let first = cleanupTarget("/cleanup/first", kind: .rustBuildArtifacts)
        let unavailable = cleanupTarget("/cleanup/added", kind: .nodeDependencies)
        let reviewRecommended = cleanupTarget("/cleanup/review", kind: .userCache)
        let targets = [first, unavailable, reviewRecommended]

        XCTAssertEqual(
            CleanupSuggestionSelection.availableIDs(in: targets, excluding: [unavailable.id]),
            [first.id, reviewRecommended.id]
        )
        XCTAssertEqual(
            CleanupSuggestionSelection.reconcile(
                [first.id, unavailable.id, "/cleanup/missing"],
                targets: targets,
                excluding: [unavailable.id]
            ),
            [first.id]
        )
    }

    private func directory(_ url: URL, size: Int64) -> FileNodeRecord {
        FileNodeRecord(
            id: url.path,
            url: url,
            name: url.lastPathComponent,
            isDirectory: true,
            isSymbolicLink: false,
            allocatedSize: size,
            logicalSize: size,
            descendantFileCount: 1,
            lastModified: nil,
            isPackage: false,
            isAccessible: true,
            isSelfAccessible: true,
            isSynthetic: false,
            isAutoSummarized: false
        )
    }

    private func cleanupTarget(_ path: String, kind: CleanupTargetKind) -> CleanupTarget {
        CleanupTarget(
            node: directory(URL(fileURLWithPath: path), size: 1_000),
            kind: kind
        )
    }

    private func file(_ url: URL) -> FileNodeRecord {
        FileNodeRecord(
            id: url.path,
            url: url,
            name: url.lastPathComponent,
            isDirectory: false,
            isSymbolicLink: false,
            allocatedSize: 1,
            logicalSize: 1,
            descendantFileCount: 0,
            lastModified: nil,
            isPackage: false,
            isAccessible: true,
            isSelfAccessible: true,
            isSynthetic: false,
            isAutoSummarized: false
        )
    }
}
