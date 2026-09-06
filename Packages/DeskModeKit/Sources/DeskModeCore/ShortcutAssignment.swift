import Foundation

/// A persistence-friendly representation of one profile shortcut.
///
/// The numeric values are Carbon key codes and modifiers. They identify a
/// physical key position; they do not promise that the displayed letter stays
/// identical when the active keyboard layout changes.
public struct ShortcutAssignment: Codable, Equatable, Hashable, Sendable {
    public let profileID: UUID
    public let carbonKeyCode: Int
    public let carbonModifiers: Int

    public init(profileID: UUID, carbonKeyCode: Int, carbonModifiers: Int) {
        self.profileID = profileID
        self.carbonKeyCode = carbonKeyCode
        self.carbonModifiers = carbonModifiers
    }
}

public enum ShortcutAssignmentValidationError: Error, Equatable, Sendable {
    case duplicateShortcut(firstProfileID: UUID, secondProfileID: UUID)
}

public enum ShortcutAssignmentValidator {
    public static func validate(_ assignments: [ShortcutAssignment]) throws {
        var owners: [ShortcutChord: UUID] = [:]

        for assignment in assignments {
            let chord = ShortcutChord(
                carbonKeyCode: assignment.carbonKeyCode,
                carbonModifiers: assignment.carbonModifiers
            )

            if let existingOwner = owners[chord], existingOwner != assignment.profileID {
                throw ShortcutAssignmentValidationError.duplicateShortcut(
                    firstProfileID: existingOwner,
                    secondProfileID: assignment.profileID
                )
            }

            owners[chord] = assignment.profileID
        }
    }
}

private struct ShortcutChord: Hashable {
    let carbonKeyCode: Int
    let carbonModifiers: Int
}
