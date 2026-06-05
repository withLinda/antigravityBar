import SwiftUI

@main
struct AntigravityBarApp: App {
    @NSApplicationDelegateAdaptor(AntigravityAppDelegate.self) private var appDelegate
    @State private var runtime: AppRuntimeController

    init() {
        let runtime = AppRuntimeController()
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            runtime.start()
        }
        _runtime = State(initialValue: runtime)
    }

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
