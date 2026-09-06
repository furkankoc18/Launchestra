import AppKit
import DeskModeCore
import Foundation
import KeyboardShortcuts
import SwiftUI

public typealias RecordedShortcut = KeyboardShortcuts.Shortcut

public enum ShortcutExperimentError: Error, Equatable, Sendable {
    case duplicateShortcut
    case systemShortcutConflict
    case persistenceFailed
}

public enum ShortcutInputEvent: Equatable, Sendable {
    case keyDown
    case keyUp
}

public protocol ShortcutAssignmentStore: Sendable {
    func save(_ assignments: [ShortcutAssignment]) async throws
}

public actor JSONShortcutExperimentStore: ShortcutAssignmentStore {
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func save(_ assignments: [ShortcutAssignment]) async throws {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(assignments)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw ShortcutExperimentError.persistenceFailed
        }
    }
}

@MainActor
public protocol ShortcutEventBackend: AnyObject {
    func validate(_ assignment: ShortcutAssignment) throws

    func listen(
        to assignment: ShortcutAssignment,
        onEvent: @escaping @MainActor @Sendable (ShortcutInputEvent) -> Void
    ) throws -> Task<Void, Never>
}

public extension ShortcutEventBackend {
    func validate(_ assignment: ShortcutAssignment) throws {}
}

@MainActor
public final class KeyboardShortcutsEventBackend: ShortcutEventBackend {
    public init() {}

    public func validate(_ assignment: ShortcutAssignment) throws {
        guard !assignment.keyboardShortcut.isTakenBySystem else {
            throw ShortcutExperimentError.systemShortcutConflict
        }
    }

    public func listen(
        to assignment: ShortcutAssignment,
        onEvent: @escaping @MainActor @Sendable (ShortcutInputEvent) -> Void
    ) throws -> Task<Void, Never> {
        let shortcut = assignment.keyboardShortcut

        return Task { @MainActor in
            for await event in KeyboardShortcuts.events(for: shortcut) {
                guard !Task.isCancelled else { break }
                switch event {
                case .keyDown:
                    onEvent(.keyDown)
                case .keyUp:
                    onEvent(.keyUp)
                }
            }
        }
    }
}

@MainActor
private final class ShortcutTriggerGate {
    let profileID: UUID
    let onTrigger: @MainActor @Sendable (UUID) -> Void
    var isActive = false

    init(profileID: UUID, onTrigger: @escaping @MainActor @Sendable (UUID) -> Void) {
        self.profileID = profileID
        self.onTrigger = onTrigger
    }

    func receive(_ event: ShortcutInputEvent) {
        guard isActive, event == .keyUp else { return }
        onTrigger(profileID)
    }
}

@MainActor
public final class PreparedShortcutRegistration {
    fileprivate let assignments: [ShortcutAssignment]
    fileprivate var listenerTasks: [UUID: Task<Void, Never>]
    fileprivate let gates: [ShortcutTriggerGate]
    fileprivate var isFinalized = false

    fileprivate init(
        assignments: [ShortcutAssignment],
        listenerTasks: [UUID: Task<Void, Never>],
        gates: [ShortcutTriggerGate]
    ) {
        self.assignments = assignments
        self.listenerTasks = listenerTasks
        self.gates = gates
    }

    public func discard() {
        guard !isFinalized else { return }
        for task in listenerTasks.values { task.cancel() }
        listenerTasks.removeAll()
        isFinalized = true
    }
}

@MainActor
public final class ShortcutExperimentRegistry {
    private let backend: ShortcutEventBackend
    private var listenerTasks: [UUID: Task<Void, Never>] = [:]

    public private(set) var assignments: [ShortcutAssignment] = []
    public var activeListenerCount: Int { listenerTasks.count }

    public init(backend: ShortcutEventBackend = KeyboardShortcutsEventBackend()) {
        self.backend = backend
    }

    deinit {
        for task in listenerTasks.values {
            task.cancel()
        }
    }

    public func validate(_ proposed: [ShortcutAssignment]) throws {
        do {
            try ShortcutAssignmentValidator.validate(proposed)
        } catch {
            throw ShortcutExperimentError.duplicateShortcut
        }
        for assignment in proposed {
            try backend.validate(assignment)
        }
    }

    public func replace(
        with proposed: [ShortcutAssignment],
        onTrigger: @escaping @MainActor @Sendable (UUID) -> Void
    ) throws {
        let prepared = try prepare(proposed, onTrigger: onTrigger)
        commit(prepared)
    }

    public func prepare(
        _ proposed: [ShortcutAssignment],
        onTrigger: @escaping @MainActor @Sendable (UUID) -> Void
    ) throws -> PreparedShortcutRegistration {
        try validate(proposed)

        var nextTasks: [UUID: Task<Void, Never>] = [:]
        var gates: [ShortcutTriggerGate] = []

        do {
            for assignment in proposed {
                let gate = ShortcutTriggerGate(profileID: assignment.profileID, onTrigger: onTrigger)
                gates.append(gate)
                nextTasks[assignment.profileID] = try backend.listen(to: assignment, onEvent: gate.receive)
            }
        } catch {
            for task in nextTasks.values {
                task.cancel()
            }
            throw error
        }

        return PreparedShortcutRegistration(
            assignments: proposed,
            listenerTasks: nextTasks,
            gates: gates
        )
    }

    public func commit(_ prepared: PreparedShortcutRegistration) {
        guard !prepared.isFinalized else { return }
        for task in listenerTasks.values {
            task.cancel()
        }
        for gate in prepared.gates { gate.isActive = true }
        listenerTasks = prepared.listenerTasks
        assignments = prepared.assignments
        prepared.isFinalized = true
    }

    public func removeAll() {
        for task in listenerTasks.values {
            task.cancel()
        }
        listenerTasks.removeAll()
        assignments.removeAll()
    }
}

@MainActor
public final class ShortcutExperimentCoordinator {
    private let store: ShortcutAssignmentStore
    private let registry: ShortcutExperimentRegistry

    public init(store: ShortcutAssignmentStore, registry: ShortcutExperimentRegistry) {
        self.store = store
        self.registry = registry
    }

    public func saveAndActivate(
        _ assignments: [ShortcutAssignment],
        onTrigger: @escaping @MainActor @Sendable (UUID) -> Void
    ) async throws {
        let prepared = try registry.prepare(assignments, onTrigger: onTrigger)
        do {
            try await store.save(assignments)
            registry.commit(prepared)
        } catch {
            prepared.discard()
            throw error
        }
    }
}

public typealias ProfileShortcutRegistry = ShortcutExperimentRegistry

public extension ShortcutAssignment {
    init(profileID: UUID, shortcut: KeyboardShortcuts.Shortcut) {
        self.init(
            profileID: profileID,
            carbonKeyCode: shortcut.carbonKeyCode,
            carbonModifiers: shortcut.carbonModifiers
        )
    }

    var keyboardShortcut: KeyboardShortcuts.Shortcut {
        .init(carbonKeyCode: carbonKeyCode, carbonModifiers: carbonModifiers)
    }
}

/// Compiles the package's custom-storage recorder API without introducing a
/// second UserDefaults-backed shortcut authority.
public struct ShortcutExperimentRecorder: View {
    @Binding private var shortcut: KeyboardShortcuts.Shortcut?

    public init(shortcut: Binding<KeyboardShortcuts.Shortcut?>) {
        _shortcut = shortcut
    }

    public var body: some View {
        KeyboardShortcuts.Recorder("Profile shortcut", shortcut: $shortcut)
    }
}
