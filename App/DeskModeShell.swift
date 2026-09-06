import AppKit
import DeskModeCore
import DeskModePlatform
import SwiftUI
import UniformTypeIdentifiers

private func localized(_ key: String) -> String {
    Bundle.main.localizedString(forKey: key, value: key, table: nil)
}

enum StorageViewState: Equatable {
    case loading
    case ready(ProfileStore)
    case recovery(RepositoryRecoveryState)
    case unavailable(String)
}

enum ManagementDestination: Equatable {
    case onboarding
    case profiles
    case profile(UUID)
    case results
    case settings
    case recovery
}

private enum PendingEditorIntent {
    case destination(ManagementDestination)
    case newProfile
    case duplicate(Profile)
    case closeWindow
}

struct RunProgressPresentation: Equatable {
    let profileID: UUID
    let profileName: String
    let completed: Int
    let total: Int
}

struct ActionResultPresentation: Identifiable, Equatable {
    let id: UUID
    let title: String
    let status: ActionRunStatus
}

struct LastRunPresentation: Equatable {
    let result: RunResult
    let actions: [ActionResultPresentation]
}

@MainActor
private final class SettingsUISmokeLoginItemBackend: LoginItemBackend {
    var status: LoginItemStatus = .notRegistered

    func register() throws {
        status = .enabled
    }

    func unregister() async throws {
        status = .notRegistered
    }

    func openSystemSettings() {}
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var storageState: StorageViewState = .loading
    @Published private(set) var draft: ProfileDraft?
    @Published private(set) var isSaving = false
    @Published private(set) var editorMessage: String?
    @Published private(set) var shortcutMessage: String?
    @Published private(set) var runProgress: RunProgressPresentation?
    @Published private(set) var lastRun: LastRunPresentation?
    @Published private(set) var loginItemStatus: LoginItemStatus = .notRegistered
    @Published private(set) var isUpdatingLoginItem = false
    @Published private(set) var settingsMessage: String?
    @Published private(set) var recoveryMessage: String?
    @Published private(set) var isRecovering = false
    @Published private(set) var profilePresentationMilliseconds: Double?
    @Published var managementDestination: ManagementDestination = .profiles
    @Published var showsUnsavedChangesDialog = false
    @Published var showsResetConfirmation = false

    private let repository: JSONProfileRepository?
    private let folderReferences: FolderReferenceService
    private let dispatcher: any ActionDispatching
    private let runner: ProfileRunner
    private let shortcutCoordinator: ProfileShortcutCoordinator
    private let loginItemService: LoginItemService
    private let diagnostics: DiagnosticsRecorder
    private let userDefaults: UserDefaults
    private let automaticallyShowOnboarding: Bool
    private var pendingEditorIntent: PendingEditorIntent?
    private var currentRunToken: UUID?
    private var finishedEnabledActionIDs: Set<UUID> = []
    private var diagnosticActionIDs: [UUID: UUID] = [:]
    private var runStartedAt: Date?
    private var profilePresentationRequestedAt: TimeInterval?

    private static let onboardingCompletedKey = "onboarding.completed.v1"

    let dataDirectoryURL: URL?
    let applicationName: String
    let applicationVersion: String
    let applicationBuild: String

    convenience init() {
        let arguments = ProcessInfo.processInfo.arguments
        let repository: JSONProfileRepository?
        if let path = ProcessInfo.processInfo.environment["DESKMODE_PROFILE_DIRECTORY"] {
            repository = try? JSONProfileRepository(directoryURL: URL(fileURLWithPath: path, isDirectory: true))
        } else {
            repository = try? JSONProfileRepository.applicationSupport()
        }
        let folders = FolderReferenceService()
        let dispatcher: any ActionDispatching = arguments.contains("--run-ui-smoke")
            || arguments.contains("--cancel-run-ui-smoke")
            || arguments.contains("--profile-shortcut-smoke")
            || arguments.contains("--e2e-ui-smoke")
            ? RunUISmokeDispatcher(holdDispatch: arguments.contains("--cancel-run-ui-smoke"))
            : WorkspaceDispatcher(folders: folders)
        let smokeArguments = [
            "--management-window-smoke", "--editor-ui-smoke", "--profiles-ui-smoke",
            "--run-ui-smoke", "--cancel-run-ui-smoke", "--profile-shortcut-smoke",
            "--settings-ui-smoke", "--login-item-os-smoke", "--recovery-ui-smoke",
            "--onboarding-ui-smoke", "--returning-user-ui-smoke", "--e2e-ui-smoke",
            "--performance-idle-smoke",
        ]
        let defaults = ProcessInfo.processInfo.environment["DESKMODE_DEFAULTS_SUITE"]
            .flatMap(UserDefaults.init(suiteName:)) ?? .standard
        if arguments.contains("--onboarding-ui-smoke") {
            defaults.removeObject(forKey: Self.onboardingCompletedKey)
        }
        self.init(
            repository: repository,
            folderReferences: folders,
            dispatcher: dispatcher,
            runner: ProfileRunner(),
            shortcutCoordinator: ProfileShortcutCoordinator(),
            loginItemService: arguments.contains("--settings-ui-smoke")
                ? LoginItemService(backend: SettingsUISmokeLoginItemBackend())
                : LoginItemService(),
            dataDirectoryURL: repository?.directoryURL,
            applicationName: Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? "Launchestra",
            applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                ?? "—",
            applicationBuild: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
                ?? "—",
            userDefaults: defaults,
            automaticallyShowOnboarding: arguments.contains("--onboarding-ui-smoke")
                || !arguments.contains(where: smokeArguments.contains)
        )
    }

    init(
        repository: JSONProfileRepository?,
        folderReferences: FolderReferenceService,
        dispatcher: any ActionDispatching,
        runner: ProfileRunner,
        shortcutCoordinator: ProfileShortcutCoordinator,
        loginItemService: LoginItemService,
        dataDirectoryURL: URL?,
        applicationName: String,
        applicationVersion: String,
        applicationBuild: String,
        userDefaults: UserDefaults = .standard,
        automaticallyShowOnboarding: Bool = false
    ) {
        self.repository = repository
        self.folderReferences = folderReferences
        self.dispatcher = dispatcher
        self.runner = runner
        self.shortcutCoordinator = shortcutCoordinator
        self.loginItemService = loginItemService
        self.dataDirectoryURL = dataDirectoryURL
        self.applicationName = applicationName
        self.applicationVersion = applicationVersion
        self.applicationBuild = applicationBuild
        self.userDefaults = userDefaults
        self.automaticallyShowOnboarding = automaticallyShowOnboarding
        diagnostics = DiagnosticsRecorder()
        loginItemStatus = loginItemService.status
        loadProfiles()
        if ProcessInfo.processInfo.arguments.contains("--management-window-smoke") {
            prepareManagementWindowSmoke()
        }
        if ProcessInfo.processInfo.arguments.contains("--editor-ui-smoke") {
            prepareEditorUISmoke()
        }
        if ProcessInfo.processInfo.arguments.contains("--profiles-ui-smoke") {
            prepareProfilesUISmoke()
        }
        if ProcessInfo.processInfo.arguments.contains("--run-ui-smoke")
            || ProcessInfo.processInfo.arguments.contains("--cancel-run-ui-smoke") {
            prepareRunUISmoke()
        }
        if ProcessInfo.processInfo.arguments.contains("--settings-ui-smoke") {
            prepareSettingsUISmoke()
        }
        if ProcessInfo.processInfo.arguments.contains("--login-item-os-smoke") {
            prepareLoginItemOSSmoke()
        }
        if ProcessInfo.processInfo.arguments.contains("--recovery-ui-smoke") {
            prepareRecoveryUISmoke()
        }
        if ProcessInfo.processInfo.arguments.contains("--returning-user-ui-smoke") {
            prepareReturningUserUISmoke()
        }
        if ProcessInfo.processInfo.arguments.contains("--e2e-ui-smoke") {
            prepareProfilesUISmoke()
        }
    }

