import DeskModeCore
import Foundation
import Testing
@testable import DeskModePlatform

private struct FailAtStage: RepositoryFaultInjecting {
    let stage: RepositoryWriteStage

    func shouldFail(at stage: RepositoryWriteStage) -> Bool {
        self.stage == stage
    }
}

@Test("Repository creates, replaces and backs up the last verified main store")
func repositoryCreateReplaceAndBackup() async throws {
    let root = temporaryRepositoryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let repository = try JSONProfileRepository(directoryURL: root)

    #expect(try await repository.load() == .empty)
    let first = try await repository.save(makeRepositoryStore(revision: 0, name: "First"), expectedRevision: 0)
    #expect(first.revision == 1)
    #expect(!FileManager.default.fileExists(atPath: repository.backupFileURL.path))

    let secondDraft = makeRepositoryStore(revision: 1, name: "Second")
    let second = try await repository.save(secondDraft, expectedRevision: 1)
    #expect(second.revision == 2)

    let mainData = try Data(contentsOf: repository.mainFileURL)
    let backupData = try Data(contentsOf: repository.backupFileURL)
    let main = try ProfileStoreCoding.makeDecoder().decode(ProfileStore.self, from: mainData)
    let backup = try ProfileStoreCoding.makeDecoder().decode(ProfileStore.self, from: backupData)
    #expect(main.revision == 2)
    #expect(main.profiles[0].name == "Second")
    #expect(backup.revision == 1)
    #expect(backup.profiles[0].name == "First")
}

@Test("Profile order survives a repository restart")
func repositoryPreservesProfileOrderAcrossRestart() async throws {
    let root = temporaryRepositoryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let date = Date(timeIntervalSince1970: 1_788_602_400)
    let first = Profile(
        id: UUID(), name: "First", createdAt: date, updatedAt: date,
        failurePolicy: .continue, shortcut: nil, actions: []
    )
    let second = Profile(
        id: UUID(), name: "Second", createdAt: date, updatedAt: date,
        failurePolicy: .continue, shortcut: nil, actions: []
    )

    do {
        let repository = try JSONProfileRepository(directoryURL: root)
        _ = try await repository.load()
        let initial = ProfileStore(revision: 0, profiles: [first, second])
        let reordered = ProfileStoreEditor.moving(profileID: second.id, by: -1, in: initial)
        _ = try await repository.save(reordered, expectedRevision: 0)
    }

    let reopened = try JSONProfileRepository(directoryURL: root)
    let loaded = try await reopened.load()
    #expect(loaded.revision == 1)
    #expect(loaded.profiles.map(\.id) == [second.id, first.id])
}

@Test("Revision mismatch preserves disk and reports the current revision")
func repositoryRevisionConflict() async throws {
    let root = temporaryRepositoryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let repository = try JSONProfileRepository(directoryURL: root)
    _ = try await repository.load()
    let saved = try await repository.save(makeRepositoryStore(revision: 0), expectedRevision: 0)
    let before = try Data(contentsOf: repository.mainFileURL)

    await #expect(throws: JSONProfileRepositoryError.revisionConflict(expected: 0, actual: 1)) {
        try await repository.save(saved, expectedRevision: 0)
    }
    #expect(try Data(contentsOf: repository.mainFileURL) == before)
}

@Test("A changed on-disk fingerprint blocks a stale writer")
func repositoryExternalModification() async throws {
    let root = temporaryRepositoryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let repository = try JSONProfileRepository(directoryURL: root)
    _ = try await repository.load()
    let saved = try await repository.save(makeRepositoryStore(revision: 0), expectedRevision: 0)

    var externalObject = try #require(
        JSONSerialization.jsonObject(with: Data(contentsOf: repository.mainFileURL)) as? [String: Any]
    )
    externalObject["revision"] = 9
    let externalData = try JSONSerialization.data(withJSONObject: externalObject, options: [.sortedKeys])
    try externalData.write(to: repository.mainFileURL, options: .atomic)

    await #expect(throws: JSONProfileRepositoryError.externalModification) {
        try await repository.save(saved, expectedRevision: 1)
    }
    #expect(try Data(contentsOf: repository.mainFileURL) == externalData)
}

@Test("Only one repository writer can hold a directory lock")
func repositoryWriterLock() throws {
    let root = temporaryRepositoryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let first = try JSONProfileRepository(directoryURL: root)

    #expect(throws: JSONProfileRepositoryError.writerLockUnavailable) {
        _ = try JSONProfileRepository(directoryURL: root)
    }
    withExtendedLifetime(first) {}
}

