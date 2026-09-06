import DeskModeCore
import Foundation
import Testing
@testable import DeskModePlatform

@MainActor
private final class FakeWorkspaceClient: WorkspaceClient {
    var applications: [String: URL] = [:]
    var finder: URL? = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
    var openedApplications: [URL] = []
    var openedFolders: [URL] = []
    var openedWebURLs: [URL] = []
    var rejectApplication = false
    var rejectFolder = false
    var rejectURL = false

    func applicationURL(bundleIdentifier: String) -> URL? { applications[bundleIdentifier] }
    func finderURL() -> URL? { finder }
    func openApplication(at url: URL) async throws {
        if rejectApplication { throw CocoaError(.fileReadNoPermission) }
        openedApplications.append(url)
    }
    func openFolder(_ folder: URL, with finder: URL) async throws {
        if rejectFolder { throw CocoaError(.fileNoSuchFile) }
        openedFolders.append(folder)
    }
    func openURL(_ url: URL) -> Bool {
        guard !rejectURL else { return false }
        openedWebURLs.append(url)
        return true
    }
}

@Test("Application preflight reports a typed missing-app error")
@MainActor
func dispatcherMissingApplication() async {
    let dispatcher = WorkspaceDispatcher(client: FakeWorkspaceClient())
    let action = ProfileAction(
        id: UUID(), label: nil, enabled: true,
        kind: .openApplication(ApplicationReference(bundleIdentifier: "missing.app", displayName: "Missing"))
    )
    #expect(await dispatcher.preflight(action) == .failure(.applicationNotFound))
}

@Test("WorkspaceDispatcher exposes only the three allowed open operations and maps acceptance")
@MainActor
func dispatcherAllowedOperations() async throws {
    let client = FakeWorkspaceClient()
    let appURL = URL(fileURLWithPath: "/Applications/Test.app")
    let folderURL = URL(fileURLWithPath: "/tmp/Test", isDirectory: true)
    let webURL = try #require(URL(string: "https://example.test/path"))
    client.applications["test.app"] = appURL
    let dispatcher = WorkspaceDispatcher(client: client)

    #expect(resultError(await dispatchResult { dispatcher.openApplication(at: appURL, completion: $0) }) == nil)
    #expect(resultError(await dispatchResult { dispatcher.openFolder(folderURL, completion: $0) }) == nil)
    #expect(resultError(await dispatchResult { dispatcher.openURL(webURL, completion: $0) }) == nil)
    #expect(client.openedApplications == [appURL])
    #expect(client.openedFolders == [folderURL])
    #expect(client.openedWebURLs == [webURL])
}

@Test("URL allowlist rejects unsafe schemes before the workspace client")
@MainActor
func dispatcherURLAllowlist() async throws {
    let client = FakeWorkspaceClient()
    let dispatcher = WorkspaceDispatcher(client: client)
    let fileURL = URL(fileURLWithPath: "/tmp/private-token")
    let result = await dispatchResult { dispatcher.openURL(fileURL, completion: $0) }
    #expect(resultError(result) == .invalidURL)
    #expect(client.openedWebURLs.isEmpty)
    #expect(!String(describing: result).contains("private-token"))
}

@Test("Workspace errors map to stable codes without exposing raw resource paths")
@MainActor
func dispatcherErrorPrivacy() async {
    let client = FakeWorkspaceClient()
    client.rejectApplication = true
    let dispatcher = WorkspaceDispatcher(client: client)
    let secret = URL(fileURLWithPath: "/Users/person/Secret Project.app")
    let result = await dispatchResult { dispatcher.openApplication(at: secret, completion: $0) }
    #expect(resultError(result) == .accessDenied)
    #expect(!String(describing: result).contains("Secret Project"))
}

@MainActor
private func dispatchResult(
    _ begin: (@escaping @Sendable (Result<Void, RunErrorCode>) -> Void) -> DispatchCancellation
) async -> Result<Void, RunErrorCode> {
    await withCheckedContinuation { continuation in
        _ = begin { continuation.resume(returning: $0) }
    }
}

private func resultError(_ result: Result<Void, RunErrorCode>) -> RunErrorCode? {
    if case let .failure(error) = result { return error }
    return nil
}
