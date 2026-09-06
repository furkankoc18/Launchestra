import XCTest

@MainActor
final class DeskModeUITests: XCTestCase {
    func testWarmedProfileListPresentationPerformance() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let performanceRoot = projectRoot.appending(path: ".build/performance", directoryHint: .isDirectory)
        try XCTSkipUnless(
            FileManager.default.fileExists(
                atPath: performanceRoot.appending(path: "run-menu-measurement").path
            ),
            "Run explicitly for the DM-026 performance measurement."
        )

        let root = FileManager.default.temporaryDirectory
            .appending(component: "DeskModePerformanceUI-\(UUID().uuidString)", directoryHint: .isDirectory)
        let profileDirectory = root.appending(component: "Profiles", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: profileDirectory, withIntermediateDirectories: true)
        try performanceFixtureData().write(
            to: profileDirectory.appending(component: "profiles.json"),
            options: .atomic
        )

        let app = XCUIApplication()
        app.launchEnvironment["DESKMODE_PROFILE_DIRECTORY"] = profileDirectory.path
        app.launchEnvironment["DESKMODE_PERFORMANCE_UI"] = "1"
        app.launchArguments = ["--settings-ui-smoke", "-AppleLanguages", "(en)"]
        app.launch()
        defer { app.terminate() }

        XCTAssertTrue(app.descendants(matching: .any)["settings-view"].waitForExistence(timeout: 5))
        let profilesButton = app.buttons["profiles-navigation-button"]
        let settingsButton = app.buttons["settings-navigation-button"]
        XCTAssertTrue(profilesButton.exists)

        // Warm SwiftUI's list construction before recording the required 30 transitions.
        profilesButton.click()
        XCTAssertTrue(app.descendants(matching: .any)["profile-presentation-ms"].waitForExistence(timeout: 5))
        settingsButton.click()
        XCTAssertTrue(app.descendants(matching: .any)["settings-view"].waitForExistence(timeout: 3))

        var durations: [Double] = []
        for _ in 0..<30 {
            profilesButton.click()
            let metric = app.descendants(matching: .any)["profile-presentation-ms"]
            XCTAssertTrue(metric.waitForExistence(timeout: 3))
            let rawMetric = metric.value as? String ?? metric.label
            guard let milliseconds = Double(rawMetric) else {
                XCTFail("Profile presentation metric was not numeric: \(rawMetric)")
                return
            }
            durations.append(milliseconds)
            settingsButton.click()
        }

