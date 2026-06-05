import AppKit
import Observation
import SwiftUI

@MainActor
final class MenuBarStatusItemController: NSObject, NSPopoverDelegate {
    private let store: AntigravityUsageStore
    private let statusItem: NSStatusItem
    private let popover: NSPopover

    init(store: AntigravityUsageStore) {
        self.store = store
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        super.init()
        configureStatusItem()
        configurePopover()
        observeStatus()
    }

    func start() {
        updateStatusItem()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        button.target = self
        button.action = #selector(togglePopover(_:))
        button.imagePosition = .imageLeading
        button.setAccessibilityLabel("AntigravityBar")
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentSize = NSSize(width: MenuBarPanelMetrics.width, height: MenuBarPanelMetrics.height)
        popover.contentViewController = NSHostingController(rootView: MenuBarRootView(store: store))
    }

    private func observeStatus() {
        withObservationTracking {
            _ = store.statusBarPercentText
            _ = store.statusBarAccessibilityText
            _ = store.loadState
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.updateStatusItem()
                self?.observeStatus()
            }
        }
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        button.image = statusImage()
        button.attributedTitle = statusTitle()
        button.toolTip = "AntigravityBar"
        button.setAccessibilityLabel(store.statusBarAccessibilityText)
        statusItem.length = NSStatusItem.variableLength
    }

    private func statusTitle() -> NSAttributedString {
        let text = store.loadState == .loading ? " AG ..." : " AG \(store.statusBarPercentText)"
        return NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: NSColor.labelColor
            ]
        )
    }

    private func statusImage() -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = true
        return image
    }

    @objc
    private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else {
            return
        }

        if popover.isShown {
            popover.performClose(sender)
            return
        }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}
