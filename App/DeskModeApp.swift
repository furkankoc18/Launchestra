import SwiftUI

@main
struct DeskModeApp: App {
    @StateObject private var model: AppModel
    @StateObject private var integrationModel: IntegrationLabModel

    init() {
        _model = StateObject(wrappedValue: AppModel())
        _integrationModel = StateObject(wrappedValue: IntegrationLabModel())
    }

    var body: some Scene {
        MenuBarExtra("Launchestra", systemImage: "rectangle.3.group") {
            DeskModeMenu(model: model) {
                IntegrationLabWindowController.shared.show(model: integrationModel)
            }
        }
        .menuBarExtraStyle(.window)
    }
}