    var store: ProfileStore? {
        guard case let .ready(store) = storageState else { return nil }
        return store
    }

    var profiles: [Profile] { store?.profiles ?? [] }
    var hasCompletedOnboarding: Bool { userDefaults.bool(forKey: Self.onboardingCompletedKey) }
    var isRunning: Bool { currentRunToken != nil }
    var activeProfileID: UUID? { runProgress?.profileID }
    var hasDirtyDraft: Bool { draft?.isDirty == true }
    var canAddProfile: Bool { profiles.count < ProfileStoreValidator.maximumProfiles }
    var canAddAction: Bool {
        guard let draft else { return false }
        return draft.actions.count < ProfileStoreValidator.maximumActionsPerProfile
    }

    var draftValidationMessage: String? {
        guard let draft, let store else { return nil }
        guard let error = ProfileDraftValidator.errors(draft, in: store, now: Date()).first else { return nil }
        return message(for: error)
    }

    var canSaveDraft: Bool {
        draft?.isDirty == true && draftValidationMessage == nil && !isSaving && storageState.isReady
    }

    var isLaunchAtLoginEnabled: Bool {
        loginItemStatus == .enabled || loginItemStatus == .requiresApproval
    }

    var loginItemStatusTitle: String {
        switch loginItemStatus {
        case .notRegistered: localized("Kapalı")
        case .enabled: localized("Açık")
        case .requiresApproval: localized("Onay gerekiyor")
        case .notFound: localized("Kullanılamıyor")
        }
    }

    var loginItemStatusDetail: String {
        switch loginItemStatus {
        case .notRegistered:
            localized("Launchestra oturum açıldığında kendiliğinden başlamaz.")
        case .enabled:
            localized("Launchestra sonraki oturum açılışlarında macOS tarafından başlatılabilir. Hiçbir profil otomatik çalıştırılmaz.")
        case .requiresApproval:
            localized("macOS onayı gerekiyor. Sistem Ayarları’ndaki Giriş Öğeleri bölümünde Launchestra’ya izin ver.")
        case .notFound:
            localized("macOS bu uygulama paketini giriş öğesi olarak bulamadı. Uygulamayı Applications klasörüne taşıdıktan sonra yeniden dene.")
        }
    }

    func loadProfiles() {
        guard let repository else {
            storageState = .unavailable(localized("Profil deposu açılamadı."))
            return
        }
        Task {
            do {
                let loaded = try await repository.load()
                storageState = .ready(loaded)
                diagnostics.record(DiagnosticRecord(event: .profilesLoaded))
                do {
                    try shortcutCoordinator.activateLoaded(
                        ShortcutAssignment.profileAssignments(in: loaded),
                        onTrigger: { [weak self] profileID in self?.run(profileID: profileID) }
                    )
                    shortcutMessage = nil
                    await Task.yield()
                    writeProfileShortcutSmokeMarker(named: "ready")
                } catch {
                    shortcutMessage = message(forShortcutError: error)
                    writeProfileShortcutSmokeMarker(named: "failed")
                }
                if automaticallyShowOnboarding && !hasCompletedOnboarding {
                    managementDestination = .onboarding
                    ManagementWindowController.shared.show(model: self)
                }
            } catch JSONProfileRepositoryError.mainMissingBackupAvailable {
                await enterRecovery(using: repository)
            } catch {
                if await enterRecovery(using: repository) == false {
                    shortcutCoordinator.removeAll()
                    diagnostics.record(DiagnosticRecord(event: .storageUnavailable))
                    storageState = .unavailable(localized("Profil verisi okunamadı. Dosya değiştirilmedi."))
                }
            }
        }
    }

    func showOnboarding() {
        requestDestination(.onboarding)
        ManagementWindowController.shared.show(model: self)
    }

    func finishOnboarding(createProfile: Bool) {
        userDefaults.set(true, forKey: Self.onboardingCompletedKey)
        if createProfile {
            beginNewProfile()
        } else {
            apply(.profiles)
        }
    }

    func showProfiles() {
        requestDestination(.profiles)
        ManagementWindowController.shared.show(model: self)
    }

    func showSettings() {
        refreshLoginItemStatus()
        requestDestination(.settings)
        ManagementWindowController.shared.show(model: self)
    }

    func showResults() {
        guard lastRun != nil else { return }
        requestDestination(.results)
        ManagementWindowController.shared.show(model: self)
    }

    func requestDestination(_ destination: ManagementDestination) {
        if destination == .settings { refreshLoginItemStatus() }
        if hasDirtyDraft, destination != managementDestination {
            pendingEditorIntent = .destination(destination)
            showsUnsavedChangesDialog = true
            return
        }
        if destination == .profiles, managementDestination != .profiles {
            profilePresentationRequestedAt = ProcessInfo.processInfo.systemUptime
        }
        apply(destination)
    }

    func profileListDidAppear() {
        guard let requestedAt = profilePresentationRequestedAt else { return }
        profilePresentationRequestedAt = nil
        profilePresentationMilliseconds =
            (ProcessInfo.processInfo.systemUptime - requestedAt) * 1_000
    }

    func refreshLoginItemStatus() {
        let current = loginItemService.status
        if current != loginItemStatus { settingsMessage = nil }
        loginItemStatus = current
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        guard !isUpdatingLoginItem else { return }
        isUpdatingLoginItem = true
        settingsMessage = nil
        Task {
            defer { isUpdatingLoginItem = false }
            do {
                loginItemStatus = try await loginItemService.setEnabled(enabled)
                settingsMessage = switch loginItemStatus {
                case .enabled: localized("Girişte başlatma açıldı.")
                case .notRegistered: localized("Girişte başlatma kapatıldı.")
                case .requiresApproval: localized("Kayıt oluşturuldu; etkinleşmesi için macOS onayı gerekiyor.")
                case .notFound: localized("Giriş öğesi uygulama paketinde bulunamadı.")
                }
            } catch {
                loginItemStatus = loginItemService.status
                settingsMessage = enabled
                    ? localized("Girişte başlatma açılamadı. macOS durumunu kontrol edip yeniden dene.")
                    : localized("Girişte başlatma kapatılamadı. macOS durumunu kontrol edip yeniden dene.")
            }
        }
    }

    func openLoginItemSystemSettings() {
        loginItemService.openSystemSettings()
    }

    func showDataDirectory() {
        guard let dataDirectoryURL else {
            settingsMessage = localized("Veri klasörünün konumu belirlenemedi.")
            return
        }
        if NSWorkspace.shared.open(dataDirectoryURL) {
            settingsMessage = nil
        } else {
            settingsMessage = localized("Veri klasörü Finder’da açılamadı.")
        }
    }

    func restoreRecoveryBackup() {
        guard let repository, !isRecovering else { return }
        isRecovering = true
        recoveryMessage = nil
        Task {
            defer { isRecovering = false }
            do {
                let restored = try await repository.restoreBackup()
                shortcutCoordinator.removeAll()
                storageState = .ready(restored)
                diagnostics.record(DiagnosticRecord(event: .recoveryCompleted))
                apply(.profiles)
                loadProfiles()
            } catch {
                recoveryMessage = localized("Yedek geri yüklenemedi. Özgün dosyalar değiştirilmedi.")
            }
        }
    }

    func requestRecoveryReset() {
        showsResetConfirmation = true
    }

    func resetRecoveryData() {
        guard let repository, !isRecovering else { return }
        isRecovering = true
        recoveryMessage = nil
        Task {
            defer { isRecovering = false }
            do {
                let empty = try await repository.resetToEmpty()
                shortcutCoordinator.removeAll()
                storageState = .ready(empty)
                diagnostics.record(DiagnosticRecord(event: .recoveryCompleted))
                apply(.profiles)
            } catch {
                recoveryMessage = localized("Yeni yapılandırma oluşturulamadı. Özgün dosyalar korundu.")
            }
        }
    }

