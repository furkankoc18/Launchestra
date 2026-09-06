import Foundation
import Testing
@testable import DeskModeCore

private struct PatientClock: RunnerClock {
    func now() async -> Duration { .zero }
    func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: .seconds(3_600))
    }
}

private struct ImmediateClock: RunnerClock {
    func now() async -> Duration { .zero }
    func sleep(for duration: Duration) async throws {}
}

private struct ActionTimeoutClock: RunnerClock {
    func now() async -> Duration { .zero }
    func sleep(for duration: Duration) async throws {
        if duration > .seconds(10) {
            try await Task.sleep(for: .seconds(3_600))
        }
    }
}

@MainActor
private final class FakeActionDispatcher: ActionDispatching {
    enum Behavior {
        case accepted
        case failed(RunErrorCode)
        case held
        case doubleCallback
    }

    var preflight: [UUID: Result<PreparedAction, RunErrorCode>] = [:]
    var behaviors: [Behavior] = []
    var dispatched: [URL] = []
    var heldCompletions: [@Sendable (Result<Void, RunErrorCode>) -> Void] = []
    var holdPreflight = false
    var preflightContinuations: [CheckedContinuation<Result<PreparedAction, RunErrorCode>, Never>] = []

    func preflight(_ action: ProfileAction) async -> Result<PreparedAction, RunErrorCode> {
        if holdPreflight {
            return await withCheckedContinuation { preflightContinuations.append($0) }
        }
        return preflight[action.id] ?? .success(.web(URL(string: "https://example.test/\(action.id)")!))
    }

    func dispatch(
        _ action: PreparedAction,
        completion: @escaping @Sendable (Result<Void, RunErrorCode>) -> Void
    ) -> DispatchCancellation {
        if case let .web(url) = action { dispatched.append(url) }
        let behavior = behaviors.isEmpty ? .accepted : behaviors.removeFirst()
        switch behavior {
        case .accepted: completion(.success(()))
        case let .failed(error): completion(.failure(error))
        case .held: heldCompletions.append(completion)
        case .doubleCallback:
            completion(.success(()))
            completion(.failure(.launchRejected))
        }
        return DispatchCancellation()
    }
}

private actor EventRecorder {
    var events: [RunEvent] = []
    func append(_ event: RunEvent) { events.append(event) }
}

@Test("Continue policy dispatches later actions after a runtime error")
func runnerContinueRuntimeFailure() async throws {
    let dispatcher = FakeActionDispatcher()
    await MainActor.run { dispatcher.behaviors = [.accepted, .failed(.launchRejected), .accepted] }
    let runner = ProfileRunner(clock: PatientClock())
    let profile = makeRunProfile(policy: .continue, count: 3)
    let result = try await runner.run(profile: profile, dispatcher: dispatcher)

    #expect(result.status == .partial)
    #expect(result.actions.map(\.status) == [.accepted, .failed(.launchRejected), .accepted])
    #expect(await MainActor.run { dispatcher.dispatched.count } == 3)
}

@Test("Stop policy aborts every dispatch when any preflight fails")
func runnerStopPreflightFailure() async throws {
    let dispatcher = FakeActionDispatcher()
    let profile = makeRunProfile(policy: .stop, count: 3)
    await MainActor.run { dispatcher.preflight[profile.actions[1].id] = .failure(.applicationNotFound) }
    let result = try await ProfileRunner(clock: PatientClock()).run(profile: profile, dispatcher: dispatcher)

    #expect(result.status == .failed)
    #expect(result.actions.map(\.status) == [
        .skipped(.preflightAborted), .failed(.applicationNotFound), .skipped(.preflightAborted)
    ])
    #expect(await MainActor.run { dispatcher.dispatched.isEmpty })
}

@Test("Stop policy skips remaining actions after a runtime error")
func runnerStopRuntimeFailure() async throws {
    let dispatcher = FakeActionDispatcher()
    await MainActor.run { dispatcher.behaviors = [.accepted, .failed(.launchRejected)] }
    let result = try await ProfileRunner(clock: PatientClock()).run(
        profile: makeRunProfile(policy: .stop, count: 3),
        dispatcher: dispatcher
    )

    #expect(result.status == .partial)
    #expect(result.actions.map(\.status) == [
        .accepted, .failed(.launchRejected), .skipped(.policyStopped)
    ])
}

