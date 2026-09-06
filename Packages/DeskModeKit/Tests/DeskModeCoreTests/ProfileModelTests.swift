import Foundation
import Testing
@testable import DeskModeCore

@Test("DATA-MODEL JSON example decodes, validates and round-trips")
func documentedJSONExample() throws {
    var projectRoot = URL(fileURLWithPath: #filePath)
    for _ in 0..<5 { projectRoot.deleteLastPathComponent() }
    let document = try String(
        contentsOf: projectRoot.appending(path: "docs/06-DATA-MODEL.md"),
        encoding: .utf8
    )
    let json = try #require(
        document.components(separatedBy: "```json\n").dropFirst().first?
            .components(separatedBy: "\n```").first
    )
    let decoded = try ProfileStoreCoding.makeDecoder().decode(ProfileStore.self, from: Data(json.utf8))

    try ProfileStoreValidator.validate(decoded)
    #expect(decoded.schemaVersion == 1)
    #expect(decoded.revision == 0)
    #expect(decoded.profiles.first?.name == "Çalışma")
    #expect(decoded.profiles.first?.actions.count == 2)

    let encoded = try ProfileStoreCoding.makeEncoder().encode(decoded)
    let roundTrip = try ProfileStoreCoding.makeDecoder().decode(ProfileStore.self, from: encoded)
    #expect(roundTrip == decoded)
}

@Test("Unknown fields and action types are rejected during decoding")
func strictDecoding() throws {
    let store = makeStore()
    let original = try ProfileStoreCoding.makeEncoder().encode(store)
    var object = try #require(JSONSerialization.jsonObject(with: original) as? [String: Any])
    object["futureField"] = true
    let unknownTopLevel = try JSONSerialization.data(withJSONObject: object)

    #expect(throws: DecodingError.self) {
        try ProfileStoreCoding.makeDecoder().decode(ProfileStore.self, from: unknownTopLevel)
    }

    let urlStore = makeStore(actions: [makeURLAction("https://example.com")])
    let urlData = try ProfileStoreCoding.makeEncoder().encode(urlStore)
    var urlObject = try #require(JSONSerialization.jsonObject(with: urlData) as? [String: Any])
    var profiles = try #require(urlObject["profiles"] as? [[String: Any]])
    var actions = try #require(profiles[0]["actions"] as? [[String: Any]])
    var kind = try #require(actions[0]["kind"] as? [String: Any])
    kind["type"] = "runShell"
    actions[0]["kind"] = kind
    profiles[0]["actions"] = actions
    urlObject["profiles"] = profiles
    let unknownType = try JSONSerialization.data(withJSONObject: urlObject)

    #expect(throws: DecodingError.self) {
        try ProfileStoreCoding.makeDecoder().decode(ProfileStore.self, from: unknownType)
    }

    kind = try #require(actions[0]["kind"] as? [String: Any])
    var payload = try #require(kind["payload"] as? [String: Any])
    payload["futurePayloadField"] = "value"
    kind["payload"] = payload
    actions[0]["kind"] = kind
    profiles[0]["actions"] = actions
    urlObject["profiles"] = profiles
    let unknownPayload = try JSONSerialization.data(withJSONObject: urlObject)

    #expect(throws: DecodingError.self) {
        try ProfileStoreCoding.makeDecoder().decode(ProfileStore.self, from: unknownPayload)
    }

    var missingFieldObject = try #require(JSONSerialization.jsonObject(with: original) as? [String: Any])
    var missingFieldProfiles = try #require(missingFieldObject["profiles"] as? [[String: Any]])
    missingFieldProfiles[0].removeValue(forKey: "shortcut")
    missingFieldObject["profiles"] = missingFieldProfiles
    let missingField = try JSONSerialization.data(withJSONObject: missingFieldObject)
    #expect(throws: DecodingError.self) {
        try ProfileStoreCoding.makeDecoder().decode(ProfileStore.self, from: missingField)
    }
}

