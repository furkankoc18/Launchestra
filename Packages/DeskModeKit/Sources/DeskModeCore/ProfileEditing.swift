import Foundation

public struct ProfileDraft: Equatable, Sendable {
    public let id: UUID
    public let original: Profile?
    public let createdAt: Date
    public var name: String
    public var failurePolicy: FailurePolicy
    public var shortcut: ShortcutBinding?
    public var actions: [ProfileAction]

    public init(profile: Profile) {
        id = profile.id
        original = profile
        createdAt = profile.createdAt
        name = profile.name
        failurePolicy = profile.failurePolicy
        shortcut = profile.shortcut
        actions = profile.actions
    }

    public init(id: UUID = UUID(), createdAt: Date, name: String = "") {
        self.id = id
        original = nil
        self.createdAt = createdAt
        self.name = name
        failurePolicy = .continue
        shortcut = nil
        actions = []
    }

    public var isDirty: Bool {
        guard let original else { return true }
        return name != original.name
            || failurePolicy != original.failurePolicy
            || shortcut != original.shortcut
            || actions != original.actions
    }
}

public enum ProfileDraftValidationError: Error, Equatable, Sendable {
    case profileLimitReached
    case actionLimitReached
    case nameRequired
    case nameTooLong
    case duplicateName
    case invalidActionLabel(UUID)
    case invalidApplication(UUID)
    case invalidFolder(UUID)
    case invalidURL(UUID)
    case invalidShortcut
    case duplicateShortcut
}

public enum ProfileDraftValidator {
    public static func validate(
        _ draft: ProfileDraft,
        in store: ProfileStore,
        now: Date
    ) throws -> Profile {
        if draft.original == nil, store.profiles.count >= ProfileStoreValidator.maximumProfiles {
            throw ProfileDraftValidationError.profileLimitReached
        }
        if draft.actions.count > ProfileStoreValidator.maximumActionsPerProfile {
            throw ProfileDraftValidationError.actionLimitReached
        }

        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw ProfileDraftValidationError.nameRequired }
        guard trimmedName.count <= ProfileStoreValidator.maximumProfileNameCharacters else {
            throw ProfileDraftValidationError.nameTooLong
        }

        let candidate = Profile(
            id: draft.id,
            name: trimmedName,
            createdAt: draft.createdAt,
            updatedAt: max(now, draft.createdAt),
            failurePolicy: draft.failurePolicy,
            shortcut: draft.shortcut,
            actions: draft.actions
        )
        var profiles = store.profiles
        if let index = profiles.firstIndex(where: { $0.id == draft.id }) {
            profiles[index] = candidate
        } else {
            profiles.append(candidate)
        }

        do {
            let normalized = try ProfileStoreValidator.normalizedAndValidated(
                ProfileStore(schemaVersion: store.schemaVersion, revision: store.revision, profiles: profiles)
            )
            return normalized.profiles.first(where: { $0.id == draft.id })!
        } catch let error as ProfileValidationError {
            throw map(error)
        }
    }

    public static func errors(_ draft: ProfileDraft, in store: ProfileStore, now: Date) -> [ProfileDraftValidationError] {
        do {
            _ = try validate(draft, in: store, now: now)
            return []
        } catch let error as ProfileDraftValidationError {
            return [error]
        } catch {
            return [.nameRequired]
        }
    }

    private static func map(_ error: ProfileValidationError) -> ProfileDraftValidationError {
        switch error {
        case .tooManyProfiles: .profileLimitReached
        case .tooManyActions: .actionLimitReached
        case .invalidProfileName: .nameRequired
        case .duplicateProfileName: .duplicateName
        case let .invalidActionLabel(id): .invalidActionLabel(id)
        case let .invalidApplicationReference(id): .invalidApplication(id)
        case let .invalidFolderReference(id): .invalidFolder(id)
        case let .invalidURL(id): .invalidURL(id)
        case .invalidShortcut: .invalidShortcut
        case .duplicateShortcut: .duplicateShortcut
        default: .nameRequired
        }
    }
}

public enum ProfileStoreEditor {
    public static func upserting(_ profile: Profile, in store: ProfileStore) -> ProfileStore {
        var profiles = store.profiles
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
        return ProfileStore(schemaVersion: store.schemaVersion, revision: store.revision, profiles: profiles)
    }

    public static func removing(profileID: UUID, from store: ProfileStore) -> ProfileStore {
        ProfileStore(
            schemaVersion: store.schemaVersion,
            revision: store.revision,
            profiles: store.profiles.filter { $0.id != profileID }
        )
    }

    public static func moving(profileID: UUID, by offset: Int, in store: ProfileStore) -> ProfileStore {
        guard
            let source = store.profiles.firstIndex(where: { $0.id == profileID }),
            store.profiles.indices.contains(source + offset)
        else { return store }
        var profiles = store.profiles
        profiles.swapAt(source, source + offset)
        return ProfileStore(schemaVersion: store.schemaVersion, revision: store.revision, profiles: profiles)
    }

    public static func duplicate(_ profile: Profile, in store: ProfileStore, now: Date) -> ProfileDraft {
        let name = uniqueCopyName(for: profile.name, in: store)
        let actions = profile.actions.map {
            ProfileAction(
                id: UUID(),
                label: $0.label,
                enabled: $0.enabled,
                timeoutSeconds: $0.timeoutSeconds,
                kind: $0.kind
            )
        }
        var draft = ProfileDraft(id: UUID(), createdAt: now, name: name)
        draft.failurePolicy = profile.failurePolicy
        draft.shortcut = nil
        draft.actions = actions
        return draft
    }

    private static func uniqueCopyName(for source: String, in store: ProfileStore) -> String {
        let existing = Set(store.profiles.map { comparisonKey($0.name) })
        for number in 1...ProfileStoreValidator.maximumProfiles + 1 {
            let suffix = number == 1 ? " Kopyası" : " Kopyası \(number)"
            let available = max(1, ProfileStoreValidator.maximumProfileNameCharacters - suffix.count)
            let base = String(source.prefix(available)).trimmingCharacters(in: .whitespacesAndNewlines)
            let candidate = base + suffix
            if !existing.contains(comparisonKey(candidate)) { return candidate }
        }
        return String(UUID().uuidString.prefix(ProfileStoreValidator.maximumProfileNameCharacters))
    }

    private static func comparisonKey(_ value: String) -> String {
        value.precomposedStringWithCanonicalMapping
            .folding(options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }
}

public enum ProfileActionEditor {
    public static func replacing(
        _ action: ProfileAction,
        label: String? = nil,
        enabled: Bool? = nil,
        kind: ActionKind? = nil
    ) -> ProfileAction {
        ProfileAction(
            id: action.id,
            label: label ?? action.label,
            enabled: enabled ?? action.enabled,
            timeoutSeconds: action.timeoutSeconds,
            kind: kind ?? action.kind
        )
    }

    public static func moving(actionID: UUID, by offset: Int, in actions: [ProfileAction]) -> [ProfileAction] {
        guard
            let source = actions.firstIndex(where: { $0.id == actionID }),
            actions.indices.contains(source + offset)
        else { return actions }
        var result = actions
        result.swapAt(source, source + offset)
        return result
    }
}