    func requestNewProfile() {
        guard canAddProfile else {
            editorMessage = localized("En fazla 50 profil oluşturabilirsin.")
            return
        }
        if hasDirtyDraft {
            pendingEditorIntent = .newProfile
            showsUnsavedChangesDialog = true
        } else {
            beginNewProfile()
        }
    }

    func requestDuplicateCurrentProfile() {
        guard let draft, let source = profiles.first(where: { $0.id == draft.id }) else { return }
        guard canAddProfile else {
            editorMessage = localized("En fazla 50 profil oluşturabilirsin.")
            return
        }
        if hasDirtyDraft {
            pendingEditorIntent = .duplicate(source)
            showsUnsavedChangesDialog = true
        } else {
            beginDuplicate(source)
        }
    }

    func updateDraftName(_ name: String) {
        draft?.name = name
        editorMessage = nil
    }

    func updateFailurePolicy(_ policy: FailurePolicy) {
        draft?.failurePolicy = policy
        editorMessage = nil
    }

    func updateShortcut(_ shortcut: ShortcutBinding?) {
        draft?.shortcut = shortcut
        editorMessage = nil
    }

    func updateActionLabel(actionID: UUID, label: String) {
        updateAction(actionID) { action in
            ProfileAction(
                id: action.id,
                label: label.isEmpty ? nil : label,
                enabled: action.enabled,
                timeoutSeconds: action.timeoutSeconds,
                kind: action.kind
            )
        }
    }

    func updateActionEnabled(actionID: UUID, enabled: Bool) {
        updateAction(actionID) { action in
            ProfileAction(
                id: action.id,
                label: action.label,
                enabled: enabled,
                timeoutSeconds: action.timeoutSeconds,
                kind: action.kind
            )
        }
    }

    func updateActionURL(actionID: UUID, value: String) {
        updateAction(actionID) { action in
            ProfileAction(
                id: action.id,
                label: action.label,
                enabled: action.enabled,
                timeoutSeconds: action.timeoutSeconds,
                kind: .openURL(value)
            )
        }
    }

    func addURLAction() {
        guard canAddAction else {
            editorMessage = localized("Bir profilde en fazla 30 eylem olabilir.")
            return
        }
        draft?.actions.append(
            ProfileAction(id: UUID(), label: nil, enabled: true, kind: .openURL("https://"))
        )
    }

    func chooseApplication(actionID: UUID? = nil) {
        guard canAddAction || actionID != nil else {
            editorMessage = localized("Bir profilde en fazla 30 eylem olabilir.")
            return
        }
        let panel = NSOpenPanel()
        panel.title = actionID == nil ? localized("Uygulama Ekle") : localized("Uygulamayı Değiştir")
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        guard panel.runModal() == .OK, let url = panel.url, url.pathExtension.lowercased() == "app",
              let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier else { return }
        let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        setActionKind(
            .openApplication(ApplicationReference(bundleIdentifier: bundleID, displayName: displayName)),
            actionID: actionID
        )
    }