@Test("Disabled actions are skipped and every terminal event is emitted once")
func runnerDisabledAndEvents() async throws {
    let dispatcher = FakeActionDispatcher()
    var profile = makeRunProfile(policy: .continue, count: 2)
    let disabled = ProfileAction(
        id: profile.actions[0].id,
        label: nil,
        enabled: false,
        kind: profile.actions[0].kind
    )
    profile = Profile(
        id: profile.id,
        name: profile.name,
        createdAt: profile.createdAt,
        updatedAt: profile.updatedAt,
        failurePolicy: profile.failurePolicy,
        shortcut: nil,
        actions: [disabled, profile.actions[1]]
    )
    let recorder = EventRecorder()
    let result = try await ProfileRunner(clock: PatientClock()).run(
        profile: profile,
        dispatcher: dispatcher
    ) { await recorder.append($0) }
    let events = await recorder.events

    #expect(result.status == .completed)
    #expect(result.actions.map(\.status) == [.skipped(.disabled), .accepted])
    #expect(events.filter { if case .actionFinished = $0.kind { true } else { false } }.count == 2)
    #expect(events.filter { if case .runFinished = $0.kind { true } else { false } }.count == 1)
    #expect(events.map(\.sequence) == Array(1...events.count))
}

@Test("Only one run acquires the application-wide busy lock")
func runnerBusyLock() async throws {
    let dispatcher = FakeActionDispatcher()
    await MainActor.run { dispatcher.behaviors = [.held] }
    let runner = ProfileRunner(clock: PatientClock())
    let profile = makeRunProfile(policy: .continue, count: 1)
    let first = Task { try await runner.run(profile: profile, dispatcher: dispatcher) }

    while await MainActor.run(body: { dispatcher.heldCompletions.isEmpty }) { await Task.yield() }
    var busyCount = 0
    for _ in 0..<9 {
        do { _ = try await runner.run(profile: profile, dispatcher: dispatcher) }
        catch RunErrorCode.busy { busyCount += 1 }
    }
    #expect(busyCount == 9)
    await MainActor.run { dispatcher.heldCompletions.removeFirst()(.success(())) }
    _ = try await first.value
}

@Test("Cancellation stops new dispatch and preserves accepted work")
func runnerCancellation() async throws {
    let dispatcher = FakeActionDispatcher()
    await MainActor.run { dispatcher.behaviors = [.accepted, .held] }
    let runner = ProfileRunner(clock: PatientClock())
    let task = Task {
        try await runner.run(profile: makeRunProfile(policy: .continue, count: 3), dispatcher: dispatcher)
    }
    while await MainActor.run(body: { dispatcher.heldCompletions.isEmpty }) { await Task.yield() }
    await runner.cancelCurrentRun()
    let result = try await task.value

    #expect(result.status == .cancelled)
    #expect(result.actions.map(\.status) == [.accepted, .cancelled, .cancelled])
    #expect(await MainActor.run { dispatcher.dispatched.count } == 2)
}

@Test("A missing callback times out without real waiting and a late callback cannot affect the next run")
func runnerTimeoutAndLateCallback() async throws {
    let dispatcher = FakeActionDispatcher()
    await MainActor.run { dispatcher.behaviors = [.held] }
    let runner = ProfileRunner(clock: ActionTimeoutClock())
    let profile = makeRunProfile(policy: .continue, count: 1)
    let first = try await runner.run(profile: profile, dispatcher: dispatcher)
    #expect(first.status == .failed)
    #expect(first.actions[0].status == .timedOut)

    await MainActor.run {
        dispatcher.heldCompletions.removeFirst()(.success(()))
        dispatcher.behaviors = [.accepted]
    }
    let second = try await runner.run(profile: profile, dispatcher: dispatcher)
    #expect(second.status == .completed)
    #expect(second.actions[0].status == .accepted)
}

