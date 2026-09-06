import Foundation

public enum ProfileValidationError: Error, Equatable, Sendable {
    case unsupportedSchemaVersion(Int)
    case negativeRevision
    case tooManyProfiles
    case duplicateProfileID(UUID)
    case invalidProfileName(UUID)
    case duplicateProfileName(UUID, UUID)
    case invalidProfileDates(UUID)
    case tooManyActions(UUID)
    case duplicateActionID(profileID: UUID, actionID: UUID)
    case invalidActionLabel(UUID)
    case invalidTimeout(UUID)
    case invalidApplicationReference(UUID)
    case invalidFolderReference(UUID)
    case invalidURL(UUID)
    case invalidShortcut(UUID)
    case duplicateShortcut(UUID, UUID)
}

public enum ProfileStoreValidator {
    public static let maximumProfiles = 50
    public static let maximumActionsPerProfile = 30
    public static let maximumProfileNameCharacters = 60
    public static let maximumActionLabelCharacters = 80
    public static let maximumURLBytes = 4_096
    public static let maximumBookmarkBytes = 65_536

    public static func validate(_ store: ProfileStore) throws {
        _ = try normalizedAndValidated(store)
    }

    public static func normalizedAndValidated(_ store: ProfileStore) throws -> ProfileStore {
        guard store.schemaVersion == ProfileStore.currentSchemaVersion else {
            throw ProfileValidationError.unsupportedSchemaVersion(store.schemaVersion)
        }
        guard store.revision >= 0 else {
            throw ProfileValidationError.negativeRevision
        }
        guard store.profiles.count <= maximumProfiles else {
            throw ProfileValidationError.tooManyProfiles
        }

        var profileIDs = Set<UUID>()
        var names: [String: UUID] = [:]
        var shortcuts: [ShortcutBinding: UUID] = [:]
        var normalizedProfiles: [Profile] = []

        for profile in store.profiles {
            guard profileIDs.insert(profile.id).inserted else {
                throw ProfileValidationError.duplicateProfileID(profile.id)
            }

            let name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, name.count <= maximumProfileNameCharacters else {
                throw ProfileValidationError.invalidProfileName(profile.id)
            }
            let comparisonName = normalizedComparisonKey(name)
            if let otherID = names[comparisonName] {
                throw ProfileValidationError.duplicateProfileName(otherID, profile.id)
            }
            names[comparisonName] = profile.id

            guard profile.updatedAt >= profile.createdAt else {
                throw ProfileValidationError.invalidProfileDates(profile.id)
            }
            guard profile.actions.count <= maximumActionsPerProfile else {
                throw ProfileValidationError.tooManyActions(profile.id)
            }

            if let shortcut = profile.shortcut {
                try validate(shortcut: shortcut, profileID: profile.id)
                if let otherID = shortcuts[shortcut] {
                    throw ProfileValidationError.duplicateShortcut(otherID, profile.id)
                }
                shortcuts[shortcut] = profile.id
            }

            var actionIDs = Set<UUID>()
            var normalizedActions: [ProfileAction] = []
            for action in profile.actions {
                guard actionIDs.insert(action.id).inserted else {
                    throw ProfileValidationError.duplicateActionID(
                        profileID: profile.id,
                        actionID: action.id
                    )
                }
                guard action.timeoutSeconds == 10 else {
                    throw ProfileValidationError.invalidTimeout(action.id)
                }

                let label = action.label.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                if let label, label.isEmpty || label.count > maximumActionLabelCharacters {
                    throw ProfileValidationError.invalidActionLabel(action.id)
                }

                let kind = try normalizedAndValidated(kind: action.kind, actionID: action.id)
                normalizedActions.append(action.replacing(label: label, kind: kind))
            }

            normalizedProfiles.append(profile.replacing(name: name, actions: normalizedActions))
        }

        return ProfileStore(
            schemaVersion: store.schemaVersion,
            revision: store.revision,
            profiles: normalizedProfiles
        )
    }

    private static func normalizedAndValidated(
        kind: ActionKind,
        actionID: UUID
    ) throws -> ActionKind {
        switch kind {
        case let .openApplication(reference):
            let bundleIdentifier = reference.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayName = reference.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard
                !bundleIdentifier.isEmpty,
                bundleIdentifier.utf8.count <= 255,
                !displayName.isEmpty,
                displayName.count <= 255
            else {
                throw ProfileValidationError.invalidApplicationReference(actionID)
            }
            return .openApplication(
                ApplicationReference(bundleIdentifier: bundleIdentifier, displayName: displayName)
            )

        case let .openFolder(reference):
            let displayName = reference.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard
                let bookmark = Data(base64Encoded: reference.bookmarkBase64),
                !bookmark.isEmpty,
                bookmark.count <= maximumBookmarkBytes,
                !displayName.isEmpty,
                displayName.count <= 255,
                reference.lastKnownPath.utf8.count <= maximumURLBytes,
                NSString(string: reference.lastKnownPath).isAbsolutePath
            else {
                throw ProfileValidationError.invalidFolderReference(actionID)
            }
            return .openFolder(
                FolderReference(
                    bookmarkBase64: reference.bookmarkBase64,
                    lastKnownPath: reference.lastKnownPath,
                    displayName: displayName
                )
            )

        case let .openURL(value):
            guard WebURLPolicy.url(from: value) != nil else {
                throw ProfileValidationError.invalidURL(actionID)
            }
            return .openURL(value)
        }
    }

    private static func validate(shortcut: ShortcutBinding, profileID: UUID) throws {
        let uniqueModifiers = Set(shortcut.modifiers)
        let canonical = shortcut.modifiers.sorted { $0.canonicalRank < $1.canonicalRank }
        let hasPrimaryModifier = uniqueModifiers.contains(.command)
            || uniqueModifiers.contains(.control)
            || uniqueModifiers.contains(.option)

        guard
            isSupportedNormalKeyCode(shortcut.keyCode),
            uniqueModifiers.count == shortcut.modifiers.count,
            canonical == shortcut.modifiers,
            hasPrimaryModifier
        else {
            throw ProfileValidationError.invalidShortcut(profileID)
        }
    }

    private static func normalizedComparisonKey(_ value: String) -> String {
        value
            .precomposedStringWithCanonicalMapping
            .folding(options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func isSupportedNormalKeyCode(_ keyCode: Int) -> Bool {
        (0...53).contains(keyCode) || (64...71).contains(keyCode) || (75...126).contains(keyCode)
    }

}

public enum WebURLPolicy {
    public static func url(from value: String) -> URL? {
        guard
            value == value.trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty,
            value.utf8.count <= ProfileStoreValidator.maximumURLBytes,
            !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
            let components = URLComponents(string: value),
            let scheme = components.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            let host = components.host,
            !host.isEmpty,
            components.user == nil,
            components.password == nil,
            components.url != nil
        else {
            return nil
        }
        if let port = components.port, !(0...65_535).contains(port) {
            return nil
        }
        return components.url
    }
}

public protocol ProfileRepository: Sendable {
    func load() async throws -> ProfileStore
    func save(_ next: ProfileStore, expectedRevision: Int) async throws -> ProfileStore
}
