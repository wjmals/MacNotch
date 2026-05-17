import SwiftUI
import AppKit

@main
struct MacNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene { Settings { EmptyView() } }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: NotchWindowController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusMenu()
        controller = NotchWindowController()
        controller?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
    }

    private func setupStatusMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)
        let menu = NSMenu()
        menu.addItem(withTitle: "MacNotch 열기", action: #selector(toggleIsland), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem?.menu = menu
    }

    @objc private func toggleIsland() {
        guard let vm = controller?.viewModel else { return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
            vm.state = vm.state == .hidden ? .expanded : .hidden
        }
    }
}
