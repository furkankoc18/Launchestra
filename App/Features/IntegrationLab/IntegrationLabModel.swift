import AppKit
import Combine
import Darwin
import DeskModeCore
import DeskModePlatform
import Foundation
import UniformTypeIdentifiers

@MainActor
final class IntegrationLabModel: ObservableObject {
    let shortcutProfileID = UUID(uuidString: "C69C3F73-3778-4A24-8E03-17ED8DF7BEBB")!

    @Published var selectedApplicationName = "Safari"
    @Published var selectedApplicationBundleIdentifier = "com.apple.Safari"
    @Published var selectedFolderURL: URL?
    @Published var folderBookmark: Data?
    @Published var webAddress = "https://example.com/"
    @Published var shortcutDraft: RecordedShortcut?
    @Published var activeShortcutDescription = "Not assigned"
    @Published var shortcutTriggerCount = 0
    @Published var lastStatus: String?

    private let workspace = WorkspaceExperimentService()
    private let shortcutRegistry = ShortcutExperimentRegistry()
    private var shortcutSmokeSource: DispatchSourceFileSystemObject?
    private var shortcutSmokeActivated = false
    private lazy var shortcutCoordinator = ShortcutExperimentCoordinator(
        store: JSONShortcutExperimentStore(fileURL: shortcutExperimentFileURL),
        registry: shortcutRegistry
    )

    private var shortcutExperimentFileURL: URL {
        if ProcessInfo.processInfo.arguments.contains("--shortcut-smoke") {
            return shortcutSmokeDirectory
                .appending(component: "shortcut.json", directoryHint: .notDirectory)
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support
            .appending(component: "DeskMode", directoryHint: .isDirectory)
            .appending(component: "TechnicalExperiments", directoryHint: .isDirectory)
            .appending(component: "shortcut.json", directoryHint: .notDirectory)
    }

    init() {
        shortcutDraft = nil

        if ProcessInfo.processInfo.arguments.contains("--shortcut-smoke") {
            shortcutDraft = RecordedShortcut(.k, modifiers: [.command, .option, .control, .shift])
            prepareShortcutSmokeHandshake()
        }

        if ProcessInfo.processInfo.arguments.contains("--window-lifecycle-smoke") {
            prepareWindowLifecycleSmoke()
        }
    }

    private func prepareWindowLifecycleSmoke() {
        let directory = windowLifecycleSmokeDirectory
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            writeWindowLifecycleSmokeMarker(named: "launched")
        } catch {
            writeWindowLifecycleSmokeMarker(named: "failed", value: String(describing: error))
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let controller = IntegrationLabWindowController.shared
            controller.show(model: self)

            guard let firstWindow = controller.window else {
                self.writeWindowLifecycleSmokeMarker(named: "failed", value: "first-window-missing")
                return
            }

            firstWindow.close()
            guard controller.window == nil else {
                self.writeWindowLifecycleSmokeMarker(named: "failed", value: "closed-window-retained")
                return
            }

            controller.show(model: self)
            guard let secondWindow = controller.window, secondWindow !== firstWindow else {
                self.writeWindowLifecycleSmokeMarker(named: "failed", value: "window-not-recreated")
                return
            }

            self.writeWindowLifecycleSmokeMarker(named: "ready")
        }
    }

