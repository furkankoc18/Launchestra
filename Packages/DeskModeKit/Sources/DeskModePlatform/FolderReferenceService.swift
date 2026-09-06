import DeskModeCore
import Foundation

public enum FolderReferenceError: Error, Equatable, Sendable {
    case notFileURL
    case notDirectory
    case bookmarkCreationFailed
    case invalidBookmarkEncoding
    case bookmarkResolutionFailed
    case resourceMissing
}

public struct FolderReferenceResolution: Equatable, Sendable {
    public let url: URL
    public let refreshedReference: FolderReference?

    public init(url: URL, refreshedReference: FolderReference?) {
        self.url = url
        self.refreshedReference = refreshedReference
    }
}

public struct BookmarkDataResolution: Equatable, Sendable {
    public let url: URL
    public let isStale: Bool

    public init(url: URL, isStale: Bool) {
        self.url = url
        self.isStale = isStale
    }
}

public protocol BookmarkDataHandling: Sendable {
    func create(for url: URL) throws -> Data
    func resolve(_ data: Data) throws -> BookmarkDataResolution
}

public struct FoundationBookmarkDataHandler: BookmarkDataHandling {
    public init() {}

    public func create(for url: URL) throws -> Data {
        do {
            return try url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: [.isDirectoryKey],
                relativeTo: nil
            )
        } catch {
            throw FolderReferenceError.bookmarkCreationFailed
        }
    }

    public func resolve(_ data: Data) throws -> BookmarkDataResolution {
        var stale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            return BookmarkDataResolution(url: url, isStale: stale)
        } catch {
            throw FolderReferenceError.bookmarkResolutionFailed
        }
    }
}

public actor FolderReferenceService {
    private let handler: any BookmarkDataHandling
    private let fileManager: FileManager

    public init(
        handler: any BookmarkDataHandling = FoundationBookmarkDataHandler(),
        fileManager: FileManager = .default
    ) {
        self.handler = handler
        self.fileManager = fileManager
    }

    public func create(for url: URL) throws -> FolderReference {
        guard url.isFileURL else { throw FolderReferenceError.notFileURL }
        try verifyDirectory(at: url)
        let data = try handler.create(for: url)
        guard !data.isEmpty, data.count <= ProfileStoreValidator.maximumBookmarkBytes else {
            throw FolderReferenceError.bookmarkCreationFailed
        }
        return makeReference(data: data, url: url)
    }

    public func resolve(_ reference: FolderReference) throws -> FolderReferenceResolution {
        guard
            let data = Data(base64Encoded: reference.bookmarkBase64),
            !data.isEmpty,
            data.count <= ProfileStoreValidator.maximumBookmarkBytes
        else {
            throw FolderReferenceError.invalidBookmarkEncoding
        }

        let bookmark = try handler.resolve(data)
        guard bookmark.url.isFileURL else { throw FolderReferenceError.bookmarkResolutionFailed }
        try verifyDirectory(at: bookmark.url)

        let refreshed = bookmark.isStale
            ? try create(for: bookmark.url)
            : nil
        return FolderReferenceResolution(url: bookmark.url, refreshedReference: refreshed)
    }

    private func verifyDirectory(at url: URL) throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw FolderReferenceError.resourceMissing
        }
        guard isDirectory.boolValue else { throw FolderReferenceError.notDirectory }
    }

    private func makeReference(data: Data, url: URL) -> FolderReference {
        FolderReference(
            bookmarkBase64: data.base64EncodedString(),
            lastKnownPath: url.path(percentEncoded: false),
            displayName: url.lastPathComponent
        )
    }
}

public struct FolderRepairResult: Equatable, Sendable {
    public let url: URL
    public let store: ProfileStore
    public let didRefreshBookmark: Bool
}

public actor FolderReferenceRepairService {
    private let resolver: FolderReferenceService
    private let repository: any ProfileRepository

    public init(resolver: FolderReferenceService, repository: any ProfileRepository) {
        self.resolver = resolver
        self.repository = repository
    }

    public func resolveAndRepair(
        store: ProfileStore,
        profileID: UUID,
        actionID: UUID
    ) async throws -> FolderRepairResult {
        guard
            let profileIndex = store.profiles.firstIndex(where: { $0.id == profileID }),
            let actionIndex = store.profiles[profileIndex].actions.firstIndex(where: { $0.id == actionID }),
            case let .openFolder(reference) = store.profiles[profileIndex].actions[actionIndex].kind
        else {
            throw FolderReferenceError.bookmarkResolutionFailed
        }

        let resolution = try await resolver.resolve(reference)
        guard let refreshedReference = resolution.refreshedReference else {
            return FolderRepairResult(url: resolution.url, store: store, didRefreshBookmark: false)
        }

        var profiles = store.profiles
        let oldProfile = profiles[profileIndex]
        var actions = oldProfile.actions
        let oldAction = actions[actionIndex]
        actions[actionIndex] = ProfileAction(
            id: oldAction.id,
            label: oldAction.label,
            enabled: oldAction.enabled,
            timeoutSeconds: oldAction.timeoutSeconds,
            kind: .openFolder(refreshedReference)
        )
        profiles[profileIndex] = Profile(
            id: oldProfile.id,
            name: oldProfile.name,
            createdAt: oldProfile.createdAt,
            updatedAt: Date(),
            failurePolicy: oldProfile.failurePolicy,
            shortcut: oldProfile.shortcut,
            actions: actions
        )
        let draft = ProfileStore(
            schemaVersion: store.schemaVersion,
            revision: store.revision,
            profiles: profiles
        )
        let committed = try await repository.save(draft, expectedRevision: store.revision)
        return FolderRepairResult(url: resolution.url, store: committed, didRefreshBookmark: true)
    }
}
