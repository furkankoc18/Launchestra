import CryptoKit
import Darwin
import DeskModeCore
import Foundation
import os.lock

public enum RepositoryWriteStage: String, CaseIterable, Equatable, Sendable {
    case afterValidation
    case beforeTemporaryWrite
    case afterTemporaryWrite
    case afterTemporaryVerification
    case beforeBackupWrite
    case afterBackupWrite
    case beforeCreateMain
    case beforeReplaceMain
}

public protocol RepositoryFaultInjecting: Sendable {
    func shouldFail(at stage: RepositoryWriteStage) -> Bool
}

public struct NoRepositoryFaults: RepositoryFaultInjecting {
    public init() {}

    public func shouldFail(at stage: RepositoryWriteStage) -> Bool {
        false
    }
}

public enum JSONProfileRepositoryError: Error, Equatable, Sendable {
    case writerLockUnavailable
    case fileTooLarge
    case invalidData
    case mainMissingBackupAvailable
    case revisionConflict(expected: Int, actual: Int)
    case externalModification
    case validation(ProfileValidationError)
    case injectedFailure(RepositoryWriteStage)
    case fileSystemFailure
    case recoveryNotRequired
    case backupUnavailable
}

public enum RepositoryRecoveryCause: Equatable, Sendable {
    case mainMissing
    case mainInvalid
    case unsupportedSchemaVersion(Int)
}

public struct RepositoryRecoveryState: Equatable, Sendable {
    public let cause: RepositoryRecoveryCause
    public let backupAvailable: Bool
    public let backupModifiedAt: Date?

    public init(cause: RepositoryRecoveryCause, backupAvailable: Bool, backupModifiedAt: Date?) {
        self.cause = cause
        self.backupAvailable = backupAvailable
        self.backupModifiedAt = backupModifiedAt
    }
}