@Test("Preflight is covered by the total deadline")
func runnerPreflightDeadline() async throws {
    let dispatcher = FakeActionDispatcher()
    await MainActor.run { dispatcher.holdPreflight = true }
    let result = try await ProfileRunner(clock: ImmediateClock()).run(
        profile: makeRunProfile(policy: .continue, count: 1),
        dispatcher: dispatcher
    )
    #expect(result.status == .timedOut)
    #expect(result.actions[0].status == .timedOut)
    await MainActor.run {
        dispatcher.preflightContinuations.removeFirst().resume(returning: .failure(.applicationNotFound))
    }
}

@Test("The public event stream finishes after one terminal run event")
func runnerEventStreamFinishes() async throws {
    let dispatcher = FakeActionDispatcher()
    let stream = ProfileRunner(clock: PatientClock()).eventStream(
        for: makeRunProfile(policy: .continue, count: 1),
        dispatcher: dispatcher
    )
    var events: [RunEvent] = []
    for try await event in stream { events.append(event) }
    #expect(events.filter { if case .runFinished = $0.kind { true } else { false } }.count == 1)
}

@Test("A dispatcher callback delivered twice creates one accepted terminal action")
func runnerDoubleCallbackCompletesOnce() async throws {
    let dispatcher = FakeActionDispatcher()
    await MainActor.run { dispatcher.behaviors = [.doubleCallback] }
    let recorder = EventRecorder()
    let result = try await ProfileRunner(clock: PatientClock()).run(
        profile: makeRunProfile(policy: .continue, count: 1),
        dispatcher: dispatcher
    ) { await recorder.append($0) }
    let events = await recorder.events
    #expect(result.status == .completed)
    #expect(result.actions[0].status == .accepted)
    #expect(events.filter { if case .actionFinished = $0.kind { true } else { false } }.count == 1)
}

@Test("The runner keeps the value snapshot supplied at start")
func runnerImmutableSnapshot() async throws {
    let dispatcher = FakeActionDispatcher()
    await MainActor.run { dispatcher.behaviors = [.held, .accepted] }
    let runner = ProfileRunner(clock: PatientClock())
    let original = makeRunProfile(policy: .continue, count: 2)
    let task = Task { try await runner.run(profile: original, dispatcher: dispatcher) }
    while await MainActor.run(body: { dispatcher.heldCompletions.isEmpty }) { await Task.yield() }

    let edited = Profile(
        id: original.id,
        name: "Edited",
        createdAt: original.createdAt,
        updatedAt: original.updatedAt,
        failurePolicy: original.failurePolicy,
        shortcut: original.shortcut,
        actions: []
    )
    #expect(edited.actions.isEmpty)
    await MainActor.run { dispatcher.heldCompletions.removeFirst()(.success(())) }
    let result = try await task.value
    #expect(result.profileName == "Work")
    #expect(result.actions.count == 2)
}

@Test("An all-disabled profile is rejected without pending terminal states")
func runnerRejectsAllDisabledProfile() async throws {
    let dispatcher = FakeActionDispatcher()
    let base = makeRunProfile(policy: .continue, count: 1)
    let action = ProfileAction(
        id: base.actions[0].id,
        label: base.actions[0].label,
        enabled: false,
        kind: base.actions[0].kind
    )
    let profile = Profile(
        id: base.id,
        name: base.name,
        createdAt: base.createdAt,
        updatedAt: base.updatedAt,
        failurePolicy: base.failurePolicy,
        shortcut: nil,
        actions: [action]
    )
    let result = try await ProfileRunner(clock: PatientClock()).run(profile: profile, dispatcher: dispatcher)
    #expect(result.status == .failed)
    #expect(result.actions.map(\.status) == [.skipped(.disabled)])
}

private func makeRunProfile(policy: FailurePolicy, count: Int) -> Profile {
    let date = Date(timeIntervalSince1970: 1_788_602_400)
    return Profile(
        id: UUID(),
        name: "Work",
        createdAt: date,
        updatedAt: date,
        failurePolicy: policy,
        shortcut: nil,
        actions: (0..<count).map { index in
            ProfileAction(
                id: UUID(),
                label: "Action \(index)",
                enabled: true,
                kind: .openURL("https://example.test/\(index)")
            )
        }
    )
}