    func chooseFolder(actionID: UUID? = nil) {
        guard canAddAction || actionID != nil else {
            editorMessage = localized("Bir profilde en fazla 30 eylem olabilir.")
            return
        }
        let panel = NSOpenPanel()
        panel.title = actionID == nil ? localized("Klasör Ekle") : localized("Klasörü Değiştir")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            do {
                let reference = try await folderReferences.create(for: url)
                setActionKind(.openFolder(reference), actionID: actionID)
            } catch {
                editorMessage = localized("Klasör referansı oluşturulamadı. Başka bir klasör seç.")
            }
        }
    }

    func removeAction(_ actionID: UUID) {
        draft?.actions.removeAll { $0.id == actionID }
    }

    func moveAction(_ actionID: UUID, by offset: Int) {
        guard var draft else { return }
        draft.actions = ProfileActionEditor.moving(actionID: actionID, by: offset, in: draft.actions)
        self.draft = draft
    }

    func moveActions(fromOffsets: IndexSet, toOffset: Int) {
        guard var draft else { return }
        draft.actions.move(fromOffsets: fromOffsets, toOffset: toOffset)
        self.draft = draft
    }

    func saveDraft() {
        Task { _ = await persistDraft(andThen: nil) }
    }

    func cancelDraft() {
        guard let draft else { return }
        if let saved = profiles.first(where: { $0.id == draft.id }) {
            self.draft = ProfileDraft(profile: saved)
        } else {
            self.draft = nil
            managementDestination = .profiles
        }
        editorMessage = nil
    }

    func resolveUnsavedChangesBySaving() {
        let intent = pendingEditorIntent
        Task { _ = await persistDraft(andThen: intent) }
    }

    func resolveUnsavedChangesByDiscarding() {
        let intent = pendingEditorIntent
        pendingEditorIntent = nil
        showsUnsavedChangesDialog = false
        execute(intent)
    }

    func keepEditing() {
        pendingEditorIntent = nil
        showsUnsavedChangesDialog = false
    }

    func requestDeleteCurrentProfile() {
        guard let draft, let profile = profiles.first(where: { $0.id == draft.id }) else { return }
        guard activeProfileID != profile.id else {
            editorMessage = localized("Çalışan profil bitene kadar silinemez.")
            return
        }
        let alert = NSAlert()
        alert.messageText = String(format: localized("“%@” silinsin mi?"), profile.name)
        alert.informativeText = localized("Bu işlem yalnız Launchestra profil kaydını siler. Uygulama ve klasörler silinmez.")
        alert.addButton(withTitle: localized("Sil"))
        alert.addButton(withTitle: localized("Vazgeç"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        persistStoreMutation(ProfileStoreEditor.removing(profileID: profile.id, from: currentStore)) {
            self.draft = nil
            self.managementDestination = .profiles
        }
    }

    func moveCurrentProfile(by offset: Int) {
        guard let id = draft?.id else { return }
        let next = ProfileStoreEditor.moving(profileID: id, by: offset, in: currentStore)
        guard next != currentStore else { return }
        persistStoreMutation(next)
    }

    func moveProfiles(fromOffsets: IndexSet, toOffset: Int) {
        var profiles = currentStore.profiles
        profiles.move(fromOffsets: fromOffsets, toOffset: toOffset)
        let next = ProfileStore(
            schemaVersion: currentStore.schemaVersion,
            revision: currentStore.revision,
            profiles: profiles
        )
        guard next != currentStore else { return }
        persistStoreMutation(next)
    }

    func canRun(_ profile: Profile) -> Bool {
        !isRunning && profile.actions.contains(where: \.enabled)
    }

    func run(profileID: UUID) {
        guard currentRunToken == nil, let snapshot = profiles.first(where: { $0.id == profileID }), canRun(snapshot) else {
            return
        }
        let token = UUID()
        currentRunToken = token
        runStartedAt = Date()
        diagnostics.record(DiagnosticRecord(event: .runStarted, runID: token))
        finishedEnabledActionIDs = []
        diagnosticActionIDs = Dictionary(uniqueKeysWithValues: snapshot.actions.map { ($0.id, UUID()) })
        runProgress = RunProgressPresentation(
            profileID: snapshot.id,
            profileName: snapshot.name,
            completed: 0,
            total: snapshot.actions.filter(\.enabled).count
        )

        Task {
            do {
                let result = try await runner.run(profile: snapshot, dispatcher: dispatcher) { [weak self] event in
                    await MainActor.run { self?.handle(event, token: token, snapshot: snapshot) }
                }
                finishRun(result, token: token, snapshot: snapshot)
            } catch {
                guard currentRunToken == token else { return }
                currentRunToken = nil
                runProgress = nil
                runStartedAt = nil
                diagnosticActionIDs = [:]
                if let code = error as? RunErrorCode, code == .busy {
                    editorMessage = localized("Başka bir profil çalışıyor.")
                } else {
                    editorMessage = localized("Profil çalıştırılamadı.")
                }
            }
        }
    }

    func cancelRun() {
        Task { await runner.cancelCurrentRun() }
    }

    func quit() {
        guard isRunning else {
            NSApplication.shared.terminate(nil)
            return
        }
        let alert = NSAlert()
        alert.messageText = localized("Launchestra'dan çıkılsın mı?")
        alert.informativeText = localized("Çıkış kalan adımları durdurur. Daha önce açılan kaynaklar açık kalır.")
        alert.addButton(withTitle: localized("Çık ve Kalanları Durdur"))
        alert.addButton(withTitle: localized("Geri Dön"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Task {
            await runner.cancelCurrentRun()
            NSApplication.shared.terminate(nil)
        }
    }

    func requestWindowClose() -> Bool {
        guard hasDirtyDraft else { return true }
        pendingEditorIntent = .closeWindow
        showsUnsavedChangesDialog = true
        return false
    }

    func actionMessage(for status: ActionRunStatus) -> String {
        switch status {
        case .accepted: localized("İstek macOS tarafından kabul edildi.")
        case .timedOut: localized("Sonuç zamanında alınamadı; kaynak yine de açılmış olabilir.")
        case .cancelled: localized("Kullanıcı iptal etti; daha önce açılan kaynaklar açık kalır.")
        case let .failed(code): message(for: code)
        case .skipped(.disabled): localized("Devre dışı olduğu için atlandı.")
        case .skipped(.policyStopped): localized("Hata politikası çalıştırmayı durdurduğu için atlandı.")
        case .skipped(.preflightAborted): localized("Ön kontrolde başka bir kaynak başarısız olduğu için atlandı.")
        case .pending: localized("Bekliyor.")
        case .running: localized("Açma isteği gönderiliyor.")
        }
    }

    func actionTitle(_ action: ProfileAction) -> String {
        if let label = action.label, !label.isEmpty { return label }
        switch action.kind {
        case let .openApplication(reference): return reference.displayName
        case let .openFolder(reference): return reference.displayName
        case let .openURL(value):
            return WebURLPolicy.url(from: value)?.host.map { "\(localized("Web")) — \($0)" }
                ?? localized("Web adresi")
        }
    }

    private var currentStore: ProfileStore { store ?? .empty }

    private func apply(_ destination: ManagementDestination) {
        managementDestination = destination
        if case let .profile(id) = destination,
           let profile = profiles.first(where: { $0.id == id }) {
            draft = ProfileDraft(profile: profile)
            editorMessage = nil
        } else {
            draft = nil
        }
    }

    @discardableResult
    private func enterRecovery(using repository: JSONProfileRepository) async -> Bool {
        guard let recovery = try? await repository.recoveryState() else { return false }
        shortcutCoordinator.removeAll()
        diagnostics.record(DiagnosticRecord(event: .storageUnavailable))
        storageState = .recovery(recovery)
        managementDestination = .recovery
        ManagementWindowController.shared.show(model: self)
        return true
    }

    private func beginNewProfile() {
        let newDraft = ProfileDraft(createdAt: Date())
        draft = newDraft
        managementDestination = .profile(newDraft.id)
        editorMessage = nil
    }

    private func beginDuplicate(_ profile: Profile) {
        let duplicate = ProfileStoreEditor.duplicate(profile, in: currentStore, now: Date())
        draft = duplicate
        managementDestination = .profile(duplicate.id)
        editorMessage = nil
    }

    private func execute(_ intent: PendingEditorIntent?) {
        guard let intent else { return }
        switch intent {
        case let .destination(destination): apply(destination)
        case .newProfile: beginNewProfile()
        case let .duplicate(profile): beginDuplicate(profile)
        case .closeWindow: ManagementWindowController.shared.closeWithoutPrompt()
        }
    }

    private func persistDraft(andThen intent: PendingEditorIntent?) async -> Bool {
        guard let draft, let repository, let store else { return false }
        let profile: Profile
        do {
            profile = try ProfileDraftValidator.validate(draft, in: store, now: Date())
        } catch let error as ProfileDraftValidationError {
            editorMessage = message(for: error)
            return false
        } catch {
            editorMessage = localized("Profil doğrulanamadı.")
            return false
        }

        isSaving = true
        defer { isSaving = false }
        do {
            let proposedStore = ProfileStoreEditor.upserting(profile, in: store)
            let committed = try await shortcutCoordinator.persistAndActivate(
                ShortcutAssignment.profileAssignments(in: proposedStore),
                onTrigger: { [weak self] profileID in self?.run(profileID: profileID) }
            ) {
                try await repository.save(proposedStore, expectedRevision: store.revision)
            }
            shortcutMessage = nil
            storageState = .ready(committed)
            self.draft = committed.profiles.first(where: { $0.id == profile.id }).map(ProfileDraft.init)
            editorMessage = nil
            pendingEditorIntent = nil
            showsUnsavedChangesDialog = false
            execute(intent)
            return true
        } catch let error as ShortcutExperimentError {
            editorMessage = message(forShortcutError: error)
            return false
        } catch {
            editorMessage = localized("Değişiklikler kaydedilemedi. Taslağın korunuyor.")
            return false
        }
    }

    private func persistStoreMutation(_ next: ProfileStore, completion: (() -> Void)? = nil) {
        guard let repository, let store else { return }
        Task {
            do {
                let committed = try await shortcutCoordinator.persistAndActivate(
                    ShortcutAssignment.profileAssignments(in: next),
                    onTrigger: { [weak self] profileID in self?.run(profileID: profileID) }
                ) {
                    try await repository.save(next, expectedRevision: store.revision)
                }
                shortcutMessage = nil
                storageState = .ready(committed)
                editorMessage = nil
                completion?()
            } catch let error as ShortcutExperimentError {
                editorMessage = message(forShortcutError: error)
            } catch {
                editorMessage = localized("Değişiklik kaydedilemedi. Mevcut veriler korundu.")
            }
        }
    }

    private func message(forShortcutError error: Error) -> String {
        switch error as? ShortcutExperimentError {
        case .duplicateShortcut: localized("Bu kısayol başka bir profile atanmış.")
        case .systemShortcutConflict: localized("Bu kısayol macOS tarafından kullanılıyor. Başka bir kısayol seç.")
        case .persistenceFailed: localized("Kısayol kaydedilemedi. Önceki kısayol etkin kalıyor.")
        case nil: localized("Kısayol etkinleştirilemedi.")
        }
    }

    private func writeProfileShortcutSmokeMarker(named name: String) {
        guard ProcessInfo.processInfo.arguments.contains("--profile-shortcut-smoke"),
              let path = ProcessInfo.processInfo.environment["DESKMODE_PROFILE_SHORTCUT_SMOKE_DIRECTORY"]
        else { return }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data("1".utf8).write(to: directory.appending(component: name), options: .atomic)
        } catch {}
    }

    private func updateAction(_ actionID: UUID, transform: (ProfileAction) -> ProfileAction) {
        guard var draft, let index = draft.actions.firstIndex(where: { $0.id == actionID }) else { return }
        draft.actions[index] = transform(draft.actions[index])
        self.draft = draft
        editorMessage = nil
    }

    private func setActionKind(_ kind: ActionKind, actionID: UUID?) {
        if let actionID {
            updateAction(actionID) { action in
                ProfileAction(
                    id: action.id,
                    label: action.label,
                    enabled: action.enabled,
                    timeoutSeconds: action.timeoutSeconds,
                    kind: kind
                )
            }
        } else {
            draft?.actions.append(ProfileAction(id: UUID(), label: nil, enabled: true, kind: kind))
        }
    }

    private func handle(_ event: RunEvent, token: UUID, snapshot: Profile) {
        guard currentRunToken == token else { return }
        if case let .actionFinished(actionResult) = event.kind,
           snapshot.actions.first(where: { $0.id == actionResult.actionID })?.enabled == true {
            let code: RunErrorCode? = switch actionResult.status {
            case let .failed(value): value
            case .timedOut: .actionTimedOut
            case .cancelled: .cancelled
            default: nil
            }
            diagnostics.record(DiagnosticRecord(
                event: .actionFinished,
                runID: token,
                actionID: diagnosticActionIDs[actionResult.actionID],
                errorCode: code
            ))
            finishedEnabledActionIDs.insert(actionResult.actionID)
            runProgress = RunProgressPresentation(
                profileID: snapshot.id,
                profileName: snapshot.name,
                completed: finishedEnabledActionIDs.count,
                total: snapshot.actions.filter(\.enabled).count
            )
        }
    }

    private func finishRun(_ result: RunResult, token: UUID, snapshot: Profile) {
        guard currentRunToken == token else { return }
        let byID = Dictionary(uniqueKeysWithValues: result.actions.map { ($0.actionID, $0) })
        let actions = snapshot.actions.compactMap { action -> ActionResultPresentation? in
            guard let item = byID[action.id] else { return nil }
            return ActionResultPresentation(id: action.id, title: actionTitle(action), status: item.status)
        }
        let presentation = LastRunPresentation(result: result, actions: actions)
        let duration = runStartedAt.map { Int(Date().timeIntervalSince($0) * 1_000) }
        diagnostics.record(DiagnosticRecord(
            event: .runFinished,
            runID: token,
            durationMilliseconds: duration
        ))
        lastRun = presentation
        currentRunToken = nil
        finishedEnabledActionIDs = []
        diagnosticActionIDs = [:]
        runProgress = nil
        runStartedAt = nil
        if ProcessInfo.processInfo.arguments.contains("--run-ui-smoke")
            || ProcessInfo.processInfo.arguments.contains("--cancel-run-ui-smoke")
            || ProcessInfo.processInfo.arguments.contains("--profile-shortcut-smoke")
            || ProcessInfo.processInfo.arguments.contains("--e2e-ui-smoke") {
            managementDestination = .results
            writeRunUISmokeResult(presentation)
        }
    }

    private func message(for error: ProfileDraftValidationError) -> String {
        switch error {
        case .profileLimitReached: localized("En fazla 50 profil oluşturabilirsin.")
        case .actionLimitReached: localized("Bir profilde en fazla 30 eylem olabilir.")
        case .nameRequired: localized("Profil adı boş olamaz.")
        case .nameTooLong: localized("Profil adı en fazla 60 karakter olabilir.")
        case .duplicateName: localized("Bu isimde başka bir profil var.")
        case .invalidActionLabel: localized("Eylem etiketi boş olmalı veya en fazla 80 karakter içermeli.")
        case .invalidApplication: localized("Uygulamayı yeniden seç.")
        case .invalidFolder: localized("Klasörü yeniden seç.")
        case .invalidURL: localized("http:// veya https:// ile başlayan geçerli bir adres gir.")
        case .invalidShortcut: localized("Kısayolda en az Command, Control veya Option kullan.")
        case .duplicateShortcut: localized("Bu kısayol başka bir profile atanmış.")
        }
    }

    private func message(for code: RunErrorCode) -> String {
        switch code {
        case .applicationNotFound: localized("Bu uygulama bulunamadı.")
        case .folderUnresolved, .accessDenied: localized("Klasör açılamadı. Taşınmış veya erişim kısıtlanmış olabilir.")
        case .invalidURL: localized("Web adresi geçersiz.")
        case .launchRejected: localized("macOS açma isteğini reddetti.")
        case .actionTimedOut, .runTimedOut: localized("Açma isteğinin sonucu zamanında alınamadı.")
        case .cancelled: localized("Kullanıcı iptal etti.")
        case .busy: localized("Başka bir profil çalışıyor.")
        case .storageUnavailable: localized("Profil deposu kullanılamıyor.")
        case .invalidProfile: localized("Profil geçersiz.")
        }
    }

    private func prepareManagementWindowSmoke() {
        guard let path = ProcessInfo.processInfo.environment["DESKMODE_MANAGEMENT_SMOKE_DIRECTORY"] else { return }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data("1".utf8).write(to: directory.appending(component: "launched"), options: .atomic)
        } catch { return }

        Task {
            while case .loading = storageState { await Task.yield() }
            managementDestination = .profiles
            let controller = ManagementWindowController.shared
            controller.show(model: self)
            guard let first = controller.window else {
                try? Data("first-window-missing".utf8).write(to: directory.appending(component: "failed"))
                return
            }
            first.close()
            guard controller.window == nil else {
                try? Data("closed-window-retained".utf8).write(to: directory.appending(component: "failed"))
                return
            }
            managementDestination = .settings
            controller.show(model: self)
            guard let second = controller.window, second !== first, managementDestination == .settings else {
                try? Data("window-not-recreated".utf8).write(to: directory.appending(component: "failed"))
                return
            }
            let state: String
            switch storageState {
            case let .ready(store) where store.profiles.isEmpty: state = "empty-settings"
            case .ready: state = "profiles-settings"
            case .recovery: state = "recovery-settings"
            case .unavailable: state = "error-settings"
            case .loading: state = "unexpected-state"
            }
            try? Data(state.utf8).write(to: directory.appending(component: "ready"), options: .atomic)
        }
    }

    private func prepareEditorUISmoke() {
        Task {
            while case .loading = storageState { await Task.yield() }
            guard storageState.isReady else { return }
            beginNewProfile()
            ManagementWindowController.shared.show(model: self)
        }
    }

    private func prepareSettingsUISmoke() {
        Task {
            while case .loading = storageState { await Task.yield() }
            managementDestination = .settings
            ManagementWindowController.shared.show(model: self)
        }
    }

    private func prepareRecoveryUISmoke() {
        Task {
            while case .loading = storageState { await Task.yield() }
            if case .recovery = storageState {
                managementDestination = .recovery
                ManagementWindowController.shared.show(model: self)
            }
        }
    }

    private func prepareReturningUserUISmoke() {
        Task {
            while case .loading = storageState { await Task.yield() }
            managementDestination = hasCompletedOnboarding ? .profiles : .onboarding
            ManagementWindowController.shared.show(model: self)
        }
    }

    private func prepareLoginItemOSSmoke() {
        guard ProcessInfo.processInfo.environment["DESKMODE_RUN_LOGIN_ITEM_OS_SMOKE"] == "1",
              let path = ProcessInfo.processInfo.environment["DESKMODE_LOGIN_ITEM_SMOKE_RESULT"]
        else { return }
        let resultURL = URL(fileURLWithPath: path, isDirectory: false)
        Task {
            let initial = loginItemService.status
            guard initial == .notRegistered || initial == .notFound else {
                writeLoginItemSmokeResult("skipped;initial=\(smokeName(initial))", to: resultURL)
                NSApplication.shared.terminate(nil)
                return
            }

            do {
                let registered = try await loginItemService.setEnabled(true)
                let final = try await loginItemService.setEnabled(false)
                writeLoginItemSmokeResult(
                    "passed;initial=\(smokeName(initial));registered=\(smokeName(registered));final=\(smokeName(final))",
                    to: resultURL
                )
            } catch {
                let failedAt = loginItemService.status
                if failedAt != .notRegistered {
                    _ = try? await loginItemService.setEnabled(false)
                }
                writeLoginItemSmokeResult(
                    "failed;initial=\(smokeName(initial));status=\(smokeName(failedAt));restored=\(smokeName(loginItemService.status))",
                    to: resultURL
                )
            }
            NSApplication.shared.terminate(nil)
        }
    }

    private func writeLoginItemSmokeResult(_ value: String, to url: URL) {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data(value.utf8).write(to: url, options: .atomic)
        } catch {}
    }

    private func smokeName(_ status: LoginItemStatus) -> String {
        switch status {
        case .notRegistered: "notRegistered"
        case .enabled: "enabled"
        case .requiresApproval: "requiresApproval"
        case .notFound: "notFound"
        }
    }

    private func prepareProfilesUISmoke() {
        Task {
            while case .loading = storageState { await Task.yield() }
            managementDestination = .profiles
            ManagementWindowController.shared.show(model: self)
        }
    }

    private func prepareRunUISmoke() {
        Task {
            while case .loading = storageState { await Task.yield() }
            guard let profile = profiles.first else { return }
            managementDestination = .profiles
            ManagementWindowController.shared.show(model: self)
            run(profileID: profile.id)
        }
    }

    private func writeRunUISmokeResult(_ presentation: LastRunPresentation) {
        guard let path = ProcessInfo.processInfo.environment["DESKMODE_RUN_UI_SMOKE_DIRECTORY"] else { return }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        let lines = [presentation.result.status.rawValue]
            + presentation.actions.map { "\($0.title)|\($0.status)" }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data(lines.joined(separator: "\n").utf8).write(
                to: directory.appending(component: "result"),
                options: .atomic
            )
        } catch {}
    }
}

