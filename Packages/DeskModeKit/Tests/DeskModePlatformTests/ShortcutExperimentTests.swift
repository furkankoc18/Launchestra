import DeskModeCore
import Foundation
import Testing
@testable import DeskModePlatform

@MainActor
private final class FakeShortcutBackend: ShortcutEventBackend {
    private(set) var listenedAssignments: [ShortcutAssignment] = []
    private(set) var cancelledProfileIDs: [UUID] = []
    private var handlers: [UUID: @MainActor @Sendable (ShortcutInputEvent) -> Void] = [:]
    var failure: ShortcutExperimentError?
    var validationFailure: ShortcutExperimentError?

    func validate(_ assignment: ShortcutAssignment) throws {
        if let validationFailure { throw validationFailure }
    }

    func listen(
        to assignment: ShortcutAssignment,
        onEvent: @escaping @MainActor @Sendable (ShortcutInputEvent) -> Void
    ) throws -> Task<Void, Never> {
        if let failure { throw failure }
        listenedAssignments.append(assignment)
        handlers[assignment.profileID] = onEvent
        return Task { @MainActor [weak self] in
            defer { self?.cancelledProfileIDs.append(assignment.profileID) }
            do {
                try await Task.sleep(for: .seconds(30))
            } catch {}
        }
    }

    func emit(_ event: ShortcutInputEvent, for profileID: UUID) {
        handlers[profileID]?(event)
    }
}

private actor RecordingStore: ShortcutAssignmentStore {
    private(set) var saves: [[ShortcutAssignment]] = []
    let failure: Error?

    init(failure: Error? = nil) {
        self.failure = failure
    }

    func save(_ assignments: [ShortcutAssignment]) throws {
        if let failure { throw failure }
        saves.append(assignments)
    }
}

@Test("Rebinding and removal leave one registration authority")
@MainActor
func rebindAndRemove() async {
    let backend = FakeShortcutBackend()
    let registry = ShortcutExperimentRegistry(backend: backend)
    let profileID = UUID()
    let first = ShortcutAssignment(profileID: profileID, carbonKeyCode: 12, carbonModifiers: 256)
    let second = ShortcutAssignment(profileID: profileID, carbonKeyCode: 13, carbonModifiers: 256)

    #expect(throws: Never.self) { try registry.replace(with: [first]) { _ in } }
    #expect(registry.activeListenerCount == 1)
    #expect(throws: Never.self) { try registry.replace(with: [second]) { _ in } }
    #expect(registry.activeListenerCount == 1)
    registry.removeAll()
    #expect(registry.activeListenerCount == 0)

    await Task.yield()
    #expect(backend.listenedAssignments == [first, second])
}

@Test("A duplicate chord is rejected before registration")
@MainActor
func duplicateChord() {
    let backend = FakeShortcutBackend()
    let registry = ShortcutExperimentRegistry(backend: backend)
    let assignments = [
        ShortcutAssignment(profileID: UUID(), carbonKeyCode: 12, carbonModifiers: 256),
        ShortcutAssignment(profileID: UUID(), carbonKeyCode: 12, carbonModifiers: 256)
    ]

    #expect(throws: ShortcutExperimentError.duplicateShortcut) {
        try registry.replace(with: assignments) { _ in }
    }
    #expect(registry.activeListenerCount == 0)
}

@Test("A held shortcut fires once when its single key-up arrives")
@MainActor
func heldShortcutFiresOnce() {
    let backend = FakeShortcutBackend()
    let registry = ShortcutExperimentRegistry(backend: backend)
    let profileID = UUID()
    let assignment = ShortcutAssignment(profileID: profileID, carbonKeyCode: 40, carbonModifiers: 6912)
    var triggerCount = 0

    #expect(throws: Never.self) {
        try registry.replace(with: [assignment]) { _ in triggerCount += 1 }
    }
    backend.emit(.keyDown, for: profileID)
    backend.emit(.keyDown, for: profileID)
    backend.emit(.keyDown, for: profileID)
    #expect(triggerCount == 0)
    backend.emit(.keyUp, for: profileID)
    #expect(triggerCount == 1)
}

@Test("An OS registration conflict preserves the active assignment")
@MainActor
func registrationConflictIsTransactional() {
    let backend = FakeShortcutBackend()
    let registry = ShortcutExperimentRegistry(backend: backend)
    let first = ShortcutAssignment(profileID: UUID(), carbonKeyCode: 40, carbonModifiers: 6912)
    let replacement = ShortcutAssignment(profileID: UUID(), carbonKeyCode: 37, carbonModifiers: 6912)

    #expect(throws: Never.self) { try registry.replace(with: [first]) { _ in } }
    backend.failure = .systemShortcutConflict
    #expect(throws: ShortcutExperimentError.systemShortcutConflict) {
        try registry.replace(with: [replacement]) { _ in }
    }
    #expect(registry.assignments == [first])
    #expect(registry.activeListenerCount == 1)
}

@Test("A persistence failure never activates the proposed shortcut")
@MainActor
func saveFailureDoesNotActivate() async {
    let backend = FakeShortcutBackend()
    let registry = ShortcutExperimentRegistry(backend: backend)
    let store = RecordingStore(failure: ShortcutExperimentError.persistenceFailed)
    let coordinator = ShortcutExperimentCoordinator(store: store, registry: registry)
    let assignment = ShortcutAssignment(profileID: UUID(), carbonKeyCode: 12, carbonModifiers: 256)

    await #expect(throws: ShortcutExperimentError.persistenceFailed) {
        try await coordinator.saveAndActivate([assignment]) { _ in }
    }
    #expect(registry.activeListenerCount == 0)
    #expect(registry.assignments.isEmpty)
}

