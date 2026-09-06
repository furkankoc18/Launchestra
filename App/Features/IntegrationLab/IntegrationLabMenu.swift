import AppKit
import SwiftUI

struct IntegrationLabMenu: View {
    @ObservedObject var model: IntegrationLabModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Launchestra", systemImage: "rectangle.3.group")
                .font(.headline)

            Text("M0 integration lab")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Button("Open Integration Lab") {
                IntegrationLabWindowController.shared.show(model: model)
            }
            .keyboardShortcut("o")

            if let status = model.lastStatus {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Divider()

            Button("Quit Launchestra") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding()
        .frame(width: 300)
    }
}
