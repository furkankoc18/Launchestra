import DeskModeCore
import Foundation
import OSLog

public enum DiagnosticEvent: String, Equatable, Sendable {
    case profilesLoaded
    case storageUnavailable
    case recoveryCompleted
    case runStarted
    case actionFinished
    case runFinished
}

public struct DiagnosticRecord: Equatable, Sendable {
    public let event: DiagnosticEvent
    public let runID: UUID?
    public let actionID: UUID?
    public let errorCode: RunErrorCode?
    public let durationMilliseconds: Int?

    public init(
        event: DiagnosticEvent,
        runID: UUID? = nil,
        actionID: UUID? = nil,
        errorCode: RunErrorCode? = nil,
        durationMilliseconds: Int? = nil
    ) {
        self.event = event
        self.runID = runID
        self.actionID = actionID
        self.errorCode = errorCode
        self.durationMilliseconds = durationMilliseconds.map { max(0, $0) }
    }

    public var privacySafeFields: [String: String] {
        var fields = ["event": event.rawValue]
        if let runID { fields["run_id"] = runID.uuidString }
        if let actionID { fields["action_id"] = actionID.uuidString }
        if let errorCode { fields["error_code"] = Self.code(errorCode) }
        if let durationMilliseconds { fields["duration_ms"] = String(durationMilliseconds) }
        return fields
    }

    private static func code(_ value: RunErrorCode) -> String {
        switch value {
        case .applicationNotFound: "application_not_found"
        case .folderUnresolved: "folder_unresolved"
        case .accessDenied: "access_denied"
        case .invalidURL: "invalid_url"
        case .launchRejected: "launch_rejected"
        case .actionTimedOut: "action_timed_out"
        case .runTimedOut: "run_timed_out"
        case .cancelled: "cancelled"
        case .busy: "busy"
        case .storageUnavailable: "storage_unavailable"
        case .invalidProfile: "invalid_profile"
        }
    }
}

public struct DiagnosticsRecorder: Sendable {
    private let logger: Logger

    public init(subsystem: String = "io.github.furkankoc18.Launchestra") {
        logger = Logger(subsystem: subsystem, category: "lifecycle")
    }

    public func record(_ record: DiagnosticRecord) {
        let fields = record.privacySafeFields
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        logger.log("\(fields, privacy: .public)")
    }
}
