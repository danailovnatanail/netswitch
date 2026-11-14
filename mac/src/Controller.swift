import AppKit

/// Controller: icona nella status bar, dati, operazioni sulle interfacce e configurazioni.
/// Porting di Controller.cs. Il click sinistro sull'icona apre/chiude il flyout, il click
/// destro mostra il menu rapido (equivalente del ContextMenuStrip di WinForms).
class Controller: NSObject {
    var statusItem: NSStatusItem!
    var flyout: Flyout!

    var configs: [SavedConfig] = []
    var adapters: [AdapterInfo] = []
    private(set) var busy = false
    private(set) var startupEnabled = false
    private var refreshing = false
    private var pendingRefresh = false

    override init() {
        super.init()
        configs = ConfigStore.load()
        adapters = NetInfo.getAdapters()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = AppIcon.app
            button.image?.isTemplate = false
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        flyout = Flyout(app: self)
        flyout.anchorProvider = { [weak self] in
            guard let button = self?.statusItem.button, let window = button.window else { return nil }
            let rectInWindow = button.convert(button.bounds, to: nil)
            return window.convertToScreen(rectInWindow)
        }

        startupEnabled = Startup.isEnabled()
        updateTrayTooltip()

        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(onWake), name: NSWorkspace.didWakeNotification, object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(onAppearanceChanged),
                                                             name: NSNotification.Name("AppleInterfaceThemeChangedNotification"), object: nil)
    }

    @objc private func onWake() { refresh() }

    @objc private func onAppearanceChanged() {
        // Il tema viene riletto a ogni aggiornamento delle schede; lo sfondo del pannello
        // e i controlli fissi si allineano completamente alla prossima apertura del flyout.
        Theme.apply()
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp { showTrayMenu() }
        else { flyout.toggle() }
    }

    // ================================================================== dati

    func refresh() {
        if refreshing { pendingRefresh = true; return }
        refreshing = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let list = NetInfo.getAdapters()
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.adapters = list
                self.updateTrayTooltip()
                self.flyout.updateAdapters()
                self.refreshing = false
                if self.pendingRefresh { self.pendingRefresh = false; self.refresh() }
            }
        }
    }

    private func updateTrayTooltip() {
        var text = "NetSwitch"
        for a in adapters where a.isConnected {
            let line = "\n\(a.name): \(a.addresses.first ?? "-")"
            if (text + line).count > 63 { break }
            text += line
        }
        statusItem.button?.toolTip = text
    }

    private func saveConfigs() {
        do { try ConfigStore.save(configs) }
        catch { flyout.showResult(false, "Impossibile salvare le configurazioni:\n\(error.localizedDescription)") }
        flyout.buildConfigs()
    }

    // ================================================================== operazioni di rete

    func useDhcp(_ a: AdapterInfo) {
        runOp("DHCP su \(a.name)") { NetOps.applyDhcp(a.name) }
    }

    func applyConfig(_ a: AdapterInfo, _ c: SavedConfig) {
        let copy = c.clone()
        runOp("«\(c.name)» su \(a.name)") { NetOps.apply(a.name, a.device, copy) }
    }

    func setEnabled(_ a: AdapterInfo, _ enable: Bool) {
        if enable {
            runOp("Attivazione di \(a.name)") { NetOps.setEnabled(a.name, true) }
            return
        }
        flyout.confirm(
            title: "Disattivare \(a.name)?",
            message: a.isConnected ? "L'interfaccia è connessa: la connettività su di essa verrà interrotta."
                                    : "Potrai riattivarla in qualsiasi momento da NetSwitch.",
            okText: "Disattiva", danger: true,
            onOk: { [weak self] in self?.runOp("Disattivazione di \(a.name)") { NetOps.setEnabled(a.name, false) } })
    }

    /// Chiamato dall'editor "Imposta IP" (già validato).
    func submitApply(_ a: AdapterInfo, _ c: SavedConfig, _ saveAsConfig: Bool) {
        if saveAsConfig {
            configs.append(c.clone())
            saveConfigs()
        }
        runOp("Imposta IP su \(a.name)") { NetOps.apply(a.name, a.device, c) }
    }

    private func runOp(_ title: String, _ op: @escaping () -> OpResult) {
        if busy {
            flyout.warn("Un'altra operazione è in corso, attendere.")
            return
        }
        busy = true
        flyout.showBusy(title)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let r = op()
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.busy = false
                self.refresh()
                let text = r.ok ? (r.message.isEmpty ? title : r.message) : title + " non riuscita.\n\n" + r.message
                self.flyout.showResult(r.ok, text)
                if !self.flyout.isVisible {
                    self.notify(title: r.ok ? "NetSwitch" : "NetSwitch - errore",
                                body: truncate(r.ok ? text : title + ": " + r.message, 250))
                }
                // il sistema aggiorna le informazioni IP con un leggero ritardo
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in self?.refresh() }
            }
        }
    }

    private func notify(title: String, body: String) {
        let n = NSUserNotification()
        n.title = title
        n.informativeText = body
        NSUserNotificationCenter.default.deliver(n)
    }

    func toggleStartup() {
        let r = startupEnabled ? Startup.disable() : Startup.enable()
        if r.ok { startupEnabled.toggle() }
        if flyout.isVisible { flyout.showResult(r.ok, r.message) }
        else { notify(title: "NetSwitch", body: truncate(r.message, 250)) }
    }

    // ================================================================== configurazioni

    func validateConfigName(_ name: String, _ editing: SavedConfig?) -> String? {
        let n = name.trimmingCharacters(in: .whitespaces)
        if n.isEmpty { return "Inserisci un nome per la configurazione." }
        if configs.contains(where: { $0 !== editing && $0.name.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(n) == .orderedSame }) {
            return "Esiste già una configurazione chiamata «\(n)»."
        }
        return nil
    }

    func submitConfig(_ editing: SavedConfig?, _ c: SavedConfig) {
        if let editing = editing, let i = configs.firstIndex(where: { $0 === editing }) { configs[i] = c }
        else { configs.append(c) }
        saveConfigs()
        flyout.showResult(true, "Configurazione «\(c.name)» salvata")
    }

    /// Nuova configurazione precompilata con i valori attuali di un'interfaccia.
    func newConfigFrom(_ from: AdapterInfo) {
        let fresh = adapters.first(where: { $0.key == from.key }) ?? from
        let initC = SavedConfig()
        var n = fresh.name
        var k = 2
        while validateConfigName(n, nil) != nil { n = fresh.name + " \(k)"; k += 1 }
        initC.name = n
        initC.dhcp = fresh.dhcp
        initC.address = fresh.addresses.isEmpty ? "" : (fresh.dhcp ? fresh.addresses[0] : fresh.addresses.joined(separator: ", "))
        initC.gateway = fresh.gateways.first ?? ""
        if !fresh.dhcp {
            initC.dns1 = fresh.dns.first ?? ""
            initC.dns2 = fresh.dns.count > 1 ? fresh.dns[1] : ""
        }
        flyout.openConfigEditor(nil, initC)
    }

    func duplicateConfig(_ c: SavedConfig) {
        let copy = c.clone()
        let baseName = c.name + " (copia)"
        copy.name = baseName
        var n = 2
        while validateConfigName(copy.name, nil) != nil { copy.name = baseName + " \(n)"; n += 1 }
        if let idx = configs.firstIndex(where: { $0 === c }) { configs.insert(copy, at: idx + 1) }
        else { configs.append(copy) }
        saveConfigs()
    }

    func deleteConfig(_ c: SavedConfig) {
        flyout.confirm(title: "Eliminare «\(c.name)»?", message: "La configurazione verrà rimossa definitivamente.", okText: "Elimina", danger: true) {
            [weak self] in
            self?.configs.removeAll { $0 === c }
            self?.saveConfigs()
        }
    }

    func moveConfig(_ c: SavedConfig, _ delta: Int) {
        guard let i = configs.firstIndex(where: { $0 === c }) else { return }
        let j = i + delta
        guard j >= 0, j < configs.count else { return }
        configs.remove(at: i)
        configs.insert(c, at: j)
        saveConfigs()
    }

    // ================================================================== menu tasto destro

    private func showTrayMenu() {
        guard let button = statusItem.button else { return }
        let menu = buildTrayMenu()
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    private func buildTrayMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let open = ClosureMenuItem(title: "Apri NetSwitch", action: { [weak self] in self?.flyout.showFlyout() })
        open.attributedTitle = NSAttributedString(string: "Apri NetSwitch", attributes: [.font: NSFont.boldSystemFont(ofSize: 13)])
        menu.addItem(open)
        menu.addItem(.separator())

        for a in adapters {
            let detail: String
            if !a.adminEnabled { detail = "disattivata" }
            else if !a.isConnected { detail = a.connectionStatus == 0 ? "non connessa" : a.statusText.lowercased() }
            else if let ip = a.addresses.first { detail = ip + (a.dhcp ? "  (DHCP)" : "") }
            else { detail = "connessa" }

            let item = NSMenuItem(title: "\(a.name)    \(detail)", action: nil, keyEquivalent: "")
            item.image = AppIcon.dotFor(a)
            let sub = NSMenu()
            let can = a.adminEnabled && !busy

            let setItem = ClosureMenuItem(title: "Imposta IP...", action: { [weak self] in self?.flyout.openApplyEditor(a) })
            setItem.isEnabled = can
            let dhcpItem = ClosureMenuItem(title: "Usa DHCP", action: { [weak self] in self?.useDhcp(a) })
            dhcpItem.isEnabled = can
            let cfgItem = NSMenuItem(title: "Applica configurazione", action: nil, keyEquivalent: "")
            cfgItem.isEnabled = can && !configs.isEmpty
            let cfgSub = NSMenu()
            for c in configs {
                cfgSub.addItem(ClosureMenuItem(title: "\(c.name)    \(c.summary)", action: { [weak self] in self?.applyConfig(a, c) }))
            }
            cfgItem.submenu = cfgSub
            let toggleItem = ClosureMenuItem(title: a.adminEnabled ? "Disattiva" : "Attiva", action: { [weak self] in self?.setEnabled(a, !a.adminEnabled) })
            toggleItem.isEnabled = !busy

            sub.addItem(setItem)
            sub.addItem(dhcpItem)
            sub.addItem(cfgItem)
            sub.addItem(.separator())
            sub.addItem(toggleItem)
            item.submenu = sub
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let cfgRoot = NSMenuItem(title: "Configurazioni salvate", action: nil, keyEquivalent: "")
        let cfgRootMenu = NSMenu()
        if configs.isEmpty {
            let none = NSMenuItem(title: "(nessuna)", action: nil, keyEquivalent: "")
            none.isEnabled = false
            cfgRootMenu.addItem(none)
        }
        for c in configs {
            let ci = NSMenuItem(title: "\(c.name)    \(c.summary)", action: nil, keyEquivalent: "")
            let ciSub = NSMenu()
            for a in adapters where a.adminEnabled {
                let ai = ClosureMenuItem(title: "Applica a \(a.name)", action: { [weak self] in self?.applyConfig(a, c) })
                ai.image = AppIcon.dotFor(a)
                ai.isEnabled = !busy
                ciSub.addItem(ai)
            }
            ci.submenu = ciSub
            cfgRootMenu.addItem(ci)
        }
        cfgRootMenu.addItem(.separator())
        cfgRootMenu.addItem(ClosureMenuItem(title: "Gestisci...", action: { [weak self] in self?.flyout.showFlyout(1) }))
        cfgRoot.submenu = cfgRootMenu
        menu.addItem(cfgRoot)

        menu.addItem(.separator())
        let startupItem = ClosureMenuItem(title: "Avvia con il Mac", action: { [weak self] in self?.toggleStartup() })
        startupItem.state = startupEnabled ? .on : .off
        menu.addItem(startupItem)
        menu.addItem(ClosureMenuItem(title: "Esci", action: { [weak self] in self?.exitApp() }))
        return menu
    }

    /// Solo diagnostica (NETSWITCH_DEBUG=1): porta l'interfaccia in uno stato per gli screenshot.
    func demo(_ mode: String?) {
        guard let mode = mode, !adapters.isEmpty else { return }
        let a = adapters.first(where: { $0.addresses.count > 1 }) ?? adapters[0]
        switch mode {
        case "expand": flyout.demoExpand(a)
        case "editor": flyout.openApplyEditor(a)
        case "configs": flyout.showFlyout(1)
        case "confirm": setEnabled(a, false)
        case "error": flyout.showResult(false, "Imposta IP su Ethernet non riuscita.\n\nL'oggetto esiste già.")
        default: break
        }
    }

    func snap(_ path: String) { flyout.snap(to: path) }

    // ================================================================== uscita

    func exitApp() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
        flyout.forceClose()
        NSStatusBar.system.removeStatusItem(statusItem)
        NSApp.terminate(nil)
    }
}
