import AppKit
import SwiftUI

@MainActor
final class IntegrationLabWindowController: NSWindowController, NSWindowDelegate {
    static let shared = IntegrationLabWindowController()

    private init() {
        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show(model: IntegrationLabModel) {
        if window == nil {
            let content = IntegrationLabView(model: model)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Launchestra Integration Lab"
            window.contentView = NSHostingView(rootView: content)
            window.center()
            window.delegate = self
            self.window = window
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window?.contentView = nil
        window = nil
    }
}