        let sorted = durations.sorted()
        let p95 = sorted[Int(ceil(Double(sorted.count) * 0.95)) - 1]
        let report: [String: Any] = [
            "sampleCount": durations.count,
            "durationsMilliseconds": durations,
            "p95Milliseconds": p95,
            "profileCount": 50,
            "actionsPerProfile": 30,
        ]
        let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "DM026-Menu-Performance"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertLessThan(p95, 150)
    }

    func testApplicationLaunchesAsMenuBarAgent() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(tr)"]
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5) || app.state == .runningBackground)
    }

    func testGlobalShortcutTriggersOnceWhileDeskModeIsInBackground() {
        let smokeDirectory = FileManager.default.temporaryDirectory
            .appending(component: "DeskModeShortcutSmoke-\(UUID().uuidString)", directoryHint: .isDirectory)
        let launchedMarker = smokeDirectory.appending(component: "launched")
        let registerMarker = smokeDirectory.appending(component: "register")
        let readyMarker = smokeDirectory.appending(component: "ready")
        let failedMarker = smokeDirectory.appending(component: "failed")
        let triggeredMarker = smokeDirectory.appending(component: "triggered")
        try? FileManager.default.removeItem(at: smokeDirectory)
        defer { try? FileManager.default.removeItem(at: smokeDirectory) }

        guard let executableURL = deskModeExecutableURL() else {
            XCTFail("DeskMode executable was not found beside the UI test runner.")
            return
        }
        let appProcess = Process()
        appProcess.executableURL = executableURL
        appProcess.arguments = ["--shortcut-smoke"]
        var environment = ProcessInfo.processInfo.environment
        environment["DESKMODE_SHORTCUT_SMOKE_DIRECTORY"] = smokeDirectory.path
        appProcess.environment = environment
        do {
            try appProcess.run()
        } catch {
            XCTFail("DeskMode could not be launched: \(error)")
            return
        }
        defer {
            if appProcess.isRunning { appProcess.terminate() }
        }

        let didLaunch = waitForFile(launchedMarker, timeout: 5)
        XCTAssertTrue(didLaunch)
        do {
            try Data("1".utf8).write(to: registerMarker, options: .atomic)
        } catch {
            XCTFail("Shortcut registration marker could not be written: \(error)")
            return
        }

        let becameReady = waitForFile(readyMarker, timeout: 5)
        let registrationFailure = try? String(contentsOf: failedMarker, encoding: .utf8)
        XCTAssertTrue(becameReady, "Registration failure: \(registrationFailure ?? "none")")
        XCTAssertNil(registrationFailure)

        XCTAssertFalse(FileManager.default.fileExists(atPath: triggeredMarker.path))

        let finder = XCUIApplication(bundleIdentifier: "com.apple.finder")
        finder.activate()
        finder.typeKey("k", modifierFlags: [.command, .option, .control, .shift])

        let didTrigger = waitForFile(triggeredMarker, timeout: 5)
        XCTAssertTrue(didTrigger)
        XCTAssertEqual(try? String(contentsOf: triggeredMarker, encoding: .utf8), "1")
    }

    func testWindowCanCloseAndReopenWhileMenuAgentKeepsRunning() {
        let smokeDirectory = FileManager.default.temporaryDirectory
            .appending(component: "DeskModeWindowSmoke-\(UUID().uuidString)", directoryHint: .isDirectory)
        let launchedMarker = smokeDirectory.appending(component: "launched")
        let readyMarker = smokeDirectory.appending(component: "ready")
        let failedMarker = smokeDirectory.appending(component: "failed")
        try? FileManager.default.removeItem(at: smokeDirectory)
        defer { try? FileManager.default.removeItem(at: smokeDirectory) }

        guard let executableURL = deskModeExecutableURL() else {
            XCTFail("DeskMode executable was not found beside the UI test runner.")
            return
        }

        let appProcess = Process()
        appProcess.executableURL = executableURL
        appProcess.arguments = ["--window-lifecycle-smoke"]
        var environment = ProcessInfo.processInfo.environment
        environment["DESKMODE_WINDOW_SMOKE_DIRECTORY"] = smokeDirectory.path
        appProcess.environment = environment

        do {
            try appProcess.run()
        } catch {
            XCTFail("DeskMode could not be launched: \(error)")
            return
        }
        defer {
            if appProcess.isRunning { appProcess.terminate() }
        }

        XCTAssertTrue(waitForFile(launchedMarker, timeout: 5))
        let didReopen = waitForFile(readyMarker, timeout: 5)
        let failure = try? String(contentsOf: failedMarker, encoding: .utf8)
        XCTAssertTrue(didReopen, "Lifecycle failure: \(failure ?? "none")")
        XCTAssertNil(failure)
        XCTAssertTrue(appProcess.isRunning)
    }

    func testManagementShellShowsEmptyStateAndReopensOnSettings() {
        let smokeDirectory = FileManager.default.temporaryDirectory
            .appending(component: "DeskModeManagementSmoke-\(UUID().uuidString)", directoryHint: .isDirectory)
        let profileDirectory = smokeDirectory.appending(component: "Profiles", directoryHint: .isDirectory)
        let launchedMarker = smokeDirectory.appending(component: "launched")
        let readyMarker = smokeDirectory.appending(component: "ready")
        let failedMarker = smokeDirectory.appending(component: "failed")
        try? FileManager.default.removeItem(at: smokeDirectory)
        defer { try? FileManager.default.removeItem(at: smokeDirectory) }

        guard let executableURL = deskModeExecutableURL() else {
            XCTFail("DeskMode executable was not found beside the UI test runner.")
            return
        }
        let appProcess = Process()
        appProcess.executableURL = executableURL
        appProcess.arguments = ["--management-window-smoke"]
        var environment = ProcessInfo.processInfo.environment
        environment["DESKMODE_MANAGEMENT_SMOKE_DIRECTORY"] = smokeDirectory.path
        environment["DESKMODE_PROFILE_DIRECTORY"] = profileDirectory.path
        appProcess.environment = environment
        do {
            try appProcess.run()
        } catch {
            XCTFail("DeskMode could not be launched: \(error)")
            return
        }
        defer { if appProcess.isRunning { appProcess.terminate() } }

        XCTAssertTrue(waitForFile(launchedMarker, timeout: 5))
        XCTAssertTrue(waitForFile(readyMarker, timeout: 5))
        XCTAssertFalse(FileManager.default.fileExists(atPath: failedMarker.path))
        XCTAssertEqual(try? String(contentsOf: readyMarker, encoding: .utf8), "empty-settings")
        XCTAssertTrue(appProcess.isRunning)
    }

    func testManagementShellLoadsProfilesAndKeepsStorageErrorsVisible() throws {
        let profileJSON = """
        {
          "profiles" : [
            {
              "actions" : [],
              "createdAt" : "2026-09-06T00:00:00Z",
              "failurePolicy" : "continue",
              "id" : "87D061FC-AB78-46E7-817B-6527ED51008A",
              "name" : "Çalışma",
              "shortcut" : null,
              "updatedAt" : "2026-09-06T00:00:00Z"
            }
          ],
          "revision" : 1,
          "schemaVersion" : 1
        }
        """
        try runManagementStateSmoke(mainData: Data(profileJSON.utf8), expected: "profiles-settings")
        try runManagementStateSmoke(mainData: Data("{broken".utf8), expected: "recovery-settings")
    }

    func testProfileEditorValidatesAndSavesADraft() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(component: "DeskModeEditorUI-\(UUID().uuidString)", directoryHint: .isDirectory)
        let profileDirectory = root.appending(component: "Profiles", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }

        let app = XCUIApplication()
        app.launchEnvironment["DESKMODE_PROFILE_DIRECTORY"] = profileDirectory.path
        app.launchArguments = ["--editor-ui-smoke"]
        app.launchArguments += ["-AppleLanguages", "(tr)"]
        app.launch()
        defer { app.terminate() }

        let name = app.textFields["profile-name-field"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Kısayol"].exists)
        let save = app.buttons["save-profile-button"]
        XCTAssertFalse(save.isEnabled)

        name.click()
        name.typeText("Akşam Çalışması")
        XCTAssertTrue(save.isEnabled)

        app.buttons["Ayarlar"].firstMatch.click()
        let keepEditing = app.buttons["Düzenlemeye Dön"]
        XCTAssertTrue(keepEditing.waitForExistence(timeout: 2))
        app.typeKey(.escape, modifierFlags: [])

        app.buttons["URL Ekle"].click()
        let url = app.textFields["action-url-field"]
        XCTAssertTrue(url.waitForExistence(timeout: 2))
        XCTAssertFalse(save.isEnabled)
        XCTAssertTrue(app.staticTexts["http:// veya https:// ile başlayan geçerli bir adres gir."].exists)
        url.click()
        url.typeKey("a", modifierFlags: .command)
        url.typeText("https://local.test/work?private=ui-test-secret")
        XCTAssertTrue(save.isEnabled)
        save.click()

        let profileFile = profileDirectory.appending(component: "profiles.json")
        XCTAssertTrue(waitForFile(profileFile, timeout: 5))
        let savedText = try String(contentsOf: profileFile, encoding: .utf8)
        XCTAssertTrue(savedText.contains("Akşam Çalışması"))

    }

    func testSettingsUsesSystemStateAndShowsBundleAndDataInformation() {
        let root = FileManager.default.temporaryDirectory
            .appending(component: "DeskModeSettingsUI-\(UUID().uuidString)", directoryHint: .isDirectory)
        let profileDirectory = root.appending(component: "Profiles", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }

        let app = XCUIApplication()
        app.launchEnvironment["DESKMODE_PROFILE_DIRECTORY"] = profileDirectory.path
        app.launchArguments = ["--settings-ui-smoke"]
        app.launchArguments += ["-AppleLanguages", "(tr)"]
        app.launch()
        defer { app.terminate() }

        let settings = app.descendants(matching: .any)["settings-view"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Kapalı"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["0.1.0"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["1"].waitForExistence(timeout: 3))
        let dataPath = app.descendants(matching: .any)["data-directory-path"]
        XCTAssertTrue(dataPath.waitForExistence(timeout: 3))
        XCTAssertTrue((dataPath.value as? String)?.hasPrefix(profileDirectory.path) == true)
        XCTAssertTrue(app.buttons["show-data-directory"].waitForExistence(timeout: 3))

        let toggle = app.switches["launch-at-login-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        toggle.click()
        XCTAssertTrue(app.staticTexts["Girişte başlatma açıldı."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Açık"].exists)

        toggle.click()
        XCTAssertTrue(app.staticTexts["Girişte başlatma kapatıldı."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Kapalı"].exists)
    }

    func testDocumentationScreenshots() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(component: "LaunchestraDocumentation-\(UUID().uuidString)", directoryHint: .isDirectory)
        let profileDirectory = root.appending(component: "Profiles", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try writeRunStore(
            to: profileDirectory,
            profileName: "Development",
            urls: [
                "https://github.com/furkankoc18/Launchestra",
                "https://developer.apple.com/documentation",
            ]
        )

        let app = XCUIApplication()
        app.launchEnvironment["DESKMODE_PROFILE_DIRECTORY"] = profileDirectory.path
        app.launchEnvironment["DESKMODE_RUN_UI_SMOKE_DIRECTORY"] = root.path
        app.launchArguments = ["--e2e-ui-smoke", "-AppleLanguages", "(en)"]
        app.launch()
        defer { app.terminate() }

        XCTAssertTrue(app.buttons["run-profile-button"].firstMatch.waitForExistence(timeout: 5))
        addDocumentationScreenshot(named: "Profiles-EN", from: app)

        app.buttons["Development"].firstMatch.click()
        XCTAssertTrue(app.textFields["profile-name-field"].waitForExistence(timeout: 3))
        addDocumentationScreenshot(named: "Profile-Editor-EN", from: app)

        app.buttons["Profiles"].firstMatch.click()
        let run = app.buttons["run-profile-button"].firstMatch
        XCTAssertTrue(run.waitForExistence(timeout: 3))
        run.click()
        XCTAssertTrue(app.buttons["Edit Profile"].waitForExistence(timeout: 5))
        addDocumentationScreenshot(named: "Run-Result-EN", from: app)
    }

    func testPrimaryEditorFlowWorksWithKeyboardShortcuts() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(component: "DeskModeKeyboardUI-\(UUID().uuidString)", directoryHint: .isDirectory)
        let profileDirectory = root.appending(component: "Profiles", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }

        let app = XCUIApplication()
        app.launchEnvironment["DESKMODE_PROFILE_DIRECTORY"] = profileDirectory.path
        app.launchArguments = ["--profiles-ui-smoke", "-AppleLanguages", "(tr)"]
        app.launch()
        defer { app.terminate() }

        XCTAssertTrue(app.descendants(matching: .any)["empty-profile-state"].waitForExistence(timeout: 5))
        app.typeKey("n", modifierFlags: .command)
        let name = app.textFields["profile-name-field"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.typeText("Key Work")

        app.typeKey("u", modifierFlags: [.command, .shift])
        let url = app.textFields["action-url-field"]
        XCTAssertTrue(url.waitForExistence(timeout: 3))
        url.click()
        url.typeKey("a", modifierFlags: .command)
        url.typeText("https://key.test/work")

        app.typeKey("s", modifierFlags: .command)
        XCTAssertTrue(waitForFile(profileDirectory.appending(component: "profiles.json"), timeout: 5))
        XCTAssertFalse(app.buttons["save-profile-button"].isEnabled)
    }

    func testFirstRunOnboardingPersistsAndLocalizesInTurkishAndEnglish() {
        let root = FileManager.default.temporaryDirectory
            .appending(component: "DeskModeOnboardingUI-\(UUID().uuidString)", directoryHint: .isDirectory)
        let profileDirectory = root.appending(component: "Profiles", directoryHint: .isDirectory)
        let defaultsSuite = "DeskModeUITests.onboarding.\(UUID().uuidString)"
        defer {
            UserDefaults(suiteName: defaultsSuite)?.removePersistentDomain(forName: defaultsSuite)
            try? FileManager.default.removeItem(at: root)
        }

        let first = XCUIApplication()
        first.launchEnvironment["DESKMODE_PROFILE_DIRECTORY"] = profileDirectory.path
        first.launchEnvironment["DESKMODE_DEFAULTS_SUITE"] = defaultsSuite
        first.launchArguments = ["-AppleLanguages", "(tr)", "--onboarding-ui-smoke"]
        first.launch()
        XCTAssertTrue(first.descendants(matching: .any)["onboarding-view"].waitForExistence(timeout: 5))
        XCTAssertTrue(first.descendants(matching: .any)["Launchestra’ya Hoş Geldin"].exists)
        let turkishScreenshot = XCTAttachment(screenshot: first.screenshot())
        turkishScreenshot.name = "Onboarding-TR-Light"
        turkishScreenshot.lifetime = .keepAlways
        add(turkishScreenshot)
        XCTAssertFalse(FileManager.default.fileExists(atPath: profileDirectory.appending(component: "profiles.json").path))
        first.buttons["İlk Profilini Oluştur"].click()
        let name = first.textFields["profile-name-field"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.typeText(String(repeating: "Ç", count: 60))
        XCTAssertTrue(name.isHittable)
        first.terminate()

        let returning = XCUIApplication()
        returning.launchEnvironment["DESKMODE_PROFILE_DIRECTORY"] = profileDirectory.path
        returning.launchEnvironment["DESKMODE_DEFAULTS_SUITE"] = defaultsSuite
        returning.launchArguments = ["-AppleLanguages", "(tr)", "--returning-user-ui-smoke"]
        returning.launch()
        XCTAssertTrue(returning.descendants(matching: .any)["empty-profile-state"].waitForExistence(timeout: 5))
        XCTAssertFalse(returning.descendants(matching: .any)["onboarding-view"].exists)
        returning.terminate()

        let englishSuite = "DeskModeUITests.onboarding.en.\(UUID().uuidString)"
        defer { UserDefaults(suiteName: englishSuite)?.removePersistentDomain(forName: englishSuite) }
        let english = XCUIApplication()
        english.launchEnvironment["DESKMODE_PROFILE_DIRECTORY"] = root.appending(component: "EnglishProfiles").path
        english.launchEnvironment["DESKMODE_DEFAULTS_SUITE"] = englishSuite
        english.launchArguments = [
            "-AppleLanguages", "(en)", "-AppleInterfaceStyle", "Dark", "--onboarding-ui-smoke",
        ]
        english.launch()
        defer { english.terminate() }
        XCTAssertTrue(english.staticTexts["Welcome to Launchestra"].waitForExistence(timeout: 5))
        XCTAssertTrue(english.buttons["Create Your First Profile"].exists)
        let englishScreenshot = XCTAttachment(screenshot: english.screenshot())
        englishScreenshot.name = "Onboarding-EN-Dark"
        englishScreenshot.lifetime = .keepAlways
        add(englishScreenshot)
    }

    func testRecoveryRestoresVerifiedBackupAndPreservesCorruptMain() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(component: "DeskModeRecoveryUI-\(UUID().uuidString)", directoryHint: .isDirectory)
        let profileDirectory = root.appending(component: "Profiles", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try writeRunStore(to: profileDirectory, profileName: "Kurtarılan Profil", urls: ["https://recovery.test"])
        let main = profileDirectory.appending(component: "profiles.json")
        let backup = profileDirectory.appending(component: "profiles.backup.json")
        try FileManager.default.moveItem(at: main, to: backup)
        let corrupt = Data("{corrupt-private-recovery-sentinel".utf8)
        try corrupt.write(to: main)

        let app = XCUIApplication()
        app.launchEnvironment["DESKMODE_PROFILE_DIRECTORY"] = profileDirectory.path
        app.launchArguments = ["--recovery-ui-smoke"]
        app.launchArguments += ["-AppleLanguages", "(tr)"]
        app.launch()
        defer { app.terminate() }

        XCTAssertTrue(app.descendants(matching: .any)["recovery-view"].waitForExistence(timeout: 5))
        let restore = app.buttons["Doğrulanmış Yedeği Kullan"]
        XCTAssertTrue(restore.exists)
        restore.click()
        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Kurtarılan Profil"))
                .firstMatch.waitForExistence(timeout: 5)
        )
        let recoveryFiles = try FileManager.default.contentsOfDirectory(atPath: profileDirectory.path)
            .filter { $0.hasPrefix("profiles.recovery-before-restore-") }
        XCTAssertEqual(recoveryFiles.count, 1)
        XCTAssertEqual(try Data(contentsOf: profileDirectory.appending(component: recoveryFiles[0])), corrupt)
    }

    func testRecoveryResetRequiresConfirmationAndPreservesOriginal() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(component: "DeskModeRecoveryResetUI-\(UUID().uuidString)", directoryHint: .isDirectory)
        let profileDirectory = root.appending(component: "Profiles", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: profileDirectory, withIntermediateDirectories: true)
        let corrupt = Data("{reset-private-sentinel".utf8)
        try corrupt.write(to: profileDirectory.appending(component: "profiles.json"))

        let app = XCUIApplication()
        app.launchEnvironment["DESKMODE_PROFILE_DIRECTORY"] = profileDirectory.path
        app.launchArguments = ["--recovery-ui-smoke"]
        app.launchArguments += ["-AppleLanguages", "(tr)"]
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.descendants(matching: .any)["recovery-view"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Doğrulanmış Yedeği Kullan"].exists)
        app.buttons["Yeni Yapılandırma…"].click()
        let confirm = app.sheets.buttons["Özgün Veriyi Koru ve Sıfırla"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.click()
        XCTAssertTrue(app.descendants(matching: .any)["empty-profile-state"].waitForExistence(timeout: 5))
        let recoveryFiles = try FileManager.default.contentsOfDirectory(atPath: profileDirectory.path)
            .filter { $0.hasPrefix("profiles.recovery-before-reset-") }
        XCTAssertEqual(recoveryFiles.count, 1)
        XCTAssertEqual(try Data(contentsOf: profileDirectory.appending(component: recoveryFiles[0])), corrupt)
    }

    func testCreateRestartRunEditAndRunAgainEndToEnd() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(component: "DeskModeE2E-\(UUID().uuidString)", directoryHint: .isDirectory)
        let profileDirectory = root.appending(component: "Profiles", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }

        let editor = XCUIApplication()
        editor.launchEnvironment["DESKMODE_PROFILE_DIRECTORY"] = profileDirectory.path
        editor.launchArguments = ["--editor-ui-smoke"]
        editor.launchArguments += ["-AppleLanguages", "(tr)"]
        editor.launch()
        let name = editor.textFields["profile-name-field"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.typeText("E2E Work")
        for (index, url) in ["https://one.test/start", "https://bad.test/private?secret=e2e"].enumerated() {
            editor.buttons["URL Ekle"].click()
            let fields = editor.textFields.matching(identifier: "action-url-field")
            let field = fields.element(boundBy: index)
            XCTAssertTrue(field.waitForExistence(timeout: 3))
            field.click()
            field.typeKey("a", modifierFlags: .command)
            field.typeText(url)
        }
        editor.buttons["save-profile-button"].click()
        XCTAssertTrue(waitForFile(profileDirectory.appending(component: "profiles.json"), timeout: 5))
        editor.terminate()

        let app = XCUIApplication()
        app.launchEnvironment["DESKMODE_PROFILE_DIRECTORY"] = profileDirectory.path
        app.launchEnvironment["DESKMODE_RUN_UI_SMOKE_DIRECTORY"] = root.path
        app.launchArguments = ["--e2e-ui-smoke"]
        app.launchArguments += ["-AppleLanguages", "(tr)"]
        app.launch()
        defer { app.terminate() }
        let run = app.buttons["run-profile-button"].firstMatch
        XCTAssertTrue(run.waitForExistence(timeout: 5))
        run.click()
        let resultMarker = root.appending(component: "result")
        XCTAssertTrue(waitForFileContent(resultMarker, prefix: "partial", timeout: 5))
        XCTAssertTrue(app.buttons["Profili Düzenle"].waitForExistence(timeout: 5))

        app.buttons["Profili Düzenle"].click()
        let secondURL = app.textFields.matching(identifier: "action-url-field").element(boundBy: 1)
        XCTAssertTrue(secondURL.waitForExistence(timeout: 3))
        secondURL.click()
        secondURL.typeKey("a", modifierFlags: .command)
        secondURL.typeText("https://two.test/ready")
        app.buttons["save-profile-button"].click()
        app.buttons["Profiller"].firstMatch.click()
        let rerun = app.buttons["run-profile-button"].firstMatch
        XCTAssertTrue(rerun.waitForExistence(timeout: 3))
        rerun.click()
        XCTAssertTrue(waitForFileContent(resultMarker, prefix: "completed", timeout: 5))
        XCTAssertTrue(app.buttons["Profili Düzenle"].waitForExistence(timeout: 5))
    }

    func testRunFlowShowsPartialResultWithoutURLSecrets() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(component: "DeskModeRunUI-\(UUID().uuidString)", directoryHint: .isDirectory)
        let profileDirectory = root.appending(component: "Profiles", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try writeRunStore(
            to: profileDirectory,
            profileName: "Kısmi Sonuç",
            urls: [
                "https://one.test/start?secret=one",
                "https://fail.test/private/path?token=do-not-show",
                "https://three.test/end#hidden",
            ]
        )

        let app = XCUIApplication()
        app.launchEnvironment["DESKMODE_PROFILE_DIRECTORY"] = profileDirectory.path
        app.launchEnvironment["DESKMODE_RUN_UI_SMOKE_DIRECTORY"] = root.path
        app.launchArguments = ["--run-ui-smoke"]
        app.launchArguments += ["-AppleLanguages", "(tr)"]
        app.launch()
        defer { app.terminate() }

        XCTAssertTrue(
            app.staticTexts["2 açma isteği kabul edildi; bazı adımlar tamamlanmadı."]
                .waitForExistence(timeout: 5)
        )
        let marker = root.appending(component: "result")
        XCTAssertTrue(waitForFile(marker, timeout: 5))
        let presentation = try String(contentsOf: marker, encoding: .utf8)
        XCTAssertTrue(presentation.contains("partial"))
        XCTAssertTrue(presentation.contains("Web — one.test|accepted"))
        XCTAssertTrue(presentation.contains("Web — fail.test|failed"))
        XCTAssertTrue(presentation.contains("Web — three.test|accepted"))
        XCTAssertFalse(presentation.contains("do-not-show"))
        XCTAssertFalse(presentation.contains("/private/path"))
    }

    func testActiveRunCanBeCancelledFromManagementWindow() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(component: "DeskModeCancelUI-\(UUID().uuidString)", directoryHint: .isDirectory)
        let profileDirectory = root.appending(component: "Profiles", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try writeRunStore(
            to: profileDirectory,
            profileName: "İptal Deneyi",
            urls: ["https://hold.test/start"]
        )

        let app = XCUIApplication()
        app.launchEnvironment["DESKMODE_PROFILE_DIRECTORY"] = profileDirectory.path
        app.launchEnvironment["DESKMODE_RUN_UI_SMOKE_DIRECTORY"] = root.path
        app.launchArguments = ["--cancel-run-ui-smoke"]
        app.launchArguments += ["-AppleLanguages", "(tr)"]
        app.launch()
        defer { app.terminate() }

        let cancel = app.buttons["cancel-run-button"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        app.typeKey(.escape, modifierFlags: [])
        let marker = root.appending(component: "result")
        XCTAssertTrue(waitForFile(marker, timeout: 5))
        let presentation = try String(contentsOf: marker, encoding: .utf8)
        XCTAssertTrue(presentation.contains("cancelled"))
        XCTAssertTrue(presentation.contains("Web — hold.test|cancelled"))

        app.terminate()
        let retry = XCUIApplication()
        retry.launchEnvironment["DESKMODE_PROFILE_DIRECTORY"] = profileDirectory.path
        retry.launchEnvironment["DESKMODE_RUN_UI_SMOKE_DIRECTORY"] = root.path
        retry.launchArguments = ["--e2e-ui-smoke"]
        retry.launchArguments += ["-AppleLanguages", "(tr)"]
        retry.launch()
        defer { retry.terminate() }
        let retryButton = retry.buttons["run-profile-button"].firstMatch
        XCTAssertTrue(retryButton.waitForExistence(timeout: 5))
        retryButton.click()
        XCTAssertTrue(retry.staticTexts["1 açma isteğinin tümü kabul edildi."].waitForExistence(timeout: 5))
    }

    func testSavedProfileShortcutRunsThroughTheProductRunner() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(component: "DeskModeProfileShortcutUI-\(UUID().uuidString)", directoryHint: .isDirectory)
        let profileDirectory = root.appending(component: "Profiles", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try writeRunStore(
            to: profileDirectory,
            profileName: "Kısayol Profili",
            urls: ["https://shortcut.test/start"],
            shortcut: [
                "keyCode": 40,
                "modifiers": ["control", "option", "shift", "command"],
            ]
        )

        let app = XCUIApplication()
        app.launchEnvironment["DESKMODE_PROFILE_DIRECTORY"] = profileDirectory.path
        app.launchEnvironment["DESKMODE_RUN_UI_SMOKE_DIRECTORY"] = root.path
        app.launchEnvironment["DESKMODE_PROFILE_SHORTCUT_SMOKE_DIRECTORY"] = root.path
        app.launchArguments = ["--profile-shortcut-smoke"]
        app.launchArguments += ["-AppleLanguages", "(tr)"]
        app.launch()
        defer { app.terminate() }

        XCTAssertTrue(waitForFile(root.appending(component: "ready"), timeout: 5))
        let finder = XCUIApplication(bundleIdentifier: "com.apple.finder")
        finder.activate()
        finder.typeKey("k", modifierFlags: [.command, .option, .control, .shift])

        let marker = root.appending(component: "result")
        XCTAssertTrue(waitForFile(marker, timeout: 5))
        let presentation = try String(contentsOf: marker, encoding: .utf8)
        XCTAssertTrue(presentation.contains("completed"))
        XCTAssertTrue(presentation.contains("Web — shortcut.test|accepted"))
    }

    private func deskModeExecutableURL() -> URL? {
        var productsDirectory = Bundle(for: Self.self).bundleURL
        for _ in 0..<4 {
            productsDirectory.deleteLastPathComponent()
        }
        let executable = productsDirectory
            .appending(component: "Launchestra.app", directoryHint: .isDirectory)
            .appending(path: "Contents/MacOS/Launchestra", directoryHint: .notDirectory)
        return FileManager.default.isExecutableFile(atPath: executable.path) ? executable : nil
    }

    private func addDocumentationScreenshot(named name: String, from app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func performanceFixtureData() throws -> Data {
        let timestamp = "2026-09-06T12:00:00Z"
        let profiles: [[String: Any]] = (0..<50).map { profileIndex in
            let actions: [[String: Any]] = (0..<30).map { actionIndex in
                [
                    "id": UUID().uuidString.lowercased(),
                    "label": "Action \(actionIndex + 1)",
                    "enabled": true,
                    "timeoutSeconds": 10,
                    "kind": [
                        "type": "openURL",
                        "payload": ["url": "https://example.invalid/p\(profileIndex + 1)/a\(actionIndex + 1)"],
                    ],
                ]
            }
            return [
                "id": UUID().uuidString.lowercased(),
                "name": "Profile \(profileIndex + 1)",
                "createdAt": timestamp,
                "updatedAt": timestamp,
                "failurePolicy": "continue",
                "shortcut": NSNull(),
                "actions": actions,
            ]
        }
        return try JSONSerialization.data(
            withJSONObject: ["schemaVersion": 1, "revision": 1, "profiles": profiles],
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    private func runManagementStateSmoke(mainData: Data, expected: String) throws {
        let smokeDirectory = FileManager.default.temporaryDirectory
            .appending(component: "DeskModeManagementState-\(UUID().uuidString)", directoryHint: .isDirectory)
        let profileDirectory = smokeDirectory.appending(component: "Profiles", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: smokeDirectory) }
        try FileManager.default.createDirectory(at: profileDirectory, withIntermediateDirectories: true)
        try mainData.write(to: profileDirectory.appending(component: "profiles.json"), options: .atomic)

        guard let executableURL = deskModeExecutableURL() else {
            XCTFail("Launchestra executable was not found beside the UI test runner.")
            return
        }
        let appProcess = Process()
        appProcess.executableURL = executableURL
        appProcess.arguments = ["--management-window-smoke"]
        var environment = ProcessInfo.processInfo.environment
        environment["DESKMODE_MANAGEMENT_SMOKE_DIRECTORY"] = smokeDirectory.path
        environment["DESKMODE_PROFILE_DIRECTORY"] = profileDirectory.path
        appProcess.environment = environment
        try appProcess.run()
        defer { if appProcess.isRunning { appProcess.terminate() } }

        let ready = smokeDirectory.appending(component: "ready")
        let failed = smokeDirectory.appending(component: "failed")
        XCTAssertTrue(waitForFile(ready, timeout: 5))
        XCTAssertFalse(FileManager.default.fileExists(atPath: failed.path))
        XCTAssertEqual(try? String(contentsOf: ready, encoding: .utf8), expected)
        XCTAssertTrue(appProcess.isRunning)
    }

    private func writeRunStore(
        to directory: URL,
        profileName: String,
        urls: [String],
        shortcut: [String: Any]? = nil
    ) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let actions: [[String: Any]] = urls.map { url in
            [
                "id": UUID().uuidString,
                "label": NSNull(),
                "enabled": true,
                "timeoutSeconds": 10,
                "kind": ["type": "openURL", "payload": ["url": url]],
            ]
        }
        let shortcutValue: Any = shortcut ?? NSNull()
        let object: [String: Any] = [
            "schemaVersion": 1,
            "revision": 1,
            "profiles": [[
                "id": UUID().uuidString,
                "name": profileName,
                "createdAt": "2026-09-06T00:00:00Z",
                "updatedAt": "2026-09-06T00:00:00Z",
                "failurePolicy": "continue",
                "shortcut": shortcutValue,
                "actions": actions,
            ]],
        ]
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: directory.appending(component: "profiles.json"), options: .atomic)
    }

    private func waitForFile(_ url: URL, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: url.path) {
                return true
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return false
    }

    private func waitForFileContent(_ url: URL, prefix: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let value = try? String(contentsOf: url, encoding: .utf8), value.hasPrefix(prefix) {
                return true
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return false
    }
}