    private func prepareShortcutSmokeHandshake() {
        let directory = shortcutSmokeDirectory

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let descriptor = Darwin.open(directory.path, O_EVTONLY)
            guard descriptor >= 0 else {
                writeShortcutSmokeMarker(named: "failed")
                return
            }

            let source = Self.makeShortcutSmokeSource(
                descriptor: descriptor,
                directory: directory
            ) { [weak self] in
                await self?.activateShortcutSmokeMode()
            }
            shortcutSmokeSource = source
            source.resume()
            writeShortcutSmokeMarker(named: "launched")
        } catch {
            writeShortcutSmokeMarker(named: "failed", value: String(describing: error))
        }
    }

    nonisolated private static func makeShortcutSmokeSource(
        descriptor: Int32,
        directory: URL,
        onRegister: @escaping @MainActor @Sendable () async -> Void
    ) -> DispatchSourceFileSystemObject {
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: .write,
            queue: .global(qos: .userInitiated)
        )
        source.setCancelHandler { Darwin.close(descriptor) }
        source.setEventHandler {
            let marker = directory.appending(component: "register", directoryHint: .notDirectory)
            guard FileManager.default.fileExists(atPath: marker.path) else { return }
            Task { @MainActor in
                await onRegister()
            }
        }
        return source
    }

    private func activateShortcutSmokeMode() async {
        guard !shortcutSmokeActivated else { return }
        shortcutSmokeActivated = true
        guard let shortcutDraft else { return }
        let assignments = [ShortcutAssignment(profileID: shortcutProfileID, shortcut: shortcutDraft)]

        do {
            try await shortcutCoordinator.saveAndActivate(assignments) { [weak self] _ in
                self?.shortcutTriggerCount += 1
                guard let self else { return }
                self.writeShortcutSmokeMarker(
                    named: "triggered",
                    value: String(self.shortcutTriggerCount)
                )
            }
            writeShortcutSmokeMarker(named: "ready")
        } catch {
            writeShortcutSmokeMarker(named: "failed", value: String(describing: error))
        }
    }

    private func writeShortcutSmokeMarker(named name: String, value: String = "1") {
        let directory = shortcutSmokeDirectory
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data(value.utf8).write(
                to: directory.appending(component: name, directoryHint: .notDirectory),
                options: .atomic
            )
        } catch {
            lastStatus = "The shortcut smoke marker could not be written."
        }
    }

    private var shortcutSmokeDirectory: URL {
        if let path = ProcessInfo.processInfo.environment["DESKMODE_SHORTCUT_SMOKE_DIRECTORY"] {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return FileManager.default.temporaryDirectory
            .appending(component: "DeskModeShortcutSmoke", directoryHint: .isDirectory)
    }

    private func writeWindowLifecycleSmokeMarker(named name: String, value: String = "1") {
        do {
            try FileManager.default.createDirectory(
                at: windowLifecycleSmokeDirectory,
                withIntermediateDirectories: true
            )
            try Data(value.utf8).write(
                to: windowLifecycleSmokeDirectory.appending(component: name, directoryHint: .notDirectory),
                options: .atomic
            )
        } catch {
            lastStatus = "The window lifecycle smoke marker could not be written."
        }
    }

    private var windowLifecycleSmokeDirectory: URL {
        if let path = ProcessInfo.processInfo.environment["DESKMODE_WINDOW_SMOKE_DIRECTORY"] {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return FileManager.default.temporaryDirectory
            .appending(component: "DeskModeWindowLifecycleSmoke", directoryHint: .isDirectory)
    }

    func chooseApplication() {
        let panel = NSOpenPanel()
        panel.title = "Choose an application"
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url, let bundle = Bundle(url: url) else {
            return
        }

        guard let bundleIdentifier = bundle.bundleIdentifier else {
            lastStatus = "The selected app has no bundle identifier."
            return
        }

        selectedApplicationName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        selectedApplicationBundleIdentifier = bundleIdentifier
        lastStatus = "Selected \(selectedApplicationName). Nothing was opened."
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose a folder"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            folderBookmark = try FolderBookmark.create(for: url)
            selectedFolderURL = url
            lastStatus = "Selected \(url.lastPathComponent). Nothing was opened."
        } catch {
            lastStatus = "The folder bookmark could not be created."
        }
    }

    func resolveBookmark() {
        guard let folderBookmark else {
            lastStatus = "Choose a folder first."
            return
        }

        do {
            let resolved = try FolderBookmark.resolve(folderBookmark)
            selectedFolderURL = resolved.url
            lastStatus = resolved.isStale
                ? "Bookmark resolved but is stale."
                : "Bookmark resolved to \(resolved.url.lastPathComponent)."
        } catch {
            lastStatus = "The folder bookmark could not be resolved."
        }
    }

    func openSelectedApplication() {
        Task {
            do {
                _ = try await workspace.openApplication(bundleIdentifier: selectedApplicationBundleIdentifier)
                lastStatus = "macOS accepted the request to open \(selectedApplicationName)."
            } catch {
                lastStatus = "macOS rejected the application request."
            }
        }
    }

    func openSelectedFolder() {
        guard let selectedFolderURL else {
            lastStatus = "Choose a folder first."
            return
        }

        Task {
            do {
                try await workspace.openFolder(selectedFolderURL)
                lastStatus = "macOS accepted the Finder request."
            } catch {
                lastStatus = "macOS rejected the Finder request."
            }
        }
    }

    func openWebAddress() {
        guard let url = URL(string: webAddress) else {
            lastStatus = "Enter a valid HTTP or HTTPS address."
            return
        }

        do {
            try workspace.openWebURL(url)
            lastStatus = "macOS accepted the browser request. Page readiness is not checked."
        } catch {
            lastStatus = "Enter a valid HTTP or HTTPS address."
        }
    }

    func saveShortcut() {
        let assignments = shortcutDraft.map {
            [ShortcutAssignment(profileID: shortcutProfileID, shortcut: $0)]
        } ?? []

        Task {
            do {
                try await shortcutCoordinator.saveAndActivate(assignments) { [weak self] _ in
                    self?.shortcutTriggerCount += 1
                    self?.lastStatus = "Profile shortcut received once on key up."
                }
                activeShortcutDescription = shortcutDraft?.description ?? "Not assigned"
                lastStatus = shortcutDraft == nil
                    ? "Shortcut removed and listener unregistered."
                    : "Shortcut saved to JSON and activated."
            } catch ShortcutExperimentError.systemShortcutConflict {
                lastStatus = "That shortcut is already used by macOS."
            } catch ShortcutExperimentError.duplicateShortcut {
                lastStatus = "That shortcut already belongs to another profile."
            } catch {
                lastStatus = "The shortcut was not saved or activated."
            }
        }
    }
}
