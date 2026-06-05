import Foundation

@MainActor
final class AppRuntimeController {
    let store: AntigravityUsageStore
    private let menuBarController: MenuBarStatusItemController
    private var hasStarted = false

    init(store: AntigravityUsageStore = AntigravityUsageStore()) {
        self.store = store
        self.menuBarController = MenuBarStatusItemController(store: store)
    }

    func start() {
        guard hasStarted == false else {
            return
        }
        hasStarted = true
        menuBarController.start()
        store.start()
    }
}
