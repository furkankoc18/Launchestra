import AppKit
import DeskModeCore
import Foundation
import Testing
@testable import DeskModePlatform

@Test("A regular bookmark follows a moved test folder")
func bookmarkFollowsMovedFolder() throws {
    let root = FileManager.default.temporaryDirectory
        .appending(component: "DeskModeBookmarkTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    let original = root.appending(component: "Türkçe folder ' $() 🚀", directoryHint: .isDirectory)
    let moved = root.appending(component: "Moved folder", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: root) }

    try FileManager.default.createDirectory(at: original, withIntermediateDirectories: true)
    let bookmark = try FolderBookmark.create(for: original)
    try FileManager.default.moveItem(at: original, to: moved)

    let resolved = try FolderBookmark.resolve(bookmark)
    #expect(resolved.url.standardizedFileURL == moved.standardizedFileURL)
}

@Test("The opener rejects non-web URL schemes without launching anything")
@MainActor
func rejectsNonWebSchemes() {
    let service = WorkspaceExperimentService()
    #expect(throws: WorkspaceExperimentError.invalidURL) {
        try service.openWebURL(URL(string: "javascript:alert(1)")!)
    }
}

@Test("Opt-in smoke test exercises real Launch Services APIs", .enabled(if: ProcessInfo.processInfo.environment["DESKMODE_RUN_OS_SMOKE"] == "1"))
@MainActor
func realWorkspaceSmoke() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(component: "DeskMode OS smoke ' $() 🚀", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let folders = FolderReferenceService()
    let folderReference = try await folders.create(for: root)
    let date = Date()
    let profile = Profile(
        id: UUID(),
        name: "Real three-action smoke",
        createdAt: date,
        updatedAt: date,
        failurePolicy: .continue,
        shortcut: nil,
        actions: [
            ProfileAction(
                id: UUID(), label: "Safari", enabled: true,
                kind: .openApplication(
                    ApplicationReference(bundleIdentifier: "com.apple.Safari", displayName: "Safari")
                )
            ),
            ProfileAction(id: UUID(), label: "Folder", enabled: true, kind: .openFolder(folderReference)),
            ProfileAction(
                id: UUID(), label: "Local URL", enabled: true,
                kind: .openURL("http://localhost:65535/deskmode-smoke")
            ),
        ]
    )

    let result = try await ProfileRunner().run(
        profile: profile,
        dispatcher: WorkspaceDispatcher(folders: folders)
    )
    #expect(result.status == .completed)
    #expect(result.actions.map(\.status) == [.accepted, .accepted, .accepted])
}