@Test("Every injected pre-commit failure preserves the previous main store", arguments: RepositoryWriteStage.allCases)
func repositoryFaultInjection(stage: RepositoryWriteStage) async throws {
    let root = temporaryRepositoryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    if stage != .beforeCreateMain {
        try await createBaselineRepository(at: root)
    }

    let before = try? Data(
        contentsOf: root.appending(component: "profiles.json", directoryHint: .notDirectory)
    )
    let repository = try JSONProfileRepository(
        directoryURL: root,
        faultInjector: FailAtStage(stage: stage)
    )
    let current = try await repository.load()
    let draft = makeRepositoryStore(revision: current.revision, name: "Changed")

    await #expect(throws: JSONProfileRepositoryError.injectedFailure(stage)) {
        try await repository.save(draft, expectedRevision: current.revision)
    }

    let after = try? Data(
        contentsOf: root.appending(component: "profiles.json", directoryHint: .notDirectory)
    )
    #expect(after == before)
    let leftovers = try FileManager.default.contentsOfDirectory(atPath: root.path)
        .filter { $0.hasPrefix(".profiles-") || $0.hasPrefix(".profiles-backup-") }
    #expect(leftovers.isEmpty)
}

@Test("Invalid main data is never copied over an existing backup")
func invalidMainPreservesBackup() async throws {
    let root = temporaryRepositoryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let backupURL = root.appending(component: "profiles.backup.json", directoryHint: .notDirectory)
    let mainURL = root.appending(component: "profiles.json", directoryHint: .notDirectory)
    let backup = try ProfileStoreCoding.makeEncoder().encode(makeRepositoryStore(revision: 3))
    try backup.write(to: backupURL)
    try Data("{broken".utf8).write(to: mainURL)
    let repository = try JSONProfileRepository(directoryURL: root)

    await #expect(throws: JSONProfileRepositoryError.invalidData) {
        try await repository.load()
    }
    #expect(try Data(contentsOf: backupURL) == backup)
    #expect(try String(contentsOf: mainURL, encoding: .utf8) == "{broken")
}

@Test("A missing main with a backup requires explicit recovery")
func missingMainRequiresRecovery() async throws {
    let root = temporaryRepositoryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try ProfileStoreCoding.makeEncoder().encode(makeRepositoryStore(revision: 3)).write(
        to: root.appending(component: "profiles.backup.json", directoryHint: .notDirectory)
    )
    let repository = try JSONProfileRepository(directoryURL: root)

    await #expect(throws: JSONProfileRepositoryError.mainMissingBackupAvailable) {
        try await repository.load()
    }
}

@Test("A missing main with an invalid backup reports invalid data")
func invalidBackupIsNotARecoveryCandidate() async throws {
    let root = temporaryRepositoryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("{}".utf8).write(
        to: root.appending(component: "profiles.backup.json", directoryHint: .notDirectory)
    )
    let repository = try JSONProfileRepository(directoryURL: root)

    await #expect(throws: JSONProfileRepositoryError.invalidData) {
        try await repository.load()
    }
}

@Test("Recovery distinguishes missing, invalid and unsupported main data")
func repositoryRecoveryStates() async throws {
    let missingRoot = temporaryRepositoryDirectory()
    defer { try? FileManager.default.removeItem(at: missingRoot) }
    try FileManager.default.createDirectory(at: missingRoot, withIntermediateDirectories: true)
    let backupData = try ProfileStoreCoding.makeEncoder().encode(makeRepositoryStore(revision: 4, name: "Backup"))
    try backupData.write(to: missingRoot.appending(component: "profiles.backup.json"))
    let missingRepository = try JSONProfileRepository(directoryURL: missingRoot)
    let missing = try #require(await missingRepository.recoveryState())
    #expect(missing.cause == .mainMissing)
    #expect(missing.backupAvailable)

    let invalidRoot = temporaryRepositoryDirectory()
    defer { try? FileManager.default.removeItem(at: invalidRoot) }
    try FileManager.default.createDirectory(at: invalidRoot, withIntermediateDirectories: true)
    try Data("{broken".utf8).write(to: invalidRoot.appending(component: "profiles.json"))
    try backupData.write(to: invalidRoot.appending(component: "profiles.backup.json"))
    let invalidRepository = try JSONProfileRepository(directoryURL: invalidRoot)
    let invalid = try #require(await invalidRepository.recoveryState())
    #expect(invalid.cause == .mainInvalid)
    #expect(invalid.backupAvailable)

    let unsupportedRoot = temporaryRepositoryDirectory()
    defer { try? FileManager.default.removeItem(at: unsupportedRoot) }
    try FileManager.default.createDirectory(at: unsupportedRoot, withIntermediateDirectories: true)
    try Data("{\"schemaVersion\":999,\"revision\":0,\"profiles\":[]}".utf8).write(
        to: unsupportedRoot.appending(component: "profiles.json")
    )
    try backupData.write(to: unsupportedRoot.appending(component: "profiles.backup.json"))
    let unsupportedRepository = try JSONProfileRepository(directoryURL: unsupportedRoot)
    let unsupported = try #require(await unsupportedRepository.recoveryState())
    #expect(unsupported.cause == .unsupportedSchemaVersion(999))
    #expect(!unsupported.backupAvailable)
}

