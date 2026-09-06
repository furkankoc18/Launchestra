import AppKit
import DeskModeCore
import Foundation

@MainActor
public protocol WorkspaceClient: Sendable {
    func applicationURL(bundleIdentifier: String) -> URL?
    func finderURL() -> URL?
    func openApplication(at url: URL) async throws
    func openFolder(_ folder: URL, with finder: URL) async throws
    func openURL(_ url: URL) -> Bool
}

@MainActor
public final class SystemWorkspaceClient: WorkspaceClient {
    private let workspace: NSWorkspace

    public init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    public func applicationURL(bundleIdentifier: String) -> URL? {
        workspace.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    public func finderURL() -> URL? {
        workspace.urlForApplication(withBundleIdentifier: "com.apple.finder")
    }

    public func openApplication(at url: URL) async throws {
        _ = try await workspace.openApplication(at: url, configuration: .init())
    }

    public func openFolder(_ folder: URL, with finder: URL) async throws {
        _ = try await workspace.open([folder], withApplicationAt: finder, configuration: .init())
    }

    public func openURL(_ url: URL) -> Bool {
        workspace.open(url)
    }
}

@MainActor
public final class WorkspaceDispatcher: ActionDispatching {
    private let client: any WorkspaceClient
    private let folders: FolderReferenceService

    public init(
        client: any WorkspaceClient = SystemWorkspaceClient(),
        folders: FolderReferenceService = FolderReferenceService()
    ) {
        self.client = client
        self.folders = folders
    }

    public func preflight(_ action: ProfileAction) async -> Result<PreparedAction, RunErrorCode> {
        switch action.kind {
        case let .openApplication(reference):
            guard let url = client.applicationURL(bundleIdentifier: reference.bundleIdentifier) else {
                return .failure(.applicationNotFound)
            }
            return .success(.application(url))

        case let .openFolder(reference):
            do {
                let resolution = try await folders.resolve(reference)
                return .success(.folder(resolution.url))
            } catch FolderReferenceError.resourceMissing,
                    FolderReferenceError.notDirectory,
                    FolderReferenceError.bookmarkResolutionFailed,
                    FolderReferenceError.invalidBookmarkEncoding {
                return .failure(.folderUnresolved)
            } catch {
                return .failure(.accessDenied)
            }

        case let .openURL(value):
            guard let url = WebURLPolicy.url(from: value) else { return .failure(.invalidURL) }
            return .success(.web(url))
        }
    }

    public func dispatch(
        _ action: PreparedAction,
        completion: @escaping @Sendable (Result<Void, RunErrorCode>) -> Void
    ) -> DispatchCancellation {
        switch action {
        case let .application(url): return openApplication(at: url, completion: completion)
        case let .folder(url): return openFolder(url, completion: completion)
        case let .web(url): return openURL(url, completion: completion)
        }
    }

    public func openApplication(
        at url: URL,
        completion: @escaping @Sendable (Result<Void, RunErrorCode>) -> Void
    ) -> DispatchCancellation {
        let client = self.client
        let task = Task { @MainActor in
            do {
                try await client.openApplication(at: url)
                completion(.success(()))
            } catch {
                completion(.failure(Self.map(error)))
            }
        }
        return DispatchCancellation { task.cancel() }
    }

    public func openFolder(
        _ url: URL,
        completion: @escaping @Sendable (Result<Void, RunErrorCode>) -> Void
    ) -> DispatchCancellation {
        guard let finder = client.finderURL() else {
            completion(.failure(.applicationNotFound))
            return DispatchCancellation()
        }
        let client = self.client
        let task = Task { @MainActor in
            do {
                try await client.openFolder(url, with: finder)
                completion(.success(()))
            } catch {
                completion(.failure(Self.map(error)))
            }
        }
        return DispatchCancellation { task.cancel() }
    }

    public func openURL(
        _ url: URL,
        completion: @escaping @Sendable (Result<Void, RunErrorCode>) -> Void
    ) -> DispatchCancellation {
        guard WebURLPolicy.url(from: url.absoluteString) != nil else {
            completion(.failure(.invalidURL))
            return DispatchCancellation()
        }
        completion(client.openURL(url) ? .success(()) : .failure(.launchRejected))
        return DispatchCancellation()
    }

    private nonisolated static func map(_ error: Error) -> RunErrorCode {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoPermissionError
            ? .accessDenied
            : .launchRejected
    }
}