@Test("Timestamp encoding is UTC without fractions and decoding rejects other shapes")
func strictTimestampCoding() throws {
    let encoded = try ProfileStoreCoding.makeEncoder().encode(makeStore())
    let text = try #require(String(data: encoded, encoding: .utf8))
    #expect(text.contains("2026-09-05T10:00:00Z"))

    let fractional = text.replacingOccurrences(of: "2026-09-05T10:00:00Z", with: "2026-09-05T10:00:00.000Z")
    #expect(throws: DecodingError.self) {
        try ProfileStoreCoding.makeDecoder().decode(ProfileStore.self, from: Data(fractional.utf8))
    }
}

@Test("Unsupported schema versions and invalid revisions are rejected")
func versionAndRevisionValidation() {
    #expect(throws: ProfileValidationError.unsupportedSchemaVersion(999)) {
        try ProfileStoreValidator.validate(ProfileStore(schemaVersion: 999, revision: 0, profiles: []))
    }
    #expect(throws: ProfileValidationError.negativeRevision) {
        try ProfileStoreValidator.validate(ProfileStore(revision: -1, profiles: []))
    }
}

@Test("Profile and action capacity limits enforce 50 by 30")
func capacityLimits() throws {
    let fifty = (0..<50).map { makeProfile(name: "Profile \($0)") }
    try ProfileStoreValidator.validate(ProfileStore(revision: 0, profiles: fifty))

    let fiftyOne = (0..<51).map { makeProfile(name: "Profile \($0)") }
    #expect(throws: ProfileValidationError.tooManyProfiles) {
        try ProfileStoreValidator.validate(ProfileStore(revision: 0, profiles: fiftyOne))
    }

    let thirty = (0..<30).map { makeURLAction("https://example.com/\($0)") }
    try ProfileStoreValidator.validate(makeStore(actions: thirty))

    let profileID = UUID()
    let thirtyOne = (0..<31).map { makeURLAction("https://example.com/\($0)") }
    let oversized = ProfileStore(
        revision: 0,
        profiles: [makeProfile(id: profileID, name: "Work", actions: thirtyOne)]
    )
    #expect(throws: ProfileValidationError.tooManyActions(profileID)) {
        try ProfileStoreValidator.validate(oversized)
    }
}

@Test("Names are trimmed and compared with fixed Unicode normalization")
func unicodeNameValidation() throws {
    let profile = makeProfile(name: "  Çalışma 🚀  ", actions: [
        ProfileAction(id: UUID(), label: "  Başlat  ", enabled: true, kind: .openURL("https://example.com"))
    ])
    let normalized = try ProfileStoreValidator.normalizedAndValidated(
        ProfileStore(revision: 0, profiles: [profile])
    )
    #expect(normalized.profiles[0].name == "Çalışma 🚀")
    #expect(normalized.profiles[0].actions[0].label == "Başlat")

    let first = makeProfile(name: "Cafe\u{301}")
    let second = makeProfile(name: "CAFÉ")
    #expect(throws: ProfileValidationError.duplicateProfileName(first.id, second.id)) {
        try ProfileStoreValidator.validate(ProfileStore(revision: 0, profiles: [first, second]))
    }

    try ProfileStoreValidator.validate(ProfileStore(revision: 0, profiles: [
        makeProfile(name: "I"),
        makeProfile(name: "ı")
    ]))

    try ProfileStoreValidator.validate(ProfileStore(revision: 0, profiles: [
        makeProfile(name: String(repeating: "a", count: 60))
    ]))
    let tooLong = makeProfile(name: String(repeating: "a", count: 61))
    #expect(throws: ProfileValidationError.invalidProfileName(tooLong.id)) {
        try ProfileStoreValidator.validate(ProfileStore(revision: 0, profiles: [tooLong]))
    }
}

@Test("URL validation accepts weblocalhost and IP hosts and rejects unsafe forms", arguments: [
    "http://localhost:3000",
    "http://127.0.0.1:8080/path",
    "http://[::1]:8080/path",
    "https://example.com/path?query=1"
])
func acceptedURLs(url: String) throws {
    try ProfileStoreValidator.validate(makeStore(actions: [makeURLAction(url)]))
}

