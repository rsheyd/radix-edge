import XCTest
@testable import RadixCore

final class CleanupTargetClassifierTests: XCTestCase {
    func testFindsOnlyConservativeRebuildableTargets() {
        let rootURL = URL(fileURLWithPath: "/Users/test")
        let cargoManifest = file(rootURL.appending(path: "project/Cargo.toml"))
        let rustTarget = directory(rootURL.appending(path: "project/target"), size: 4_000)
        let unrelatedTarget = directory(rootURL.appending(path: "notes/target"), size: 3_000)
        let packageLock = file(rootURL.appending(path: "web/package-lock.json"))
        let nodeModules = directory(rootURL.appending(path: "web/node_modules"), size: 2_000)
        let cache = directory(rootURL.appending(path: "Library/Caches/example.app"), size: 1_000)

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
            allocatedSize: 10_000,
            logicalSize: 10_000,
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
        let huggingFace = directory(rootURL.appending(path: ".cache/huggingface"), size: 3_000)
        let mole = directory(rootURL.appending(path: ".cache/mole"), size: 2_000)
        let codexRuntimes = directory(rootURL.appending(path: ".cache/codex-runtimes"), size: 9_000)
        let protectedChild = directory(
            rootURL.appending(path: ".cache/codex-runtimes/Library/Caches/runtime-helper"),
            size: 8_000
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
