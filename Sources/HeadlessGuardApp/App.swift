import AppKit
import SwiftUI

@main
struct HeadlessGuardApplication: App {
    @NSApplicationDelegateAdaptor(GuardAppDelegate.self) private var appDelegate
    @StateObject private var model = GuardViewModel.shared

    init() {
        DispatchQueue.main.async {
            WindowPresenter.shared.show(model: GuardViewModel.shared)
            Task { await GuardViewModel.shared.startMonitoring() }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            GuardMenu(model: model)
        } label: {
            Image(systemName: model.incidents.isEmpty ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class GuardAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        WindowPresenter.shared.show(model: GuardViewModel.shared)
        Task { await GuardViewModel.shared.startMonitoring() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        WindowPresenter.shared.show(model: GuardViewModel.shared)
        return true
    }
}

@MainActor
final class WindowPresenter {
    static let shared = WindowPresenter()
    private var window: NSWindow?

    func show(model: GuardViewModel) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let root = DashboardView(model: model).preferredColorScheme(.dark)
        let controller = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: controller)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.title = "Headless Guard"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 920, height: 650)
        window.contentViewController = controller
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 1_040, height: 720))
        window.center()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