@Test("URL validation rejects schemes, credentials, whitespace, controls and malformed ports", arguments: [
    "javascript:alert(1)",
    "file:///tmp/example",
    "https://user:password@example.com",
    " https://example.com",
    "https://example.com\nnext",
    "http://localhost:not-a-port",
    "http://localhost:99999"
])
func rejectedURLs(url: String) {
    let action = makeURLAction(url)
    #expect(throws: ProfileValidationError.invalidURL(action.id)) {
        try ProfileStoreValidator.validate(makeStore(actions: [action]))
    }
}

@Test("References, timeout and shortcut shape are validated")
func referenceAndShortcutValidation() throws {
    let badApp = ProfileAction(
        id: UUID(),
        label: nil,
        enabled: true,
        kind: .openApplication(ApplicationReference(bundleIdentifier: "", displayName: "Safari"))
    )
    #expect(throws: ProfileValidationError.invalidApplicationReference(badApp.id)) {
        try ProfileStoreValidator.validate(makeStore(actions: [badApp]))
    }

    let badFolder = ProfileAction(
        id: UUID(),
        label: nil,
        enabled: true,
        kind: .openFolder(
            FolderReference(bookmarkBase64: "not-base64", lastKnownPath: "relative", displayName: "Folder")
        )
    )
    #expect(throws: ProfileValidationError.invalidFolderReference(badFolder.id)) {
        try ProfileStoreValidator.validate(makeStore(actions: [badFolder]))
    }

    let badTimeout = ProfileAction(
        id: UUID(),
        label: nil,
        enabled: true,
        timeoutSeconds: 9,
        kind: .openURL("https://example.com")
    )
    #expect(throws: ProfileValidationError.invalidTimeout(badTimeout.id)) {
        try ProfileStoreValidator.validate(makeStore(actions: [badTimeout]))
    }

    let profileID = UUID()
    let shiftOnly = makeProfile(
        id: profileID,
        name: "Work",
        shortcut: ShortcutBinding(keyCode: 40, modifiers: [.shift])
    )
    #expect(throws: ProfileValidationError.invalidShortcut(profileID)) {
        try ProfileStoreValidator.validate(ProfileStore(revision: 0, profiles: [shiftOnly]))
    }

    let mediaKeyProfileID = UUID()
    let mediaKey = makeProfile(
        id: mediaKeyProfileID,
        name: "Media key",
        shortcut: ShortcutBinding(keyCode: 72, modifiers: [.command])
    )
    #expect(throws: ProfileValidationError.invalidShortcut(mediaKeyProfileID)) {
        try ProfileStoreValidator.validate(ProfileStore(revision: 0, profiles: [mediaKey]))
    }

    let valid = makeProfile(
        name: "Valid",
        shortcut: ShortcutBinding(keyCode: 40, modifiers: [.control, .option, .shift, .command])
    )
    try ProfileStoreValidator.validate(ProfileStore(revision: 0, profiles: [valid]))

    let validFolder = ProfileAction(
        id: UUID(),
        label: String(repeating: "e", count: 80),
        enabled: true,
        kind: .openFolder(
            FolderReference(
                bookmarkBase64: Data(repeating: 1, count: 65_536).base64EncodedString(),
                lastKnownPath: "/tmp/DeskMode",
                displayName: "DeskMode"
            )
        )
    )
    try ProfileStoreValidator.validate(makeStore(actions: [validFolder]))

    let oversizedBookmark = ProfileAction(
        id: UUID(),
        label: nil,
        enabled: true,
        kind: .openFolder(
            FolderReference(
                bookmarkBase64: Data(repeating: 1, count: 65_537).base64EncodedString(),
                lastKnownPath: "/tmp/DeskMode",
                displayName: "DeskMode"
            )
        )
    )
    #expect(throws: ProfileValidationError.invalidFolderReference(oversizedBookmark.id)) {
        try ProfileStoreValidator.validate(makeStore(actions: [oversizedBookmark]))
    }

    let oversizedLabel = ProfileAction(
        id: UUID(),
        label: String(repeating: "e", count: 81),
        enabled: true,
        kind: .openURL("https://example.com")
    )
    #expect(throws: ProfileValidationError.invalidActionLabel(oversizedLabel.id)) {
        try ProfileStoreValidator.validate(makeStore(actions: [oversizedLabel]))
    }
}

