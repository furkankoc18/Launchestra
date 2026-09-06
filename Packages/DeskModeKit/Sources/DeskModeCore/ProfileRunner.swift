import Foundation

private actor RunCancellationSignal {
    private var cancelled = false
    private var callbacks: [UUID: @Sendable () -> Void] = [:]

    func register(_ callback: @escaping @Sendable () -> Void) -> UUID? {
        guard !cancelled else {
            callback()
            return nil
        }
        let id = UUID()
        callbacks[id] = callback
        return id
    }

    func unregister(_ id: UUID?) {
        guard let id else { return }
        callbacks[id] = nil
    }

    func cancel() {
        guard !cancelled else { return }
        cancelled = true
        let callbacks = callbacks.values
        self.callbacks.removeAll()
        for callback in callbacks { callback() }
    }

    func isCancelled() -> Bool { cancelled }
}

private enum WaitOutcome<Value: Sendable>: Sendable {
    case value(Value)
    case timeout
    case cancelled
}

private actor RunEventEmitter {
    private let runID: UUID
    private let handler: @Sendable (RunEvent) async -> Void
    private var sequence = 0

    init(runID: UUID, handler: @escaping @Sendable (RunEvent) async -> Void) {
        self.runID = runID
        self.handler = handler
    }

    func emit(_ kind: RunEventKind, actionID: UUID? = nil) async {
        sequence += 1
        await handler(RunEvent(runID: runID, actionID: actionID, sequence: sequence, kind: kind))
    }
}

