import DeskModeCore
import DeskModePlatform
import Foundation
import Testing

@Test("Diagnostic records expose only typed privacy-safe fields")
func diagnosticRecordPrivacyBoundary() throws {
    let runID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
    let actionID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    let record = DiagnosticRecord(
        event: .actionFinished,
        runID: runID,
        actionID: actionID,
        errorCode: .launchRejected,
        durationMilliseconds: -20
    )
    let serialized = record.privacySafeFields
        .sorted { $0.key < $1.key }
        .map { "\($0.key)=\($0.value)" }
        .joined(separator: " ")

    #expect(serialized.contains("event=actionFinished"))
    #expect(serialized.contains("error_code=launch_rejected"))
    #expect(serialized.contains("duration_ms=0"))
    #expect(!serialized.contains("secret-token"))
    #expect(!serialized.contains("/Users/private"))
    #expect(Set(record.privacySafeFields.keys) == ["event", "run_id", "action_id", "error_code", "duration_ms"])
}

@Test("Storage diagnostics cannot accept raw NSError or user content")
func diagnosticStorageRecordHasClosedShape() {
    let record = DiagnosticRecord(event: .storageUnavailable)
    #expect(record.privacySafeFields == ["event": "storageUnavailable"])
}