@Test("All action discriminators round-trip without synthesized enum encoding")
func actionKindRoundTrip() throws {
    let actions = [
        ProfileAction(
            id: UUID(),
            label: "App",
            enabled: true,
            kind: .openApplication(
                ApplicationReference(bundleIdentifier: "com.apple.Safari", displayName: "Safari")
            )
        ),
        ProfileAction(
            id: UUID(),
            label: "Folder",
            enabled: true,
            kind: .openFolder(
                FolderReference(
                    bookmarkBase64: Data([1, 2, 3]).base64EncodedString(),
                    lastKnownPath: "/tmp/Test",
                    displayName: "Test"
                )
            )
        ),
        makeURLAction("http://localhost:3000")
    ]
    let store = makeStore(actions: actions)
    let encoded = try ProfileStoreCoding.makeEncoder().encode(store)
    let text = try #require(String(data: encoded, encoding: .utf8))
    #expect(text.contains("\"type\" : \"openApplication\""))
    #expect(text.contains("\"type\" : \"openFolder\""))
    #expect(text.contains("\"type\" : \"openURL\""))
    #expect(try ProfileStoreCoding.makeDecoder().decode(ProfileStore.self, from: encoded) == store)
}

@Test("Profile IDs, action IDs and shortcut chords are unique in their scopes")
func identifierAndShortcutUniqueness() {
    let duplicateProfileID = UUID()
    #expect(throws: ProfileValidationError.duplicateProfileID(duplicateProfileID)) {
        try ProfileStoreValidator.validate(ProfileStore(revision: 0, profiles: [
            makeProfile(id: duplicateProfileID, name: "First"),
            makeProfile(id: duplicateProfileID, name: "Second")
        ]))
    }

    let profileID = UUID()
    let actionID = UUID()
    let duplicateActions = [
        ProfileAction(id: actionID, label: nil, enabled: true, kind: .openURL("https://example.com/1")),
        ProfileAction(id: actionID, label: nil, enabled: true, kind: .openURL("https://example.com/2"))
    ]
    #expect(throws: ProfileValidationError.duplicateActionID(profileID: profileID, actionID: actionID)) {
        try ProfileStoreValidator.validate(ProfileStore(revision: 0, profiles: [
            makeProfile(id: profileID, name: "Actions", actions: duplicateActions)
        ]))
    }

    let first = makeProfile(
        name: "First shortcut",
        shortcut: ShortcutBinding(keyCode: 40, modifiers: [.control, .command])
    )
    let second = makeProfile(
        name: "Second shortcut",
        shortcut: ShortcutBinding(keyCode: 40, modifiers: [.control, .command])
    )
    #expect(throws: ProfileValidationError.duplicateShortcut(first.id, second.id)) {
        try ProfileStoreValidator.validate(ProfileStore(revision: 0, profiles: [first, second]))
    }
}

private func makeStore(actions: [ProfileAction] = []) -> ProfileStore {
    ProfileStore(revision: 0, profiles: [makeProfile(name: "Work", actions: actions)])
}

private func makeProfile(
    id: UUID = UUID(),
    name: String,
    shortcut: ShortcutBinding? = nil,
    actions: [ProfileAction] = []
) -> Profile {
    let date = Date(timeIntervalSince1970: 1_788_602_400)
    return Profile(
        id: id,
        name: name,
        createdAt: date,
        updatedAt: date,
        failurePolicy: .continue,
        shortcut: shortcut,
        actions: actions
    )
}

private func makeURLAction(_ url: String) -> ProfileAction {
    ProfileAction(id: UUID(), label: nil, enabled: true, kind: .openURL(url))
}