@MainActor
private final class RunUISmokeDispatcher: ActionDispatching {
    private let holdDispatch: Bool

    init(holdDispatch: Bool) {
        self.holdDispatch = holdDispatch
    }

    func preflight(_ action: ProfileAction) async -> Result<PreparedAction, RunErrorCode> {
        guard case let .openURL(value) = action.kind, let url = WebURLPolicy.url(from: value) else {
            return .failure(.invalidProfile)
        }
        return .success(.web(url))
    }

    func dispatch(
        _ action: PreparedAction,
        completion: @escaping @Sendable (Result<Void, RunErrorCode>) -> Void
    ) -> DispatchCancellation {
        guard case let .web(url) = action else {
            completion(.failure(.invalidProfile))
            return DispatchCancellation()
        }
        if holdDispatch {
            return DispatchCancellation()
        }
        completion(["fail.test", "bad.test"].contains(url.host) ? .failure(.launchRejected) : .success(()))
        return DispatchCancellation()
    }
}

private extension StorageViewState {
    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }
}

struct DeskModeMenu: View {
    @ObservedObject var model: AppModel
    let showTechnicalExperiments: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Launchestra", systemImage: "rectangle.3.group").font(.headline)
            switch model.storageState {
            case .loading:
                ProgressView("Profiller yükleniyor…").controlSize(.small)
            case .recovery:
                Label("Profil verisi için kullanıcı kararı gerekiyor.", systemImage: "lifepreserver")
                    .foregroundStyle(.orange)
                Button("Kurtarmayı Aç…") {
                    model.requestDestination(.recovery)
                    ManagementWindowController.shared.show(model: model)
                }
            case let .unavailable(message):
                Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                Button("Tekrar Dene", action: model.loadProfiles)
            case let .ready(store) where store.profiles.isEmpty:
                Text("Henüz profil yok.").foregroundStyle(.secondary)
                Button("İlk Profilini Oluştur…") {
                    model.showProfiles()
                    model.requestNewProfile()
                }
            case let .ready(store):
                ForEach(store.profiles, id: \.id) { profile in
                    Button { model.run(profileID: profile.id) } label: {
                        HStack {
                            Text(profile.name)
                            Spacer()
                            if let shortcut = profile.shortcut {
                                Text(shortcut.recordedShortcut.description)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                        .disabled(!model.canRun(profile))
                        .accessibilityLabel("\(profile.name) profilini çalıştır")
                }
            }

            if let message = model.shortcutMessage {
                Label(message, systemImage: "keyboard.badge.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let progress = model.runProgress {
                Divider()
                Text("\(progress.completed)/\(progress.total) — \(progress.profileName) açılıyor")
                    .font(.caption)
                ProgressView(value: Double(progress.completed), total: Double(max(1, progress.total)))
                Button("İptal", action: model.cancelRun)
                    .keyboardShortcut(.cancelAction)
            } else if let lastRun = model.lastRun {
                Divider()
                Text(runSummary(lastRun.result)).font(.caption).foregroundStyle(.secondary)
                Button("Sonucu Göster…", action: model.showResults)
            }

            Divider()
            Button("Başlangıç Rehberi…", action: model.showOnboarding)
            Button("Profilleri Yönet…", action: model.showProfiles).keyboardShortcut("o")
            Button("Ayarlar…", action: model.showSettings).keyboardShortcut(",")
            Button("Teknik Deneyler…", action: showTechnicalExperiments)
            Divider()
            Button("Launchestra'dan Çık", action: model.quit).keyboardShortcut("q")
        }
        .padding()
        .frame(width: 340)
        .accessibilityIdentifier("deskmode-menu")
    }

    private func runSummary(_ result: RunResult) -> String {
        let accepted = result.actions.filter { $0.status == .accepted }.count
        return switch result.status {
        case .completed: String(format: localized("%d açma isteği kabul edildi."), accepted)
        case .partial: String(format: localized("%d istek kabul edildi; bazı adımlar başarısız."), accepted)
        case .failed: localized("Profil çalıştırılamadı.")
        case .cancelled: localized("Kalan adımlar iptal edildi.")
        case .timedOut: localized("Çalıştırma zaman aşımına uğradı.")
        }
    }
}

struct ManagementView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationSplitView {
            List {
                Button { model.requestDestination(.profiles) } label: {
                    Label("Profiller", systemImage: "rectangle.stack")
                }
                .accessibilityIdentifier("profiles-navigation-button")
                Button { model.requestDestination(.settings) } label: {
                    Label("Ayarlar", systemImage: "gearshape")
                }
                .accessibilityIdentifier("settings-navigation-button")
                Section {
                    ForEach(model.profiles, id: \.id) { profile in
                        Button(profile.name) { model.requestDestination(.profile(profile.id)) }
                    }
                }
                if model.lastRun != nil {
                    Button { model.requestDestination(.results) } label: {
                        Label("Son Çalıştırma", systemImage: "list.bullet.clipboard")
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210)
        } detail: {
            switch model.managementDestination {
            case .onboarding: OnboardingView(model: model)
            case .profiles: ProfilesOverview(model: model)
            case .profile: ProfileEditorView(model: model)
            case .results: RunResultView(model: model)
            case .settings: SettingsView(model: model)
            case .recovery: RecoveryView(model: model)
            }
        }
        .frame(minWidth: 760, minHeight: 560)
        .confirmationDialog(
            "Kaydedilmemiş değişiklikler var",
            isPresented: $model.showsUnsavedChangesDialog,
            titleVisibility: .visible
        ) {
            Button("Kaydet") { model.resolveUnsavedChangesBySaving() }
            Button("Değişiklikleri Bırak", role: .destructive) { model.resolveUnsavedChangesByDiscarding() }
            Button("Düzenlemeye Dön", role: .cancel) { model.keepEditing() }
        } message: {
            Text("Devam etmeden önce taslağı kaydet veya değişiklikleri bırak.")
        }
        .safeAreaInset(edge: .bottom) {
            if let progress = model.runProgress {
                HStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.small)
                    Text("\(progress.completed)/\(progress.total) — \(progress.profileName) açılıyor")
                    Spacer()
                    Button("İptal", action: model.cancelRun)
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("cancel-run-button")
                }
                .padding(12)
                .background(.bar)
            }
        }
        .confirmationDialog(
            "Yeni yapılandırma oluşturulsun mu?",
            isPresented: $model.showsResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Özgün Veriyi Koru ve Sıfırla", role: .destructive, action: model.resetRecoveryData)
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Launchestra önce mevcut verinin recovery kopyasını oluşturur. Kopya yazılamazsa sıfırlama yapılmaz.")
        }
    }
}

