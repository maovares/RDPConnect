import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private let store = ProfileStore()
    private let sidebar: SidebarViewController
    private let detail = DetailViewController()
    private var tailscaleState: TailscaleState = .unknown
    private var pendingProfile: Profile?

    override init() {
        sidebar = SidebarViewController(store: store)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let splitVC = NSSplitViewController()

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebar)
        sidebarItem.minimumThickness = 180
        sidebarItem.maximumThickness = 260
        splitVC.addSplitViewItem(sidebarItem)

        let detailItem = NSSplitViewItem(viewController: detail)
        splitVC.addSplitViewItem(detailItem)

        window = NSWindow(contentViewController: splitVC)
        window.title = "RDPConnect"
        window.setContentSize(NSSize(width: 720, height: 440))
        window.styleMask.insert(.resizable)
        window.center()
        window.makeKeyAndOrderFront(nil)

        sidebar.onSelect = { [weak self] profile in
            self?.detail.setProfile(profile)
        }
        detail.setTailscaleState(.unknown)
        detail.onChange = { [weak self] profile in
            guard let self else { return }
            store.update(profile)
            sidebar.reload(selecting: profile.id)
        }
        detail.onConnect = { [weak self] profile in
            self?.attemptConnect(profile)
        }

        detail.setProfile(store.profiles.first)

        Task { [weak self] in
            let state = await TailscaleChecker.check()
            await MainActor.run {
                self?.tailscaleState = state
                self?.detail.setTailscaleState(state)
            }
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func attemptConnect(_ profile: Profile) {
        if tailscaleState == .connected {
            doConnect(profile)
            return
        }
        let alert = NSAlert()
        alert.messageText = "Tailscale no parece estar conectado"
        alert.informativeText = "No pudimos confirmar que Tailscale esté corriendo. Si el host solo es accesible por la VPN, la conexión va a fallar."
        alert.addButton(withTitle: "Conectar igual")
        alert.addButton(withTitle: "Cancelar")
        alert.alertStyle = .warning
        if alert.runModal() == .alertFirstButtonReturn {
            doConnect(profile)
        }
    }

    private func doConnect(_ profile: Profile) {
        do {
            try RDPLauncher.launch(profile)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Error al conectar"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.runModal()
        }
    }
}
