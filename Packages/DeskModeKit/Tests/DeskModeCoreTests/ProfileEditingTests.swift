import Foundation
import Testing
@testable import DeskModeCore

@Test("New, renamed, reordered and deleted profiles preserve store revision until repository commit")
func profileStoreEditing() throws {
    let date = Date(timeIntervalSince1970: 1_788_602_400)
    var store = ProfileStore(revision: 4, profiles: [])
    var draft = ProfileDraft(createdAt: date)
    draft.name = "  Çalışma  "
    let profile = try ProfileDraftValidator.validate(draft, in: store, now: date)
    #expect(profile.name == "Çalışma")
    store = ProfileStoreEditor.upserting(profile, in: store)
    #expect(store.revision == 4)

    let secondDraft = ProfileDraft(createdAt: date, name: "Odak")
    let second = try ProfileDraftValidator.validate(secondDraft, in: store, now: date)
    store = ProfileStoreEditor.upserting(second, in: store)
    #expect(ProfileStoreEditor.moving(profileID: second.id, by: -1, in: store).profiles.map(\.id) == [second.id, profile.id])
    #expect(ProfileStoreEditor.removing(profileID: profile.id, from: store).profiles.map(\.id) == [second.id])
}

@Test("Duplicate creates new profile and action IDs, a unique name and no shortcut")
func profileDuplicationIdentity() {
    let date = Date(timeIntervalSince1970: 1_788_602_400)
    let action = ProfileAction(id: UUID(), label: "Site", enabled: true, kind: .openURL("https://example.test"))
    let profile = Profile(
        id: UUID(), name: "Work", createdAt: date, updatedAt: date,
        failurePolicy: .stop,
        shortcut: ShortcutBinding(keyCode: 0, modifiers: [.command]),
        actions: [action]
    )
    let existingCopy = Profile(
        id: UUID(), name: "work kopyası", createdAt: date, updatedAt: date,
        failurePolicy: .continue, shortcut: nil, actions: []
    )
    let draft = ProfileStoreEditor.duplicate(profile, in: ProfileStore(revision: 2, profiles: [profile, existingCopy]), now: date)
    #expect(draft.id != profile.id)
    #expect(draft.actions[0].id != action.id)
    #expect(draft.name == "Work Kopyası 2")
    #expect(draft.shortcut == nil)
    #expect(draft.failurePolicy == .stop)
}

@Test("Draft validation reports duplicate name, invalid URL and capacity limits")
func profileDraftValidationErrors() throws {
    let date = Date(timeIntervalSince1970: 1_788_602_400)
    let existing = Profile(
        id: UUID(), name: "Çalışma", createdAt: date, updatedAt: date,
        failurePolicy: .continue,
        shortcut: ShortcutBinding(keyCode: 40, modifiers: [.control, .option, .shift, .command]),
        actions: []
    )
    let store = ProfileStore(revision: 1, profiles: [existing])
    let duplicate = ProfileDraft(createdAt: date, name: "çalışma")
    #expect(throws: ProfileDraftValidationError.duplicateName) {
        try ProfileDraftValidator.validate(duplicate, in: store, now: date)
    }

    var invalidURL = ProfileDraft(createdAt: date, name: "Web")
    let actionID = UUID()
    invalidURL.actions = [ProfileAction(id: actionID, label: nil, enabled: true, kind: .openURL("file:///tmp"))]
    #expect(throws: ProfileDraftValidationError.invalidURL(actionID)) {
        try ProfileDraftValidator.validate(invalidURL, in: store, now: date)
    }

    var tooManyActions = ProfileDraft(createdAt: date, name: "Limit")
    tooManyActions.actions = (0...ProfileStoreValidator.maximumActionsPerProfile).map {
        ProfileAction(id: UUID(), label: "\($0)", enabled: true, kind: .openURL("https://example.test"))
    }
    #expect(throws: ProfileDraftValidationError.actionLimitReached) {
        try ProfileDraftValidator.validate(tooManyActions, in: store, now: date)
    }

    var invalidShortcut = ProfileDraft(createdAt: date, name: "Geçersiz Kısayol")
    invalidShortcut.shortcut = ShortcutBinding(keyCode: 200, modifiers: [.command])
    #expect(throws: ProfileDraftValidationError.invalidShortcut) {
        try ProfileDraftValidator.validate(invalidShortcut, in: store, now: date)
    }

    var duplicateShortcut = ProfileDraft(createdAt: date, name: "Aynı Kısayol")
    duplicateShortcut.shortcut = existing.shortcut
    #expect(throws: ProfileDraftValidationError.duplicateShortcut) {
        try ProfileDraftValidator.validate(duplicateShortcut, in: store, now: date)
    }
}

@Test("Action editing keeps identity and supports keyboard-equivalent ordering")
func actionEditing() {
    let first = ProfileAction(id: UUID(), label: nil, enabled: true, kind: .openURL("https://one.test"))
    let second = ProfileAction(id: UUID(), label: nil, enabled: true, kind: .openURL("https://two.test"))
    let changed = ProfileActionEditor.replacing(first, label: "One", enabled: false)
    #expect(changed.id == first.id)
    #expect(changed.label == "One")
    #expect(!changed.enabled)
    #expect(ProfileActionEditor.moving(actionID: second.id, by: -1, in: [first, second]).map(\.id) == [second.id, first.id])
}
