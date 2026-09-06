import Foundation

/// Build-time facts shared by the app and its tests.
public enum DeskModeEnvironment {
    public static let minimumMacOSMajorVersion = 14

    public static var isSupportedOperatingSystem: Bool {
        if #available(macOS 14, *) {
            true
        } else {
            false
        }
    }
}
