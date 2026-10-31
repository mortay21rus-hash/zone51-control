import AppKit
import SwiftUI

@MainActor final class SettingsWindowController {
    private var window: NSWindow?

    func show(model: AppModel) {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: ContentView(model: model)))
            window.title = "Zone51 Control"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 1080, height: 780))
            window.contentMinSize = NSSize(width: 920, height: 690)
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }

        NSApp.activate()
        window?.deminiaturize(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