@Test("Explicit restore preserves invalid main and installs the verified backup")
func repositoryExplicitRestore() async throws {
    let root = temporaryRepositoryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let broken = Data("{private-corrupt-sentinel".utf8)
    try broken.write(to: root.appending(component: "profiles.json"))
    try ProfileStoreCoding.makeEncoder().encode(makeRepositoryStore(revision: 8, name: "Restored")).write(
        to: root.appending(component: "profiles.backup.json")
    )
    let repository = try JSONProfileRepository(directoryURL: root)

    let restored = try await repository.restoreBackup()
    #expect(restored.revision == 8)
    #expect(restored.profiles.first?.name == "Restored")
    #expect(try await repository.load() == restored)
    let recoveryNames = try FileManager.default.contentsOfDirectory(atPath: root.path)
        .filter { $0.hasPrefix("profiles.recovery-before-restore-") }
    #expect(recoveryNames.count == 1)
    #expect(try Data(contentsOf: root.appending(component: recoveryNames[0])) == broken)
}

@Test("Explicit reset keeps a recovery copy before creating an empty store")
func repositoryExplicitReset() async throws {
    let root = temporaryRepositoryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let unsupported = Data("{\"schemaVersion\":999,\"private\":\"keep-me\"}".utf8)
    try unsupported.write(to: root.appending(component: "profiles.json"))
    let repository = try JSONProfileRepository(directoryURL: root)

    let reset = try await repository.resetToEmpty()
    #expect(reset == .empty)
    #expect(try await repository.load() == .empty)
    let recoveryNames = try FileManager.default.contentsOfDirectory(atPath: root.path)
        .filter { $0.hasPrefix("profiles.recovery-before-reset-") }
    #expect(recoveryNames.count == 1)
    #expect(try Data(contentsOf: root.appending(component: recoveryNames[0])) == unsupported)
}

@Test("Files larger than 10 MiB are rejected before decoding")
func oversizedRepositoryFile() async throws {
    let root = temporaryRepositoryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let mainURL = root.appending(component: "profiles.json", directoryHint: .notDirectory)
    #expect(FileManager.default.createFile(atPath: mainURL.path, contents: nil))
    let handle = try FileHandle(forWritingTo: mainURL)
    try handle.truncate(atOffset: UInt64(JSONProfileRepository.maximumFileBytes + 1))
    try handle.close()
    let repository = try JSONProfileRepository(directoryURL: root)

    await #expect(throws: JSONProfileRepositoryError.fileTooLarge) {
        try await repository.load()
    }
}

private func createBaselineRepository(at root: URL) async throws {
    let repository = try JSONProfileRepository(directoryURL: root)
    _ = try await repository.load()
    _ = try await repository.save(makeRepositoryStore(revision: 0, name: "Baseline"), expectedRevision: 0)
}

private func temporaryRepositoryDirectory() -> URL {
    FileManager.default.temporaryDirectory.appending(
        component: "DeskModeRepositoryTests-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
}

private func makeRepositoryStore(revision: Int, name: String = "Work") -> ProfileStore {
    let date = Date(timeIntervalSince1970: 1_788_602_400)
    let profile = Profile(
        id: UUID(uuidString: "87D061FC-AB78-46E7-817B-6527ED51008A")!,
        name: name,
        createdAt: date,
        updatedAt: date,
        failurePolicy: .continue,
        shortcut: nil,
        actions: []
    )
    return ProfileStore(revision: revision, profiles: [profile])
}