private struct OnboardingView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Label("Launchestra’ya Hoş Geldin", systemImage: "rectangle.3.group.fill")
                    .font(.largeTitle.bold())
                Text("Uygulamalarını, klasörlerini ve web adreslerini bir profilde sırala; hazır olduğunda menü çubuğundan birlikte aç.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 16) {
                    Label("Menü çubuğundaki Launchestra simgesi profillerine her zaman ulaşmanı sağlar.", systemImage: "menubar.rectangle")
                    Label("İlk profilin boş başlar. Sen seçmeden uygulama, klasör veya web adresi açılmaz.", systemImage: "hand.raised")
                    Label("Global kısayol ve girişte başlatma isteğe bağlıdır; başlangıçta kapalıdır.", systemImage: "keyboard")
                }
                .font(.body)
                HStack {
                    Button("Şimdilik Geç") { model.finishOnboarding(createProfile: false) }
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("İlk Profilini Oluştur") { model.finishOnboarding(createProfile: true) }
                        .keyboardShortcut(.defaultAction)
                        .accessibilityIdentifier("onboarding-create-profile")
                }
            }
            .frame(maxWidth: 680, alignment: .topLeading)
            .padding(32)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding-view")
    }
}

private struct RecoveryView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if case let .recovery(state) = model.storageState {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Label("Profil Verisini Kurtar", systemImage: "lifepreserver.fill")
                        .font(.largeTitle.bold())
                    Text(explanation(state))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let date = state.backupModifiedAt, state.backupAvailable {
                        LabeledContent("Yedek tarihi", value: date.formatted(date: .abbreviated, time: .shortened))
                    }
                    Text("Launchestra sen bir seçim yapana kadar profil dosyasını değiştirmez ve profilleri çalıştırmaz.")
                        .font(.callout)
                    if let message = model.recoveryMessage {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                    HStack {
                        Button("Veri Klasörünü Göster", action: model.showDataDirectory)
                        Spacer()
                        Button("Yeni Yapılandırma…", role: .destructive, action: model.requestRecoveryReset)
                            .accessibilityIdentifier("recovery-reset-button")
                        if state.backupAvailable {
                            Button("Doğrulanmış Yedeği Kullan", action: model.restoreRecoveryBackup)
                                .keyboardShortcut(.defaultAction)
                                .accessibilityIdentifier("recovery-restore-button")
                        }
                    }
                    .disabled(model.isRecovering)
                }
                .frame(maxWidth: 680, alignment: .topLeading)
                .padding(32)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("recovery-view")
        } else {
            ContentUnavailableView("Kurtarma Gerekmiyor", systemImage: "checkmark.circle")
        }
    }

    private func explanation(_ state: RepositoryRecoveryState) -> String {
        switch state.cause {
        case .mainMissing:
            state.backupAvailable
                ? localized("Ana profil dosyası bulunamadı. Kullanılabilir doğrulanmış bir yedek var.")
                : localized("Ana profil dosyası bulunamadı; mevcut yedek de doğrulanamadı.")
        case .mainInvalid:
            state.backupAvailable
                ? localized("Ana profil dosyası bozuk veya geçersiz. Doğrulanmış yedeği geri yükleyebilirsin.")
                : localized("Ana profil dosyası bozuk ve kullanılabilir doğrulanmış yedek yok.")
        case let .unsupportedSchemaVersion(version):
            String(
                format: localized("Bu profil dosyası daha yeni veya desteklenmeyen şema sürümünü kullanıyor (v%d). Uyumlu Launchestra sürümünü kullanabilir ya da özgün veriyi koruyarak yeni yapılandırma oluşturabilirsin."),
                version
            )
        }
    }
}

