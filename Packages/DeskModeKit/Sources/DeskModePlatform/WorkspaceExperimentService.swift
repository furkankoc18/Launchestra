import AppKit
import DeskModeCore
import Foundation

public enum WorkspaceExperimentError: Error, Equatable, Sendable {
    case applicationNotFound(String)
    case applicationRejected
    case folderRejected
    case urlRejected
    case invalidURL
    case bookmarkCreationFailed
    case bookmarkResolutionFailed
}

public struct ResolvedBookmark: Equatable, Sendable {
    public let url: URL
    public let isStale: Bool

    public init(url: URL, isStale: Bool) {
        self.url = url
        self.isStale = isStale
    }
}

public enum FolderBookmark {
    public static func create(for url: URL) throws -> Data {
        guard url.isFileURL else {
            throw WorkspaceExperimentError.bookmarkCreationFailed
        }

        do {
            return try url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: [.isDirectoryKey],
                relativeTo: nil
            )
        } catch {
            throw WorkspaceExperimentError.bookmarkCreationFailed
        }
    }

    public static func resolve(_ data: Data) throws -> ResolvedBookmark {
        var isStale = false

        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return ResolvedBookmark(url: url, isStale: isStale)
        } catch {
            throw WorkspaceExperimentError.bookmarkResolutionFailed
        }
    }
}

@MainActor
public final class WorkspaceExperimentService {
    private let workspace: NSWorkspace

    public init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    /// A successful return means Launch Services accepted the request. It does
    /// not mean the target application finished loading its own content.
    @discardableResult
    public func openApplication(bundleIdentifier: String) async throws -> NSRunningApplication {
        guard let applicationURL = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            throw WorkspaceExperimentError.applicationNotFound(bundleIdentifier)
        }

        do {
            return try await workspace.openApplication(
                at: applicationURL,
                configuration: .init()
            )
        } catch {
            throw WorkspaceExperimentError.applicationRejected
        }
    }

    /// Opens a folder with Finder and reports only whether Launch Services
    /// accepted the request.
    public func openFolder(_ folderURL: URL) async throws {
        guard
            folderURL.isFileURL,
            let finderURL = workspace.urlForApplication(withBundleIdentifier: "com.apple.finder")
        else {
            throw WorkspaceExperimentError.folderRejected
        }

        do {
            _ = try await workspace.open(
                [folderURL],
                withApplicationAt: finderURL,
                configuration: .init()
            )
        } catch {
            throw WorkspaceExperimentError.folderRejected
        }
    }

    /// Opens an HTTP(S) URL with its default handler. No network request or
    /// page-readiness check is made by DeskMode.
    public func openWebURL(_ url: URL) throws {
        guard
            let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            url.host != nil
        else {
            throw WorkspaceExperimentError.invalidURL
        }

        guard workspace.open(url) else {
            throw WorkspaceExperimentError.urlRejected
        }
    }
}
