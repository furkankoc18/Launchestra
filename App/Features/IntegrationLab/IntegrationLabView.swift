import DeskModePlatform
import SwiftUI

struct IntegrationLabView: View {
    @ObservedObject var model: IntegrationLabModel

    var body: some View {
        Form {
            Section("Application") {
                LabeledContent("Selected", value: model.selectedApplicationName)
                HStack {
                    Button("Choose Application…", action: model.chooseApplication)
                    Button("Open Application", action: model.openSelectedApplication)
                }
            }

            Section("Folder bookmark") {
                LabeledContent(
                    "Selected",
                    value: model.selectedFolderURL?.path(percentEncoded: false) ?? "None"
                )
                HStack {
                    Button("Choose Folder…", action: model.chooseFolder)
                    Button("Resolve Bookmark", action: model.resolveBookmark)
                    Button("Open in Finder", action: model.openSelectedFolder)
                        .disabled(model.selectedFolderURL == nil)
                }
            }

            Section("Web URL") {
                TextField("https://example.com/", text: $model.webAddress)
                Button("Open in Default Browser", action: model.openWebAddress)
            }

            Section("Custom-storage shortcut") {
                ShortcutExperimentRecorder(shortcut: $model.shortcutDraft)
                HStack {
                    Button("Save and Activate", action: model.saveShortcut)
                    Text("Active: \(model.activeShortcutDescription)")
                        .foregroundStyle(.secondary)
                }
                Text("Key-up triggers: \(model.shortcutTriggerCount)")
                    .font(.caption)
            }

            Section("Last result") {
                Text(model.lastStatus ?? "No request has been sent.")
                    .textSelection(.enabled)
                Text("Accepted means macOS accepted the open request; it does not mean the target finished loading.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 640, minHeight: 500)
    }
}
