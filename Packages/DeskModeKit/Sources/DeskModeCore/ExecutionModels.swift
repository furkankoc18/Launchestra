import Foundation

public enum RunErrorCode: String, Error, Equatable, Sendable {
    case invalidProfile
    case applicationNotFound
    case folderUnresolved
    case accessDenied
    case invalidURL
    case launchRejected
    case actionTimedOut
    case runTimedOut
    case cancelled
    case busy
    case storageUnavailable
}

public enum PreparedAction: Equatable, Sendable {
    case application(URL)
    case folder(URL)
    case web(URL)
}

public struct DispatchCancellation: Sendable {
    private let handler: @Sendable () -> Void

    public init(_ handler: @escaping @Sendable () -> Void = {}) {
        self.handler = handler
    }

    public func cancel() {
        handler()
    }
}

public protocol ActionDispatching: Sendable {
    @MainActor
    func preflight(_ action: ProfileAction) async -> Result<PreparedAction, RunErrorCode>

    @MainActor
    func dispatch(
        _ action: PreparedAction,
        completion: @escaping @Sendable (Result<Void, RunErrorCode>) -> Void
    ) -> DispatchCancellation
}

public enum ActionSkipReason: String, Equatable, Sendable {
    case disabled
    case policyStopped
    case preflightAborted
}

public enum ActionRunStatus: Equatable, Sendable {
    case pending
    case running
    case accepted
    case failed(RunErrorCode)
    case timedOut
    case skipped(ActionSkipReason)
    case cancelled

    public var isTerminal: Bool {
        switch self {
        case .pending, .running: false
        default: true
        }
    }
}

public struct ActionRunResult: Equatable, Sendable {
    public let actionID: UUID
    public let sequence: Int
    public let status: ActionRunStatus

    public init(actionID: UUID, sequence: Int, status: ActionRunStatus) {
        self.actionID = actionID
        self.sequence = sequence
        self.status = status
    }
}

public enum RunTerminalStatus: String, Equatable, Sendable {
    case completed
    case partial
    case failed
    case cancelled
    case timedOut
}

public struct RunResult: Equatable, Sendable {
    public let runID: UUID
    public let profileID: UUID
    public let profileName: String
    public let status: RunTerminalStatus
    public let actions: [ActionRunResult]

    public init(
        runID: UUID,
        profileID: UUID,
        profileName: String,
        status: RunTerminalStatus,
        actions: [ActionRunResult]
    ) {
        self.runID = runID
        self.profileID = profileID
        self.profileName = profileName
        self.status = status
        self.actions = actions
    }
}

public enum RunEventKind: Equatable, Sendable {
    case runStarted
    case validationFinished
    case actionStarted
    case actionFinished(ActionRunResult)
    case runFinished(RunResult)
}

public struct RunEvent: Equatable, Sendable {
    public let runID: UUID
    public let actionID: UUID?
    public let sequence: Int
    public let kind: RunEventKind

    public init(runID: UUID, actionID: UUID?, sequence: Int, kind: RunEventKind) {
        self.runID = runID
        self.actionID = actionID
        self.sequence = sequence
        self.kind = kind
    }
}

public protocol RunnerClock: Sendable {
    func now() async -> Duration
    func sleep(for duration: Duration) async throws
}

public struct ContinuousRunnerClock: RunnerClock {
    private let clock = ContinuousClock()
    private let origin: ContinuousClock.Instant

    public init() {
        origin = clock.now
    }

    public func now() async -> Duration {
        origin.duration(to: clock.now)
    }

    public func sleep(for duration: Duration) async throws {
        try await clock.sleep(for: duration)
    }
}
