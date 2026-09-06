import DeskModeCore
import Foundation
import Testing
@testable import DeskModePlatform

private struct StaleBookmarkHandler: BookmarkDataHandling {
    let resolvedURL: URL
    func create(for url: URL) throws -> Data { Data("refreshed".utf8) }
    func resolve(_ data: Data) throws -> BookmarkDataResolution {
        BookmarkDataResolution(url: resolvedURL, isStale: true)
    }
}

private struct FailingBookmarkHandler: BookmarkDataHandling {
    func create(for url: URL) throws -> Data { Data("unused".utf8) }
    func resolve(_ data: Data) throws -> BookmarkDataResolution {
        throw FolderReferenceError.bookmarkResolutionFailed
    }
}

private actor RevisionRecordingRepository: ProfileRepository {
    var expectedRevisions: [Int] = []
    func load() async throws -> ProfileStore { .empty }
    func save(_ next: ProfileStore, expectedRevision: Int) async throws -> ProfileStore {
        expectedRevisions.append(expectedRevision)
        return next.replacingRevision(with: expectedRevision + 1)
    }
}

@Test("FolderReference creates and resolves a temporary directory bookmark after a move")
func folderReferenceFollowsMovedDirectory() async throws {
    let root = FileManager.default.temporaryDirectory.appending(component: "DeskModeFolder-\(UUID())")
    let original = root.appending(component: "Original", directoryHint: .isDirectory)
    let moved = root.appending(component: "Moved", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: original, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let service = FolderReferenceService()
    let reference = try await service.create(for: original)
    try FileManager.default.moveItem(at: original, to: moved)
    let resolution = try await service.resolve(reference)

    #expect(resolution.url.standardizedFileURL == moved.standardizedFileURL)
}

@Test("Resolution never falls back to lastKnownPath")
func folderReferenceDoesNotFallbackToPath() async throws {
    let root = FileManager.default.temporaryDirectory.appending(component: "DeskModeFallback-\(UUID())")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let reference = FolderReference(
        bookmarkBase64: Data("broken".utf8).base64EncodedString(),
        lastKnownPath: root.path,
        displayName: root.lastPathComponent
    )

    await #expect(throws: FolderReferenceError.bookmarkResolutionFailed) {
        try await FolderReferenceService(handler: FailingBookmarkHandler()).resolve(reference)
    }
}

@Test("A stale bookmark refresh is saved using the loaded revision")
func staleBookmarkRevisionControlledRepair() async throws {
    let root = FileManager.default.temporaryDirectory.appending(component: "DeskModeStale-\(UUID())")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let actionID = UUID()
    let profileID = UUID()
    let date = Date(timeIntervalSince1970: 1_788_602_400)
    let reference = FolderReference(
        bookmarkBase64: Data("old".utf8).base64EncodedString(),
        lastKnownPath: "/old/location",
        displayName: "Old"
    )
    let store = ProfileStore(
        revision: 7,
        profiles: [Profile(
            id: profileID,
            name: "Work",
            createdAt: date,
            updatedAt: date,
            failurePolicy: .continue,
            shortcut: nil,
            actions: [ProfileAction(id: actionID, label: nil, enabled: true, kind: .openFolder(reference))]
        )]
    )
    let repository = RevisionRecordingRepository()
    let resolver = FolderReferenceService(handler: StaleBookmarkHandler(resolvedURL: root))
    let result = try await FolderReferenceRepairService(resolver: resolver, repository: repository)
        .resolveAndRepair(store: store, profileID: profileID, actionID: actionID)

    #expect(result.didRefreshBookmark)
    #expect(result.store.revision == 8)
    #expect(await repository.expectedRevisions == [7])
    guard case let .openFolder(updated) = result.store.profiles[0].actions[0].kind else {
        Issue.record("Expected a folder action")
        return
    }
    #expect(updated.lastKnownPath == root.path)
    #expect(updated.bookmarkBase64 == Data("refreshed".utf8).base64EncodedString())
}
