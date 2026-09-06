import AppKit
import Carbon.HIToolbox
import DeskModeCore
import KeyboardShortcuts
import SwiftUI

public extension ShortcutBinding {
    init(recordedShortcut: RecordedShortcut) {
        var modifiers: [ShortcutModifier] = []
        let flags = recordedShortcut.modifiers
        if flags.contains(.control) { modifiers.append(.control) }
        if flags.contains(.option) { modifiers.append(.option) }
        if flags.contains(.shift) { modifiers.append(.shift) }
        if flags.contains(.command) { modifiers.append(.command) }
        self.init(keyCode: recordedShortcut.carbonKeyCode, modifiers: modifiers)
    }

    var recordedShortcut: RecordedShortcut {
        let carbonModifiers = modifiers.reduce(into: 0) { value, modifier in
            switch modifier {
            case .control: value |= Int(controlKey)
            case .option: value |= Int(optionKey)
            case .shift: value |= Int(shiftKey)
            case .command: value |= Int(cmdKey)
            }
        }
        return RecordedShortcut(carbonKeyCode: keyCode, carbonModifiers: carbonModifiers)
    }
}

public extension ShortcutAssignment {
    init(profileID: UUID, binding: ShortcutBinding) {
        let shortcut = binding.recordedShortcut
        self.init(
            profileID: profileID,
            carbonKeyCode: shortcut.carbonKeyCode,
            carbonModifiers: shortcut.carbonModifiers
        )
    }

    static func profileAssignments(in store: ProfileStore) -> [ShortcutAssignment] {
        store.profiles.compactMap { profile in
            profile.shortcut.map { ShortcutAssignment(profileID: profile.id, binding: $0) }
        }
    }
}

@MainActor
public final class ProfileShortcutCoordinator {
    private let registry: ProfileShortcutRegistry

    public var assignments: [ShortcutAssignment] { registry.assignments }
    public var activeListenerCount: Int { registry.activeListenerCount }

    public init(registry: ProfileShortcutRegistry = ProfileShortcutRegistry()) {
        self.registry = registry
    }

    public func activateLoaded(
        _ assignments: [ShortcutAssignment],
        onTrigger: @escaping @MainActor @Sendable (UUID) -> Void
    ) throws {
        try registry.replace(with: assignments, onTrigger: onTrigger)
    }

    public func persistAndActivate<Value>(
        _ assignments: [ShortcutAssignment],
        onTrigger: @escaping @MainActor @Sendable (UUID) -> Void,
        persist: () async throws -> Value
    ) async throws -> Value {
        let prepared = try registry.prepare(assignments, onTrigger: onTrigger)
        do {
            let value = try await persist()
            registry.commit(prepared)
            return value
        } catch {
            prepared.discard()
            throw error
        }
    }

    public func removeAll() {
        registry.removeAll()
    }
}

public struct ProfileShortcutRecorder: View {
    @Binding private var shortcut: ShortcutBinding?

    public init(shortcut: Binding<ShortcutBinding?>) {
        _shortcut = shortcut
    }

    public var body: some View {
        KeyboardShortcuts.Recorder(
            "Kısayol",
            shortcut: Binding(
                get: { shortcut?.recordedShortcut },
                set: { shortcut = $0.map(ShortcutBinding.init(recordedShortcut:)) }
            )
        )
    }
}
