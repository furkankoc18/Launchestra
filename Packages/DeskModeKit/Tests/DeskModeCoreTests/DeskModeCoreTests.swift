import Foundation
import Testing
@testable import DeskModeCore

@Test("The package records the macOS 14 baseline")
func minimumOperatingSystem() {
    #expect(DeskModeEnvironment.minimumMacOSMajorVersion == 14)
    #expect(DeskModeEnvironment.isSupportedOperatingSystem)
}

@Test("Shortcut assignments round-trip through JSON")
func shortcutAssignmentRoundTrip() throws {
    let assignment = ShortcutAssignment(
        profileID: UUID(uuidString: "D567A89A-5AF0-4D8D-AAC8-2E29D8B177E8")!,
        carbonKeyCode: 12,
        carbonModifiers: 768
    )

    let data = try JSONEncoder().encode(assignment)
    let decoded = try JSONDecoder().decode(ShortcutAssignment.self, from: data)

    #expect(decoded == assignment)
}

@Test("The same shortcut cannot belong to two profiles")
func duplicateShortcutValidation() {
    let firstID = UUID()
    let secondID = UUID()
    let assignments = [
        ShortcutAssignment(profileID: firstID, carbonKeyCode: 12, carbonModifiers: 768),
        ShortcutAssignment(profileID: secondID, carbonKeyCode: 12, carbonModifiers: 768)
    ]

    #expect(throws: ShortcutAssignmentValidationError.duplicateShortcut(
        firstProfileID: firstID,
        secondProfileID: secondID
    )) {
        try ShortcutAssignmentValidator.validate(assignments)
    }
}