public actor ProfileRunner {
    public static let totalTimeout: Duration = .seconds(60)

    private let clock: any RunnerClock
    private var activeRunID: UUID?
    private var cancellationSignal: RunCancellationSignal?

    public init(clock: any RunnerClock = ContinuousRunnerClock()) {
        self.clock = clock
    }

    public var isRunning: Bool { activeRunID != nil }

    public func cancelCurrentRun() async {
        await cancellationSignal?.cancel()
    }

    public nonisolated func eventStream(
        for profile: Profile,
        dispatcher: any ActionDispatching
    ) -> AsyncThrowingStream<RunEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    _ = try await self.run(profile: profile, dispatcher: dispatcher) {
                        continuation.yield($0)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func run(
        profile snapshot: Profile,
        dispatcher: any ActionDispatching,
        onEvent: @escaping @Sendable (RunEvent) async -> Void = { _ in }
    ) async throws -> RunResult {
        guard activeRunID == nil else { throw RunErrorCode.busy }

        let runID = UUID()
        let signal = RunCancellationSignal()
        activeRunID = runID
        cancellationSignal = signal
        defer {
            if activeRunID == runID {
                activeRunID = nil
                cancellationSignal = nil
            }
        }

        let events = RunEventEmitter(runID: runID, handler: onEvent)

        await events.emit(.runStarted)
        let start = await clock.now()
        var results = snapshot.actions.enumerated().map {
            ActionRunResult(actionID: $0.element.id, sequence: $0.offset, status: .pending)
        }

        guard isStructurallyValid(snapshot) else {
            await events.emit(.validationFinished)
            for index in results.indices {
                let action = snapshot.actions[index]
                let status: ActionRunStatus = action.enabled
                    ? .failed(.invalidProfile)
                    : .skipped(.disabled)
                results[index] = ActionRunResult(actionID: action.id, sequence: index, status: status)
                await events.emit(.actionFinished(results[index]), actionID: action.id)
            }
            let result = RunResult(
                runID: runID,
                profileID: snapshot.id,
                profileName: snapshot.name,
                status: .failed,
                actions: results
            )
            await events.emit(.runFinished(result))
            return result
        }

        var prepared: [UUID: PreparedAction] = [:]
        var preflightErrors: [UUID: RunErrorCode] = [:]
        var totalTimedOut = false
        var userCancelled = false

        for action in snapshot.actions where action.enabled {
            let remaining = await remainingBudget(since: start)
            if remaining <= .zero {
                totalTimedOut = true
                break
            }
            let outcome = await waitForAsync(
                timeout: remaining,
                signal: signal
            ) {
                await dispatcher.preflight(action)
            }
            switch outcome {
            case let .value(.success(value)): prepared[action.id] = value
            case let .value(.failure(error)): preflightErrors[action.id] = error
            case .timeout: totalTimedOut = true
            case .cancelled: userCancelled = true
            }
            if totalTimedOut || userCancelled { break }
        }

        await events.emit(.validationFinished)

        if userCancelled || totalTimedOut {
            for index in results.indices {
                let action = snapshot.actions[index]
                let status: ActionRunStatus = action.enabled
                    ? (userCancelled ? .cancelled : .timedOut)
                    : .skipped(.disabled)
                results[index] = ActionRunResult(actionID: action.id, sequence: index, status: status)
                await events.emit(.actionFinished(results[index]), actionID: action.id)
            }
            return await finish(
                runID: runID,
                snapshot: snapshot,
                results: results,
                status: userCancelled ? .cancelled : .timedOut,
                events: events
            )
        }

        if snapshot.failurePolicy == .stop, !preflightErrors.isEmpty {
            for index in results.indices {
                let action = snapshot.actions[index]
                let status: ActionRunStatus
                if !action.enabled { status = .skipped(.disabled) }
                else if let error = preflightErrors[action.id] { status = .failed(error) }
                else { status = .skipped(.preflightAborted) }
                results[index] = ActionRunResult(actionID: action.id, sequence: index, status: status)
                await events.emit(.actionFinished(results[index]), actionID: action.id)
            }
            return await finish(
                runID: runID,
                snapshot: snapshot,
                results: results,
                status: .failed,
                events: events
            )
        }

        var policyStopped = false
        for index in snapshot.actions.indices {
            let action = snapshot.actions[index]
            let terminal: ActionRunStatus

            if !action.enabled {
                terminal = .skipped(.disabled)
            } else if policyStopped {
                terminal = .skipped(.policyStopped)
            } else if let error = preflightErrors[action.id] {
                terminal = .failed(error)
            } else if await signal.isCancelled() {
                userCancelled = true
                terminal = .cancelled
            } else {
                let remaining = await remainingBudget(since: start)
                if remaining <= .zero {
                    totalTimedOut = true
                    terminal = .timedOut
                } else if let ready = prepared[action.id] {
                    await events.emit(.actionStarted, actionID: action.id)
                    let actionBudget = Duration.seconds(action.timeoutSeconds)
                    let timeout = min(actionBudget, remaining)
                    let timeoutIsTotal = remaining <= actionBudget
                    switch await waitForDispatch(
                        ready,
                        dispatcher: dispatcher,
                        timeout: timeout,
                        signal: signal
                    ) {
                    case .value(.success): terminal = .accepted
                    case let .value(.failure(error)): terminal = .failed(error)
                    case .timeout:
                        if timeoutIsTotal {
                            totalTimedOut = true
                            terminal = .timedOut
                        } else {
                            terminal = .timedOut
                        }
                    case .cancelled:
                        userCancelled = true
                        terminal = .cancelled
                    }
                } else {
                    terminal = .failed(.launchRejected)
                }
            }

            results[index] = ActionRunResult(actionID: action.id, sequence: index, status: terminal)
            await events.emit(.actionFinished(results[index]), actionID: action.id)

            if userCancelled || totalTimedOut {
                for remainingIndex in results.indices where remainingIndex > index {
                    let pending = snapshot.actions[remainingIndex]
                    let status: ActionRunStatus = pending.enabled
                        ? (userCancelled ? .cancelled : .timedOut)
                        : .skipped(.disabled)
                    results[remainingIndex] = ActionRunResult(
                        actionID: pending.id,
                        sequence: remainingIndex,
                        status: status
                    )
                    await events.emit(.actionFinished(results[remainingIndex]), actionID: pending.id)
                }
                break
            }

            if snapshot.failurePolicy == .stop, isFailure(terminal) {
                policyStopped = true
            }
        }

        let status = terminalStatus(
            results: results,
            userCancelled: userCancelled,
            totalTimedOut: totalTimedOut
        )
        return await finish(
            runID: runID,
            snapshot: snapshot,
            results: results,
            status: status,
            events: events
        )
    }

    private func isStructurallyValid(_ profile: Profile) -> Bool {
        guard profile.actions.contains(where: \.enabled) else { return false }
        let store = ProfileStore(revision: 0, profiles: [profile])
        return (try? ProfileStoreValidator.validate(store)) != nil
    }

    private func remainingBudget(since start: Duration) async -> Duration {
        let elapsed = await clock.now() - start
        return max(.zero, Self.totalTimeout - elapsed)
    }

    private func waitForAsync<Value: Sendable>(
        timeout: Duration,
        signal: RunCancellationSignal,
        operation: @escaping @Sendable () async -> Value
    ) async -> WaitOutcome<Value> {
        let (stream, continuation) = AsyncStream<WaitOutcome<Value>>.makeStream()
        let operationTask = Task { continuation.yield(.value(await operation())) }
        let timeoutTask = Task {
            do {
                try await clock.sleep(for: timeout)
                continuation.yield(.timeout)
            } catch {}
        }
        let registration = await signal.register { continuation.yield(.cancelled) }
        let outcome = await stream.first(where: { _ in true }) ?? .cancelled
        continuation.finish()
        operationTask.cancel()
        timeoutTask.cancel()
        await signal.unregister(registration)
        return outcome
    }

    private func waitForDispatch(
        _ action: PreparedAction,
        dispatcher: any ActionDispatching,
        timeout: Duration,
        signal: RunCancellationSignal
    ) async -> WaitOutcome<Result<Void, RunErrorCode>> {
        let (stream, continuation) = AsyncStream<WaitOutcome<Result<Void, RunErrorCode>>>.makeStream()
        let token = await dispatcher.dispatch(action) { result in
            continuation.yield(.value(result))
        }
        let timeoutTask = Task {
            do {
                try await clock.sleep(for: timeout)
                continuation.yield(.timeout)
            } catch {}
        }
        let registration = await signal.register { continuation.yield(.cancelled) }
        let outcome = await stream.first(where: { _ in true }) ?? .cancelled
        continuation.finish()
        timeoutTask.cancel()
        token.cancel()
        await signal.unregister(registration)
        return outcome
    }

    private func isFailure(_ status: ActionRunStatus) -> Bool {
        switch status {
        case .failed, .timedOut: true
        default: false
        }
    }

    private func terminalStatus(
        results: [ActionRunResult],
        userCancelled: Bool,
        totalTimedOut: Bool
    ) -> RunTerminalStatus {
        if userCancelled { return .cancelled }
        if totalTimedOut { return .timedOut }
        let accepted = results.contains { $0.status == .accepted }
        let failed = results.contains { isFailure($0.status) }
        if accepted && !failed { return .completed }
        if accepted && failed { return .partial }
        return .failed
    }

    private func finish(
        runID: UUID,
        snapshot: Profile,
        results: [ActionRunResult],
        status: RunTerminalStatus,
        events: RunEventEmitter
    ) async -> RunResult {
        let result = RunResult(
            runID: runID,
            profileID: snapshot.id,
            profileName: snapshot.name,
            status: status,
            actions: results
        )
        await events.emit(.runFinished(result))
        return result
    }
}
