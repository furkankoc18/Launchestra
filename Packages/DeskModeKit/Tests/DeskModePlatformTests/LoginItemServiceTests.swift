import DeskModePlatform
import Testing

@MainActor
private final class FakeLoginItemBackend: LoginItemBackend {
    var status: LoginItemStatus
    var statusAfterRegister: LoginItemStatus = .enabled
    var registerError: (any Error)?
    var unregisterError: (any Error)?
    private(set) var registerCount = 0
    private(set) var unregisterCount = 0
    private(set) var openedSystemSettings = false

    init(status: LoginItemStatus) {
        self.status = status
    }

    func register() throws {
        registerCount += 1
        if let registerError { throw registerError }
        status = statusAfterRegister
    }

    func unregister() async throws {
        unregisterCount += 1
        if let unregisterError { throw unregisterError }
        status = .notRegistered
    }

    func openSystemSettings() {
        openedSystemSettings = true
    }
}

private struct LoginItemTestError: Error {}

@Test("Login item begins from the system state and does not register during initialization")
@MainActor
func loginItemInitialState() {
    let backend = FakeLoginItemBackend(status: .notRegistered)
    let service = LoginItemService(backend: backend)

    #expect(service.status == .notRegistered)
    #expect(backend.registerCount == 0)
    #expect(backend.unregisterCount == 0)
}

@Test("Enabling and disabling follow the backend's resulting status")
@MainActor
func loginItemEnableDisable() async throws {
    let backend = FakeLoginItemBackend(status: .notRegistered)
    let service = LoginItemService(backend: backend)

    #expect(try await service.setEnabled(true) == .enabled)
    #expect(backend.registerCount == 1)
    #expect(try await service.setEnabled(false) == .notRegistered)
    #expect(backend.unregisterCount == 1)
}

@Test("Approval and external revocation remain system-derived states")
@MainActor
func loginItemApprovalAndExternalChange() async throws {
    let backend = FakeLoginItemBackend(status: .notRegistered)
    backend.statusAfterRegister = .requiresApproval
    let service = LoginItemService(backend: backend)

    #expect(try await service.setEnabled(true) == .requiresApproval)
    backend.status = .enabled
    #expect(service.status == .enabled)
    backend.status = .requiresApproval
    #expect(service.status == .requiresApproval)
    #expect(try await service.setEnabled(false) == .notRegistered)
    #expect(backend.unregisterCount == 1)
}

@Test("A registration failure is propagated without inventing an enabled state")
@MainActor
func loginItemRegistrationFailure() async {
    let backend = FakeLoginItemBackend(status: .notRegistered)
    backend.registerError = LoginItemTestError()
    let service = LoginItemService(backend: backend)

    await #expect(throws: LoginItemTestError.self) {
        try await service.setEnabled(true)
    }
    #expect(service.status == .notRegistered)
}

@Test("Enabled requests are idempotent and System Settings is delegated")
@MainActor
func loginItemIdempotenceAndSettings() async throws {
    let backend = FakeLoginItemBackend(status: .enabled)
    let service = LoginItemService(backend: backend)

    #expect(try await service.setEnabled(true) == .enabled)
    #expect(backend.registerCount == 0)
    service.openSystemSettings()
    #expect(backend.openedSystemSettings)

    let missingBackend = FakeLoginItemBackend(status: .notFound)
    let missingService = LoginItemService(backend: missingBackend)
    #expect(try await missingService.setEnabled(false) == .notFound)
    #expect(missingBackend.unregisterCount == 0)
}