private struct ProfilesOverview: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Profiller").font(.largeTitle.bold())
                Spacer()
                Button("Oluştur", systemImage: "plus", action: model.requestNewProfile)
                    .keyboardShortcut("n", modifiers: .command)
                    .disabled(!model.canAddProfile)
                    .accessibilityIdentifier("create-profile-button")
            }
            if model.profiles.isEmpty {
                ContentUnavailableView(
                    "Henüz Profil Yok",
                    systemImage: "rectangle.stack.badge.plus",
                    description: Text("İlk çalışma profilini oluşturabilirsin.")
                )
                .accessibilityIdentifier("empty-profile-state")
            } else {
                List {
                    ForEach(model.profiles, id: \.id) { profile in
                        HStack {
                            Button { model.requestDestination(.profile(profile.id)) } label: {
                                VStack(alignment: .leading) {
                                    Text(profile.name).font(.headline)
                                    Text(String(format: localized("%d eylem"), profile.actions.count))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            if model.activeProfileID == profile.id { ProgressView().controlSize(.small) }
                            Button("Çalıştır", systemImage: "play.fill") {
                                model.run(profileID: profile.id)
                            }
                            .disabled(!model.canRun(profile))
                            .accessibilityLabel(
                                String(format: localized("%@ profilini çalıştır"), profile.name)
                            )
                            .accessibilityIdentifier("run-profile-button")
                        }
                    }
                    .onMove(perform: model.moveProfiles)
                }
            }
            if let message = model.shortcutMessage {
                Label(message, systemImage: "keyboard.badge.exclamationmark")
                    .foregroundStyle(.orange)
            }
            if ProcessInfo.processInfo.environment["DESKMODE_PERFORMANCE_UI"] == "1",
               let milliseconds = model.profilePresentationMilliseconds {
                Text(String(format: "%.3f", milliseconds))
                    .accessibilityIdentifier("profile-presentation-ms")
                    .accessibilityValue(String(format: "%.3f", milliseconds))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .onAppear(perform: model.profileListDidAppear)
    }
}

private struct ProfileEditorView: View {
    @ObservedObject var model: AppModel
    @FocusState private var nameIsFocused: Bool

    var body: some View {
        if let draft = model.draft {
            VStack(spacing: 0) {
                HStack {
                    Text(draft.original == nil ? "Yeni Profil" : draft.name).font(.title.bold()).lineLimit(1)
                    Spacer()
                    Button("Çoğalt", action: model.requestDuplicateCurrentProfile).disabled(draft.original == nil)
                    Button("Yukarı") { model.moveCurrentProfile(by: -1) }.disabled(draft.original == nil)
                    Button("Aşağı") { model.moveCurrentProfile(by: 1) }.disabled(draft.original == nil)
                    Button("Sil", role: .destructive, action: model.requestDeleteCurrentProfile)
                        .disabled(draft.original == nil || model.activeProfileID == draft.id)
                }
                .padding()

                Form {
                    Section("Profil") {
                        TextField(
                            "Profil adı",
                            text: Binding(
                                get: { draft.name },
                                set: { model.updateDraftName($0) }
                            )
                        )
                        .focused($nameIsFocused)
                        .accessibilityIdentifier("profile-name-field")
                        HStack {
                            Text("Hata politikası")
                            Spacer()
                            Menu(draft.failurePolicy == .continue ? "Devam et" : "İlk hatada dur") {
                                Button("Devam et") { model.updateFailurePolicy(.continue) }
                                Button("İlk hatada dur") { model.updateFailurePolicy(.stop) }
                            }
                        }
                        ProfileShortcutRecorder(
                            shortcut: Binding(
                                get: { draft.shortcut },
                                set: { model.updateShortcut($0) }
                            )
                        )
                        .accessibilityIdentifier("profile-shortcut-recorder")
                        Text("Boş bırakabilir veya bu profile özel bir global kısayol atayabilirsin.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section("Eylemler") {
                        ForEach(Array(draft.actions.enumerated()), id: \.element.id) { index, action in
                            ActionEditorRow(model: model, action: action, index: index, count: draft.actions.count)
                        }
                        .onMove(perform: model.moveActions)
                        HStack {
                            Button("Uygulama Ekle…") { model.chooseApplication() }
                            Button("Klasör Ekle…") { model.chooseFolder() }
                            Button("URL Ekle", action: model.addURLAction)
                                .keyboardShortcut("u", modifiers: [.command, .shift])
                        }
                        .disabled(!model.canAddAction)
                    }

                    if let message = model.draftValidationMessage ?? model.editorMessage ?? model.shortcutMessage {
                        Label(message, systemImage: "exclamationmark.circle")
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("editor-error")
                    }
                }
                .formStyle(.grouped)

                HStack {
                    Spacer()
                    Button("İptal", action: model.cancelDraft)
                        .keyboardShortcut(.cancelAction)
                    Button(model.isSaving ? "Kaydediliyor…" : "Kaydet", action: model.saveDraft)
                        .keyboardShortcut("s", modifiers: .command)
                        .disabled(!model.canSaveDraft)
                        .accessibilityIdentifier("save-profile-button")
                }
                .padding()
            }
            .onAppear {
                if draft.original == nil { nameIsFocused = true }
            }
        } else {
            ContentUnavailableView("Profil Seçilmedi", systemImage: "rectangle.stack")
        }
    }
}

private struct ActionEditorRow: View {
    @ObservedObject var model: AppModel
    let action: ProfileAction
    let index: Int
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle(
                    "Etkin",
                    isOn: Binding(
                        get: { action.enabled },
                        set: { model.updateActionEnabled(actionID: action.id, enabled: $0) }
                    )
                )
                TextField(
                    "Etiket (isteğe bağlı)",
                    text: Binding(
                        get: { action.label ?? "" },
                        set: { model.updateActionLabel(actionID: action.id, label: $0) }
                    )
                )
                Button("Yukarı") { model.moveAction(action.id, by: -1) }.disabled(index == 0)
                Button("Aşağı") { model.moveAction(action.id, by: 1) }.disabled(index == count - 1)
                Button("Kaldır", role: .destructive) { model.removeAction(action.id) }
            }

            switch action.kind {
            case let .openApplication(reference):
                HStack {
                    Label(reference.displayName, systemImage: "app")
                    Spacer()
                    Button("Değiştir…") { model.chooseApplication(actionID: action.id) }
                }
            case let .openFolder(reference):
                HStack {
                    Label(reference.displayName, systemImage: "folder")
                    Spacer()
                    Button("Değiştir…") { model.chooseFolder(actionID: action.id) }
                }
            case let .openURL(value):
                TextField(
                    "https://example.com",
                    text: Binding(
                        get: { value },
                        set: { model.updateActionURL(actionID: action.id, value: $0) }
                    )
                )
                .accessibilityIdentifier("action-url-field")
                if WebURLPolicy.url(from: value) == nil {
                    Text("http:// veya https:// ile başlayan geçerli bir adres gir.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Eylem \(index + 1)")
    }
}

private struct RunResultView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if let lastRun = model.lastRun {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(lastRun.result.profileName).font(.largeTitle.bold())
                        Text(summary(lastRun.result))
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("run-summary")
                    }
                    Spacer()
                    Button("Profili Düzenle") {
                        model.requestDestination(.profile(lastRun.result.profileID))
                    }
                    .disabled(!model.profiles.contains(where: { $0.id == lastRun.result.profileID }))
                }
                List(lastRun.actions) { action in
                    HStack(alignment: .top) {
                        Image(systemName: icon(action.status)).foregroundStyle(color(action.status))
                        VStack(alignment: .leading) {
                            Text(action.title).font(.headline)
                            Text(model.actionMessage(for: action.status)).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                Text("Kabul, hedef uygulamanın veya sayfanın tamamen hazır olduğu anlamına gelmez.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .accessibilityIdentifier("run-result-view")
        } else {
            ContentUnavailableView("Henüz Çalıştırma Yok", systemImage: "list.bullet.clipboard")
        }
    }

    private func summary(_ result: RunResult) -> String {
        let accepted = result.actions.filter { $0.status == .accepted }.count
        return switch result.status {
        case .completed: String(format: localized("%d açma isteğinin tümü kabul edildi."), accepted)
        case .partial: String(format: localized("%d açma isteği kabul edildi; bazı adımlar tamamlanmadı."), accepted)
        case .failed: localized("Hiçbir açma isteği kabul edilmedi.")
        case .cancelled: localized("Çalıştırma iptal edildi; açılan kaynaklar açık kaldı.")
        case .timedOut: localized("Toplam çalışma süresi doldu; bazı kaynaklar yine de açılmış olabilir.")
        }
    }

    private func icon(_ status: ActionRunStatus) -> String {
        switch status {
        case .accepted: "checkmark.circle.fill"
        case .failed, .timedOut: "exclamationmark.triangle.fill"
        case .cancelled: "xmark.circle.fill"
        case .skipped: "forward.end.circle"
        case .pending, .running: "clock"
        }
    }

    private func color(_ status: ActionRunStatus) -> Color {
        switch status {
        case .accepted: .green
        case .failed, .timedOut: .orange
        case .cancelled: .red
        default: .secondary
        }
    }
}

private struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Genel") {
                Toggle(
                    "Girişte başlat",
                    isOn: Binding(
                        get: { model.isLaunchAtLoginEnabled },
                        set: { model.setLaunchAtLogin($0) }
                    )
                )
                .disabled(model.isUpdatingLoginItem)
                .accessibilityIdentifier("launch-at-login-toggle")

                LabeledContent("Durum", value: model.loginItemStatusTitle)
                    .accessibilityIdentifier("login-item-status")
                Text(model.loginItemStatusDetail)
                    .foregroundStyle(.secondary)

                if model.loginItemStatus == .requiresApproval {
                    Button("Giriş Öğeleri Ayarlarını Aç", action: model.openLoginItemSystemSettings)
                        .accessibilityIdentifier("open-login-items-settings")
                }
                if model.isUpdatingLoginItem {
                    ProgressView().controlSize(.small)
                }
                if let message = model.settingsMessage {
                    Text(message)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("settings-message")
                }
            }

            Section("Veriler") {
                LabeledContent("Konum") {
                    Text(model.dataDirectoryURL?.path(percentEncoded: false) ?? "Belirlenemedi")
                        .textSelection(.enabled)
                        .multilineTextAlignment(.trailing)
                        .accessibilityIdentifier("data-directory-path")
                }
                Button("Finder’da Göster", action: model.showDataDirectory)
                    .disabled(model.dataDirectoryURL == nil)
                    .accessibilityIdentifier("show-data-directory")
            }

            Section("Hakkında") {
                LabeledContent("Uygulama", value: model.applicationName)
                LabeledContent("Sürüm", value: model.applicationVersion)
                LabeledContent("Derleme", value: model.applicationBuild)
                Button("Başlangıç Rehberini Aç", action: model.showOnboarding)
            }
            Section("Gizlilik") {
                Text("Profiller bu Mac'te saklanır. Launchestra URL içeriğini indirmez ve açılan kaynakların hazır olduğunu izlemez.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .accessibilityIdentifier("settings-view")
        .onAppear(perform: model.refreshLoginItemStatus)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshLoginItemStatus()
        }
    }
}

@MainActor
final class ManagementWindowController: NSWindowController, NSWindowDelegate {
    static let shared = ManagementWindowController()
    private weak var model: AppModel?
    private var bypassClosePrompt = false

    private init() { super.init(window: nil) }
    required init?(coder: NSCoder) { nil }

    func show(model: AppModel) {
        self.model = model
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 820, height: 620),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Launchestra"
            window.contentView = NSHostingView(rootView: ManagementView(model: model))
            window.center()
            window.delegate = self
            self.window = window
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func closeWithoutPrompt() {
        bypassClosePrompt = true
        window?.close()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if bypassClosePrompt {
            bypassClosePrompt = false
            return true
        }
        return model?.requestWindowClose() ?? true
    }

    func windowWillClose(_ notification: Notification) {
        window?.contentView = nil
        window = nil
    }
}
