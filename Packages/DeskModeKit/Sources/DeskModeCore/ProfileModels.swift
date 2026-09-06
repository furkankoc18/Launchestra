import Foundation

public struct ProfileStore: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let revision: Int
    public let profiles: [Profile]

    public init(schemaVersion: Int = currentSchemaVersion, revision: Int, profiles: [Profile]) {
        self.schemaVersion = schemaVersion
        self.revision = revision
        self.profiles = profiles
    }

    public static var empty: ProfileStore {
        ProfileStore(revision: 0, profiles: [])
    }

    public func replacingRevision(with revision: Int) -> ProfileStore {
        ProfileStore(schemaVersion: schemaVersion, revision: revision, profiles: profiles)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case revision
        case profiles
    }

    public init(from decoder: Decoder) throws {
        try decoder.rejectUnknownKeys(allowing: CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        revision = try container.decode(Int.self, forKey: .revision)
        profiles = try container.decode([Profile].self, forKey: .profiles)
    }
}

public struct Profile: Codable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let createdAt: Date
    public let updatedAt: Date
    public let failurePolicy: FailurePolicy
    public let shortcut: ShortcutBinding?
    public let actions: [ProfileAction]

    public init(
        id: UUID,
        name: String,
        createdAt: Date,
        updatedAt: Date,
        failurePolicy: FailurePolicy,
        shortcut: ShortcutBinding?,
        actions: [ProfileAction]
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.failurePolicy = failurePolicy
        self.shortcut = shortcut
        self.actions = actions
    }

    func replacing(name: String, actions: [ProfileAction]) -> Profile {
        Profile(
            id: id,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            failurePolicy: failurePolicy,
            shortcut: shortcut,
            actions: actions
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case name
        case createdAt
        case updatedAt
        case failurePolicy
        case shortcut
        case actions
    }

    public init(from decoder: Decoder) throws {
        try decoder.rejectUnknownKeys(allowing: CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        failurePolicy = try container.decode(FailurePolicy.self, forKey: .failurePolicy)
        guard container.contains(.shortcut) else {
            throw DecodingError.keyNotFound(
                CodingKeys.shortcut,
                .init(codingPath: decoder.codingPath, debugDescription: "Missing shortcut field.")
            )
        }
        shortcut = try container.decodeIfPresent(ShortcutBinding.self, forKey: .shortcut)
        actions = try container.decode([ProfileAction].self, forKey: .actions)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(failurePolicy, forKey: .failurePolicy)
        if let shortcut {
            try container.encode(shortcut, forKey: .shortcut)
        } else {
            try container.encodeNil(forKey: .shortcut)
        }
        try container.encode(actions, forKey: .actions)
    }
}

public enum FailurePolicy: String, Codable, Equatable, Sendable {
    case `continue`
    case stop
}

public struct ProfileAction: Codable, Equatable, Sendable {
    public let id: UUID
    public let label: String?
    public let enabled: Bool
    public let timeoutSeconds: Int
    public let kind: ActionKind

    public init(
        id: UUID,
        label: String?,
        enabled: Bool,
        timeoutSeconds: Int = 10,
        kind: ActionKind
    ) {
        self.id = id
        self.label = label
        self.enabled = enabled
        self.timeoutSeconds = timeoutSeconds
        self.kind = kind
    }

    func replacing(label: String?, kind: ActionKind) -> ProfileAction {
        ProfileAction(
            id: id,
            label: label,
            enabled: enabled,
            timeoutSeconds: timeoutSeconds,
            kind: kind
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case label
        case enabled
        case timeoutSeconds
        case kind
    }

    public init(from decoder: Decoder) throws {
        try decoder.rejectUnknownKeys(allowing: CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        guard container.contains(.label) else {
            throw DecodingError.keyNotFound(
                CodingKeys.label,
                .init(codingPath: decoder.codingPath, debugDescription: "Missing label field.")
            )
        }
        label = try container.decodeIfPresent(String.self, forKey: .label)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        timeoutSeconds = try container.decode(Int.self, forKey: .timeoutSeconds)
        kind = try container.decode(ActionKind.self, forKey: .kind)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        if let label {
            try container.encode(label, forKey: .label)
        } else {
            try container.encodeNil(forKey: .label)
        }
        try container.encode(enabled, forKey: .enabled)
        try container.encode(timeoutSeconds, forKey: .timeoutSeconds)
        try container.encode(kind, forKey: .kind)
    }
}

public enum ActionKind: Equatable, Sendable {
    case openApplication(ApplicationReference)
    case openFolder(FolderReference)
    case openURL(String)
}

extension ActionKind: Codable {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case type
        case payload
    }

    private enum Kind: String, Codable {
        case openApplication
        case openFolder
        case openURL
    }

    private struct URLPayload: Codable, Equatable, Sendable {
        let url: String

        private enum CodingKeys: String, CodingKey, CaseIterable {
            case url
        }

        init(url: String) {
            self.url = url
        }

        init(from decoder: Decoder) throws {
            try decoder.rejectUnknownKeys(allowing: CodingKeys.self)
            let container = try decoder.container(keyedBy: CodingKeys.self)
            url = try container.decode(String.self, forKey: .url)
        }
    }

    public init(from decoder: Decoder) throws {
        try decoder.rejectUnknownKeys(allowing: CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(Kind.self, forKey: .type)

        switch type {
        case .openApplication:
            self = .openApplication(try container.decode(ApplicationReference.self, forKey: .payload))
        case .openFolder:
            self = .openFolder(try container.decode(FolderReference.self, forKey: .payload))
        case .openURL:
            self = .openURL(try container.decode(URLPayload.self, forKey: .payload).url)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .openApplication(reference):
            try container.encode(Kind.openApplication, forKey: .type)
            try container.encode(reference, forKey: .payload)
        case let .openFolder(reference):
            try container.encode(Kind.openFolder, forKey: .type)
            try container.encode(reference, forKey: .payload)
        case let .openURL(url):
            try container.encode(Kind.openURL, forKey: .type)
            try container.encode(URLPayload(url: url), forKey: .payload)
        }
    }
}

public struct ApplicationReference: Codable, Equatable, Sendable {
    public let bundleIdentifier: String
    public let displayName: String

    public init(bundleIdentifier: String, displayName: String) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case bundleIdentifier
        case displayName
    }

    public init(from decoder: Decoder) throws {
        try decoder.rejectUnknownKeys(allowing: CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
        displayName = try container.decode(String.self, forKey: .displayName)
    }
}

public struct FolderReference: Codable, Equatable, Sendable {
    public let bookmarkBase64: String
    public let lastKnownPath: String
    public let displayName: String

    public init(bookmarkBase64: String, lastKnownPath: String, displayName: String) {
        self.bookmarkBase64 = bookmarkBase64
        self.lastKnownPath = lastKnownPath
        self.displayName = displayName
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case bookmarkBase64
        case lastKnownPath
        case displayName
    }

    public init(from decoder: Decoder) throws {
        try decoder.rejectUnknownKeys(allowing: CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bookmarkBase64 = try container.decode(String.self, forKey: .bookmarkBase64)
        lastKnownPath = try container.decode(String.self, forKey: .lastKnownPath)
        displayName = try container.decode(String.self, forKey: .displayName)
    }
}

public struct ShortcutBinding: Codable, Equatable, Hashable, Sendable {
    public let keyCode: Int
    public let modifiers: [ShortcutModifier]

    public init(keyCode: Int, modifiers: [ShortcutModifier]) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case keyCode
        case modifiers
    }

    public init(from decoder: Decoder) throws {
        try decoder.rejectUnknownKeys(allowing: CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keyCode = try container.decode(Int.self, forKey: .keyCode)
        modifiers = try container.decode([ShortcutModifier].self, forKey: .modifiers)
    }
}

public enum ShortcutModifier: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case control
    case option
    case shift
    case command

    var canonicalRank: Int {
        switch self {
        case .control: 0
        case .option: 1
        case .shift: 2
        case .command: 3
        }
    }
}

private struct AnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

private extension Decoder {
    func rejectUnknownKeys<Key: CodingKey & CaseIterable>(allowing keyType: Key.Type) throws {
        let allowed = Set(Key.allCases.map(\.stringValue))
        let container = try container(keyedBy: AnyCodingKey.self)
        let unknown = container.allKeys.map(\.stringValue).filter { !allowed.contains($0) }.sorted()
        guard unknown.isEmpty else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: codingPath, debugDescription: "Unknown keys: \(unknown.joined(separator: ", "))")
            )
        }
    }
}
