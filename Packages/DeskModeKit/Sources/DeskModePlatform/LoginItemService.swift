import ServiceManagement

public enum LoginItemStatus: Equatable, Sendable {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound
}

@MainActor
public protocol LoginItemBackend: AnyObject {
    var status: LoginItemStatus { get }
    func register() throws
    func unregister() async throws
    func openSystemSettings()
}

@MainActor
public final class SMAppServiceLoginItemBackend: LoginItemBackend {
    private let service: SMAppService

    public init(service: SMAppService = .mainApp) {
        self.service = service
    }

    public var status: LoginItemStatus {
        switch service.status {
        case .notRegistered: .notRegistered
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notFound: .notFound
        @unknown default: .notFound
        }
    }

    public func register() throws {
        try service.register()
    }

    public func unregister() async throws {
        try await service.unregister()
    }

    public func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

@MainActor
public final class LoginItemService {
    private let backend: any LoginItemBackend

    public init(backend: any LoginItemBackend = SMAppServiceLoginItemBackend()) {
        self.backend = backend
    }

    public var status: LoginItemStatus { backend.status }

    @discardableResult
    public func setEnabled(_ enabled: Bool) async throws -> LoginItemStatus {
        if enabled {
            if backend.status == .notRegistered || backend.status == .notFound {
                try backend.register()
            }
        } else {
            switch backend.status {
            case .enabled, .requiresApproval:
                try await backend.unregister()
            case .notRegistered, .notFound:
                break
            }
        }
        return backend.status
    }

    public func openSystemSettings() {
        backend.openSystemSettings()
    }
}
