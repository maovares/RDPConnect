import AppKit
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private let store = ProfileStore()
    private let sidebar: SidebarViewController
    private let detail = DetailViewController()
    private var tailscaleState: TailscaleState = .unknown
    private var tailscaleMonitorTask: Task<Void, Never>?

    override init() {
        sidebar = SidebarViewController(store: store)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()

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
        detail.onSaveNow = { [weak self] in
            self?.store.flush()
        }

        detail.setProfile(store.profiles.first)

        startTailscaleMonitoring()

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        tailscaleMonitorTask?.cancel()
        store.flush()
    }

    private func startTailscaleMonitoring() {
        tailscaleMonitorTask = Task { [weak self] in
            while !Task.isCancelled {
                let state = await TailscaleChecker.check()
                await MainActor.run {
                    self?.tailscaleState = state
                    self?.detail.setTailscaleState(state)
                }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

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
            try RDPLauncher.launch(profile) { [weak self] message in
                self?.showAlert(title: "La conexión terminó con error", message: message, style: .critical)
            }
        } catch {
            showAlert(title: "Error al conectar", message: error.localizedDescription, style: .critical)
        }
    }

    private func showAlert(title: String, message: String, style: NSAlert.Style) {
        // Si sdl-freerdp tomó el foco como app activa y luego cerró, macOS no se lo
        // devuelve a RDPConnect automáticamente: sin esto, el alert queda modal pero
        // no-frontmost y el usuario no puede hacer click en sus botones para cerrarlo.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.runModal()
    }

    @objc private func exportProfiles() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "rdpconnect-profiles.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let data = store.exportJSON() else { return }
        do {
            try data.write(to: url)
        } catch {
            showAlert(title: "No se pudo exportar", message: error.localizedDescription, style: .warning)
        }
    }

    @objc private func importProfiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            try store.importJSON(data)
            sidebar.reload(selecting: store.profiles.last?.id)
            detail.setProfile(store.profiles.last)
        } catch {
            showAlert(title: "No se pudo importar", message: error.localizedDescription, style: .warning)
        }
    }

    private func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()
        let appName = "RDPConnect"

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "Acerca de \(appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let hide = appMenu.addItem(withTitle: "Ocultar \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        hide.target = NSApp
        let hideOthers = appMenu.addItem(withTitle: "Ocultar otros", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        hideOthers.target = NSApp
        let showAll = appMenu.addItem(withTitle: "Mostrar todo", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        showAll.target = NSApp
        appMenu.addItem(.separator())
        let quit = appMenu.addItem(withTitle: "Salir de \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp

        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "Archivo")
        fileMenuItem.submenu = fileMenu
        let exportItem = fileMenu.addItem(withTitle: "Exportar perfiles…", action: #selector(exportProfiles), keyEquivalent: "e")
        exportItem.target = self
        let importItem = fileMenu.addItem(withTitle: "Importar perfiles…", action: #selector(importProfiles), keyEquivalent: "i")
        importItem.target = self

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edición")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Deshacer", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Rehacer", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cortar", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copiar", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Pegar", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Seleccionar todo", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Ventana")
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "Minimizar", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Cerrar", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        NSApp.windowsMenu = windowMenu

        return mainMenu
    }
}