public actor JSONProfileRepository: ProfileRepository {
    public static let maximumFileBytes = 10 * 1_024 * 1_024

    public nonisolated let directoryURL: URL
    public nonisolated let mainFileURL: URL
    public nonisolated let backupFileURL: URL

    private let lockFileURL: URL
    private let lockPathKey: String
    private let faultInjector: any RepositoryFaultInjecting
    private let lockDescriptor: Int32
    private var loadedStore: ProfileStore?
    private var loadedFingerprint: String?

    public init(
        directoryURL: URL,
        faultInjector: any RepositoryFaultInjecting = NoRepositoryFaults()
    ) throws {
        self.directoryURL = directoryURL
        mainFileURL = directoryURL.appending(component: "profiles.json", directoryHint: .notDirectory)
        backupFileURL = directoryURL.appending(component: "profiles.backup.json", directoryHint: .notDirectory)
        lockFileURL = directoryURL.appending(component: "profiles.lock", directoryHint: .notDirectory)
        lockPathKey = lockFileURL.standardizedFileURL.resolvingSymlinksInPath().path
        self.faultInjector = faultInjector

        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        } catch {
            throw JSONProfileRepositoryError.fileSystemFailure
        }

        guard Self.pathRegistry.acquire(lockPathKey) else {
            throw JSONProfileRepositoryError.writerLockUnavailable
        }

        let descriptor = Darwin.open(lockFileURL.path, O_CREAT | O_RDWR | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else {
            Self.pathRegistry.release(lockPathKey)
            throw JSONProfileRepositoryError.fileSystemFailure
        }

        var writeLock = Darwin.flock()
        writeLock.l_type = Int16(F_WRLCK)
        writeLock.l_whence = Int16(SEEK_SET)
        writeLock.l_start = 0
        writeLock.l_len = 0
        guard Darwin.fcntl(descriptor, F_SETLK, &writeLock) == 0 else {
            Darwin.close(descriptor)
            Self.pathRegistry.release(lockPathKey)
            throw JSONProfileRepositoryError.writerLockUnavailable
        }
        lockDescriptor = descriptor
    }

    deinit {
        var unlock = Darwin.flock()
        unlock.l_type = Int16(F_UNLCK)
        unlock.l_whence = Int16(SEEK_SET)
        unlock.l_start = 0
        unlock.l_len = 0
        _ = Darwin.fcntl(lockDescriptor, F_SETLK, &unlock)
        Darwin.close(lockDescriptor)
        Self.pathRegistry.release(lockPathKey)
    }

    public static func applicationSupport() throws -> JSONProfileRepository {
        guard let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw JSONProfileRepositoryError.fileSystemFailure
        }
        return try JSONProfileRepository(
            directoryURL: support.appending(component: "DeskMode", directoryHint: .isDirectory)
        )
    }

    public func load() throws -> ProfileStore {
        guard FileManager.default.fileExists(atPath: mainFileURL.path) else {
            if FileManager.default.fileExists(atPath: backupFileURL.path) {
                _ = try decodeAndValidate(readBoundedData(from: backupFileURL))
                throw JSONProfileRepositoryError.mainMissingBackupAvailable
            }
            let empty = ProfileStore.empty
            loadedStore = empty
            loadedFingerprint = nil
            return empty
        }

        let data = try readBoundedData(from: mainFileURL)
        let store = try decodeAndValidate(data)
        loadedStore = store
        loadedFingerprint = fingerprint(of: data)
        return store
    }

    public func save(_ next: ProfileStore, expectedRevision: Int) throws -> ProfileStore {
        let current: ProfileStore
        if let loadedStore {
            current = loadedStore
        } else {
            current = try load()
        }

        guard current.revision == expectedRevision else {
            throw JSONProfileRepositoryError.revisionConflict(
                expected: expectedRevision,
                actual: current.revision
            )
        }
        guard next.revision == expectedRevision else {
            throw JSONProfileRepositoryError.revisionConflict(
                expected: expectedRevision,
                actual: next.revision
            )
        }

        let existingMainData = try verifyDiskHasNotChanged(since: current)
        let normalized: ProfileStore
        do {
            normalized = try ProfileStoreValidator.normalizedAndValidated(next)
        } catch let error as ProfileValidationError {
            throw JSONProfileRepositoryError.validation(error)
        } catch {
            throw JSONProfileRepositoryError.invalidData
        }

        let committed = normalized.replacingRevision(with: expectedRevision + 1)
        try checkFault(at: .afterValidation)

        let encoded: Data
        do {
            encoded = try ProfileStoreCoding.makeEncoder().encode(committed)
        } catch {
            throw JSONProfileRepositoryError.invalidData
        }
        guard encoded.count <= Self.maximumFileBytes else {
            throw JSONProfileRepositoryError.fileTooLarge
        }

        let temporaryURL = directoryURL.appending(
            component: ".profiles-\(UUID().uuidString).tmp",
            directoryHint: .notDirectory
        )
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        try checkFault(at: .beforeTemporaryWrite)
        try writeAndSynchronize(encoded, to: temporaryURL)
        try checkFault(at: .afterTemporaryWrite)
        _ = try decodeAndValidate(readBoundedData(from: temporaryURL))
        try checkFault(at: .afterTemporaryVerification)

        if let existingMainData {
            try checkFault(at: .beforeBackupWrite)
            try writeBackupAtomically(existingMainData)
            try checkFault(at: .afterBackupWrite)
            try checkFault(at: .beforeReplaceMain)
            try replaceMain(with: temporaryURL)
        } else {
            try checkFault(at: .beforeCreateMain)
            try createMain(from: temporaryURL)
        }

        try synchronizeDirectory()
        loadedStore = committed
        loadedFingerprint = fingerprint(of: encoded)
        return committed
    }

    public func recoveryState() throws -> RepositoryRecoveryState? {
        let mainExists = FileManager.default.fileExists(atPath: mainFileURL.path)
        let backup = validBackupMetadata()

        guard mainExists else {
            guard FileManager.default.fileExists(atPath: backupFileURL.path) else { return nil }
            return RepositoryRecoveryState(
                cause: .mainMissing,
                backupAvailable: backup != nil,
                backupModifiedAt: backup?.modifiedAt
            )
        }

        let mainData: Data
        do {
            mainData = try readBoundedData(from: mainFileURL)
        } catch {
            return RepositoryRecoveryState(
                cause: .mainInvalid,
                backupAvailable: backup != nil,
                backupModifiedAt: backup?.modifiedAt
            )
        }

        if let version = schemaVersion(in: mainData), version != ProfileStore.currentSchemaVersion {
            return RepositoryRecoveryState(
                cause: .unsupportedSchemaVersion(version),
                backupAvailable: false,
                backupModifiedAt: nil
            )
        }

        do {
            _ = try decodeAndValidate(mainData)
            return nil
        } catch {
            return RepositoryRecoveryState(
                cause: .mainInvalid,
                backupAvailable: backup != nil,
                backupModifiedAt: backup?.modifiedAt
            )
        }
    }

    public func restoreBackup() throws -> ProfileStore {
        guard let recovery = try recoveryState() else {
            throw JSONProfileRepositoryError.recoveryNotRequired
        }
        guard recovery.backupAvailable else {
            throw JSONProfileRepositoryError.backupUnavailable
        }
        let data = try readBoundedData(from: backupFileURL)
        let store = try decodeAndValidate(data)
        if FileManager.default.fileExists(atPath: mainFileURL.path) {
            _ = try preserveRecoveryCopy(of: mainFileURL, label: "before-restore")
        }
        try installRecoveryData(data)
        loadedStore = store
        loadedFingerprint = fingerprint(of: data)
        return store
    }

    public func resetToEmpty() throws -> ProfileStore {
        guard try recoveryState() != nil else {
            throw JSONProfileRepositoryError.recoveryNotRequired
        }
        if FileManager.default.fileExists(atPath: mainFileURL.path) {
            _ = try preserveRecoveryCopy(of: mainFileURL, label: "before-reset")
        } else if FileManager.default.fileExists(atPath: backupFileURL.path) {
            _ = try preserveRecoveryCopy(of: backupFileURL, label: "backup-before-reset")
        }

        let empty = ProfileStore.empty
        let data: Data
        do {
            data = try ProfileStoreCoding.makeEncoder().encode(empty)
        } catch {
            throw JSONProfileRepositoryError.invalidData
        }
        try installRecoveryData(data)
        loadedStore = empty
        loadedFingerprint = fingerprint(of: data)
        return empty
    }

    private func verifyDiskHasNotChanged(since current: ProfileStore) throws -> Data? {
        let mainExists = FileManager.default.fileExists(atPath: mainFileURL.path)
        switch (loadedFingerprint, mainExists) {
        case (nil, false):
            return nil
        case (nil, true), (.some, false):
            throw JSONProfileRepositoryError.externalModification
        case let (.some(expectedFingerprint), true):
            let data: Data
            do {
                data = try readBoundedData(from: mainFileURL)
            } catch {
                throw JSONProfileRepositoryError.externalModification
            }
            guard fingerprint(of: data) == expectedFingerprint else {
                throw JSONProfileRepositoryError.externalModification
            }
            let diskStore: ProfileStore
            do {
                diskStore = try decodeAndValidate(data)
            } catch {
                throw JSONProfileRepositoryError.externalModification
            }
            guard diskStore.revision == current.revision else {
                throw JSONProfileRepositoryError.externalModification
            }
            return data
        }
    }

    private func decodeAndValidate(_ data: Data) throws -> ProfileStore {
        let store: ProfileStore
        do {
            store = try ProfileStoreCoding.makeDecoder().decode(ProfileStore.self, from: data)
        } catch {
            throw JSONProfileRepositoryError.invalidData
        }

        do {
            return try ProfileStoreValidator.normalizedAndValidated(store)
        } catch let error as ProfileValidationError {
            throw JSONProfileRepositoryError.validation(error)
        } catch {
            throw JSONProfileRepositoryError.invalidData
        }
    }

    private func validBackupMetadata() -> (store: ProfileStore, modifiedAt: Date?)? {
        guard FileManager.default.fileExists(atPath: backupFileURL.path),
              let data = try? readBoundedData(from: backupFileURL),
              let store = try? decodeAndValidate(data)
        else { return nil }
        let values = try? backupFileURL.resourceValues(forKeys: [.contentModificationDateKey])
        return (store, values?.contentModificationDate)
    }

    private func schemaVersion(in data: Data) -> Int? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return object["schemaVersion"] as? Int
    }

    private func preserveRecoveryCopy(of sourceURL: URL, label: String) throws -> URL {
        let recoveryURL = directoryURL.appending(
            component: "profiles.recovery-\(label)-\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString).json",
            directoryHint: .notDirectory
        )
        do {
            try FileManager.default.copyItem(at: sourceURL, to: recoveryURL)
            let handle = try FileHandle(forWritingTo: recoveryURL)
            try handle.synchronize()
            try handle.close()
            try synchronizeDirectory()
            return recoveryURL
        } catch {
            throw JSONProfileRepositoryError.fileSystemFailure
        }
    }

    private func installRecoveryData(_ data: Data) throws {
        _ = try decodeAndValidate(data)
        let temporaryURL = directoryURL.appending(
            component: ".profiles-recovery-\(UUID().uuidString).tmp",
            directoryHint: .notDirectory
        )
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        try writeAndSynchronize(data, to: temporaryURL)
        if FileManager.default.fileExists(atPath: mainFileURL.path) {
            try replaceMain(with: temporaryURL)
        } else {
            try createMain(from: temporaryURL)
        }
        try synchronizeDirectory()
    }

    private func readBoundedData(from url: URL) throws -> Data {
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            guard let size = values.fileSize, size <= Self.maximumFileBytes else {
                throw JSONProfileRepositoryError.fileTooLarge
            }
            return try Data(contentsOf: url, options: [.mappedIfSafe, .uncached])
        } catch let error as JSONProfileRepositoryError {
            throw error
        } catch {
            throw JSONProfileRepositoryError.fileSystemFailure
        }
    }

    private func writeBackupAtomically(_ verifiedMainData: Data) throws {
        _ = try decodeAndValidate(verifiedMainData)
        let temporaryBackupURL = directoryURL.appending(
            component: ".profiles-backup-\(UUID().uuidString).tmp",
            directoryHint: .notDirectory
        )
        defer { try? FileManager.default.removeItem(at: temporaryBackupURL) }
        try writeAndSynchronize(verifiedMainData, to: temporaryBackupURL)

        if FileManager.default.fileExists(atPath: backupFileURL.path) {
            guard Darwin.rename(temporaryBackupURL.path, backupFileURL.path) == 0 else {
                throw JSONProfileRepositoryError.fileSystemFailure
            }
        } else {
            do {
                try FileManager.default.moveItem(at: temporaryBackupURL, to: backupFileURL)
            } catch {
                throw JSONProfileRepositoryError.fileSystemFailure
            }
        }
        try synchronizeDirectory()
    }

    private func createMain(from temporaryURL: URL) throws {
        guard !FileManager.default.fileExists(atPath: mainFileURL.path) else {
            throw JSONProfileRepositoryError.externalModification
        }
        do {
            try FileManager.default.moveItem(at: temporaryURL, to: mainFileURL)
        } catch {
            throw JSONProfileRepositoryError.fileSystemFailure
        }
    }

    private func replaceMain(with temporaryURL: URL) throws {
        guard FileManager.default.fileExists(atPath: mainFileURL.path) else {
            throw JSONProfileRepositoryError.externalModification
        }
        guard Darwin.rename(temporaryURL.path, mainFileURL.path) == 0 else {
            throw JSONProfileRepositoryError.fileSystemFailure
        }
    }

    private func writeAndSynchronize(_ data: Data, to url: URL) throws {
        do {
            try data.write(to: url, options: .withoutOverwriting)
            let handle = try FileHandle(forWritingTo: url)
            try handle.synchronize()
            try handle.close()
        } catch {
            throw JSONProfileRepositoryError.fileSystemFailure
        }
    }

    private func synchronizeDirectory() throws {
        let descriptor = Darwin.open(directoryURL.path, O_RDONLY | O_CLOEXEC)
        guard descriptor >= 0 else {
            throw JSONProfileRepositoryError.fileSystemFailure
        }
        defer { Darwin.close(descriptor) }
        guard Darwin.fsync(descriptor) == 0 else {
            throw JSONProfileRepositoryError.fileSystemFailure
        }
    }

    private func fingerprint(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func checkFault(at stage: RepositoryWriteStage) throws {
        if faultInjector.shouldFail(at: stage) {
            throw JSONProfileRepositoryError.injectedFailure(stage)
        }
    }

    private static let pathRegistry = RepositoryPathRegistry()
}

private final class RepositoryPathRegistry: Sendable {
    private let paths = OSAllocatedUnfairLock(initialState: Set<String>())

    func acquire(_ path: String) -> Bool {
        paths.withLock { $0.insert(path).inserted }
    }

    func release(_ path: String) {
        _ = paths.withLock { $0.remove(path) }
    }
}