@Test("No assignment creates no global listener")
@MainActor
func noAssignment() {
    let backend = FakeShortcutBackend()
    let registry = ShortcutExperimentRegistry(backend: backend)

    #expect(throws: Never.self) { try registry.replace(with: []) { _ in } }
    #expect(registry.activeListenerCount == 0)
}

@Test("JSON shortcut storage writes a decodable assignment list")
func jsonShortcutStorage() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(component: "DeskModeShortcutStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    let fileURL = root.appending(component: "shortcut.json", directoryHint: .notDirectory)
    defer { try? FileManager.default.removeItem(at: root) }

    let assignments = [
        ShortcutAssignment(profileID: UUID(), carbonKeyCode: 12, carbonModifiers: 256)
    ]
    let store = JSONShortcutExperimentStore(fileURL: fileURL)
    try await store.save(assignments)

    let data = try Data(contentsOf: fileURL)
    #expect(try JSONDecoder().decode([ShortcutAssignment].self, from: data) == assignments)
}

@Test("Profile shortcut mapping preserves the canonical JSON binding")
@MainActor
func profileShortcutMapping() {
    let recorded = RecordedShortcut(.k, modifiers: [.command, .option, .control, .shift])
    let binding = ShortcutBinding(recordedShortcut: recorded)

    #expect(binding.keyCode == recorded.carbonKeyCode)
    #expect(binding.modifiers == [.control, .option, .shift, .command])
    #expect(binding.recordedShortcut == recorded)

    let profileID = UUID()
    let date = Date()
    let store = ProfileStore(
        revision: 3,
        profiles: [
            Profile(
                id: profileID,
                name: "Shortcut",
                createdAt: date,
                updatedAt: date,
                failurePolicy: .continue,
                shortcut: binding,
                actions: []
            )
        ]
    )
    #expect(ShortcutAssignment.profileAssignments(in: store) == [
        ShortcutAssignment(profileID: profileID, shortcut: recorded)
    ])
}

@Test("A profile save failure keeps the old listener and discards the proposed listener")
@MainActor
func profileSaveFailureKeepsOldListener() async {
    struct SaveFailure: Error {}

    let backend = FakeShortcutBackend()
    let registry = ProfileShortcutRegistry(backend: backend)
    let coordinator = ProfileShortcutCoordinator(registry: registry)
    let old = ShortcutAssignment(profileID: UUID(), carbonKeyCode: 12, carbonModifiers: 256)
    let proposed = ShortcutAssignment(profileID: UUID(), carbonKeyCode: 13, carbonModifiers: 256)
    var oldTriggerCount = 0
    var proposedTriggerCount = 0

    #expect(throws: Never.self) {
        try coordinator.activateLoaded([old]) { _ in oldTriggerCount += 1 }
    }
    await #expect(throws: SaveFailure.self) {
        try await coordinator.persistAndActivate(
            [proposed],
            onTrigger: { _ in proposedTriggerCount += 1 }
        ) {
            backend.emit(.keyUp, for: proposed.profileID)
            throw SaveFailure()
        }
    }

    #expect(coordinator.assignments == [old])
    #expect(coordinator.activeListenerCount == 1)
    backend.emit(.keyUp, for: old.profileID)
    backend.emit(.keyUp, for: proposed.profileID)
    #expect(oldTriggerCount == 1)
    #expect(proposedTriggerCount == 0)
}

@Test("A system conflict is visible before profile persistence and preserves active bindings")
@MainActor
func systemConflictPrecedesPersistence() async {
    let backend = FakeShortcutBackend()
    let registry = ProfileShortcutRegistry(backend: backend)
    let coordinator = ProfileShortcutCoordinator(registry: registry)
    let old = ShortcutAssignment(profileID: UUID(), carbonKeyCode: 12, carbonModifiers: 256)
    let proposed = ShortcutAssignment(profileID: UUID(), carbonKeyCode: 13, carbonModifiers: 256)
    var didPersist = false

    #expect(throws: Never.self) { try coordinator.activateLoaded([old]) { _ in } }
    backend.validationFailure = .systemShortcutConflict
    await #expect(throws: ShortcutExperimentError.systemShortcutConflict) {
        try await coordinator.persistAndActivate([proposed], onTrigger: { _ in }) {
            didPersist = true
        }
    }

    #expect(!didPersist)
    #expect(coordinator.assignments == [old])
}

@Test("Loaded profile shortcuts reactivate and trigger once on key up")
@MainActor
func loadedProfileShortcutReactivates() {
    let backend = FakeShortcutBackend()
    let coordinator = ProfileShortcutCoordinator(
        registry: ProfileShortcutRegistry(backend: backend)
    )
    let profileID = UUID()
    let assignment = ShortcutAssignment(profileID: profileID, carbonKeyCode: 40, carbonModifiers: 6912)
    var triggers: [UUID] = []

    #expect(throws: Never.self) {
        try coordinator.activateLoaded([assignment]) { triggers.append($0) }
    }
    backend.emit(.keyDown, for: profileID)
    backend.emit(.keyDown, for: profileID)
    backend.emit(.keyUp, for: profileID)

    #expect(triggers == [profileID])
}
