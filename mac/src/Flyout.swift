import AppKit

/// Finestra compatta "a comparsa" ancorata alla status bar, vicino all'icona di NetSwitch.
/// Porting di Flyout.cs: su macOS la barra dei menu è sempre in alto (a differenza della
/// taskbar di Windows che può stare sopra o sotto), quindi il pannello compare sempre
/// appena sotto l'icona. Le animazioni di scorrimento della versione Windows sono state
/// semplificate in semplici dissolvenze (fade), più semplici da rendere in modo affidabile
/// con AppKit.
class Flyout: NSWindow, NSMenuDelegate {
    static let panelWidth: CGFloat = 380

    weak var appRef: Controller?
    /// Fornisce il rettangolo (in coordinate schermo) dell'icona nella status bar, per
    /// posizionare il pannello. Impostato dal Controller dopo la creazione dello status item.
    var anchorProvider: (() -> NSRect?)?

    private let panel = NSView()
    private let layers = NSView()
    private let pageHost = NSView()
    private var mainPage: NSView!
    private var ifScroll: NSScrollView!
    private var cfgScroll: NSScrollView!
    private let ifList = NSStackView()
    private let cfgList = NSStackView()
    private var tabSeg: SegmentedControl!
    private let ifSummary = UI.text("", 12, Theme.fg2)
    private let onlyConnected = UI.switchControl(UI.text("Solo connesse", 12, Theme.fg2))

    private let snack = NSView()
    private let snackIcon = UI.icon(UI.Glyph.check, 14, Theme.success)
    private let snackText = UI.wrappingText("", 12.5, Theme.fg)
    private var snackCloseBtn: StyledButton!
    private var snackTimer: Timer?

    private let overlay = NSView()

    private var groupHeaders: [NSTextField?] = [nil, nil, nil]
    private var cards: [String: AdapterCardView] = [:]
    private var expandedAdapters: Set<String> = []
    private var expandedConfigs: Set<String> = []
    private var autoRefreshTimer: Timer?
    private var lastHidden = Date.distantPast
    private var openMenus: [NSMenu] = []
    private var currentPageIsMain = true

    init(app: Controller) {
        self.appRef = app
        let rect = NSRect(x: 0, y: 0, width: Flyout.panelWidth, height: 600)
        super.init(contentRect: rect, styleMask: [.borderless], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        panel.wantsLayer = true
        panel.layer?.cornerRadius = 8
        panel.layer?.borderWidth = 1
        panel.layer?.backgroundColor = Theme.bg.cgColor
        panel.layer?.borderColor = Theme.cardBorder.cgColor
        contentView = panel

        layers.translatesAutoresizingMaskIntoConstraints = false
        layers.wantsLayer = true
        layers.layer?.cornerRadius = 8
        layers.layer?.masksToBounds = true
        panel.addSubview(layers)
        pin(layers, to: panel)

        pageHost.translatesAutoresizingMaskIntoConstraints = false
        layers.addSubview(pageHost)
        pin(pageHost, to: layers)

        mainPage = buildMainPage()
        setPage(mainPage, animated: false)

        buildSnack()

        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.isHidden = true
        layers.addSubview(overlay)
        pin(overlay, to: layers)

        NotificationCenter.default.addObserver(self, selector: #selector(onResignKey), name: NSWindow.didResignKeyNotification, object: self)

        updateAdapters()
        buildConfigs()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    @objc private func onResignKey() { hideFlyout() }

    private func pin(_ child: NSView, to parent: NSView) {
        NSLayoutConstraint.activate([
            child.topAnchor.constraint(equalTo: parent.topAnchor),
            child.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
            child.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            child.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
        ])
    }

    /// Chiusura con Esc: usa il meccanismo standard di AppKit (nessun monitor di eventi necessario).
    override func cancelOperation(_ sender: Any?) {
        if !overlay.isHidden { closeOverlay() }
        else if !currentPageIsMain { showMain(-1) }
        else { hideFlyout() }
    }

    // ================================================================== visibilità e posizione

    func toggle() {
        if isVisible { hideFlyout() }
        else if Date().timeIntervalSince(lastHidden) > 0.35 { showFlyout() }
    }

    func showFlyout(_ tab: Int = -1) {
        if tab == 0 { tabSeg.select(0); onTabChanged(0) }
        if tab == 1 { tabSeg.select(1); onTabChanged(1) }
        let wasVisible = isVisible
        positionNearTray()
        if !wasVisible {
            alphaValue = 0
            orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.18
                self.animator().alphaValue = 1
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        startAutoRefresh()
        appRef?.refresh()
    }

    func hideFlyout() {
        guard isVisible else { return }
        if Program.noAutoHide { return }
        for m in openMenus { m.cancelTracking() }
        lastHidden = Date()
        autoRefreshTimer?.invalidate()
        orderOut(nil)
    }

    func forceClose() {
        autoRefreshTimer?.invalidate()
        orderOut(nil)
        close()
    }

    private func startAutoRefresh() {
        autoRefreshTimer?.invalidate()
        guard !Program.fake else { return }
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self = self, let app = self.appRef, !app.busy else { return }
            app.refresh()
        }
    }

    private func positionNearTray() {
        let gap: CGFloat = 10
        let anchor = anchorProvider?() ?? defaultAnchor()
        let screen = NSScreen.screens.first { $0.frame.contains(NSPoint(x: anchor.midX, y: anchor.midY)) } ?? NSScreen.main ?? NSScreen.screens[0]
        let vis = screen.visibleFrame
        let panelH = min(620, vis.height - 2 * gap)
        var frame = NSRect(x: 0, y: 0, width: Flyout.panelWidth, height: panelH)
        var x = anchor.midX - frame.width / 2
        x = max(vis.minX + gap, min(x, vis.maxX - gap - frame.width))
        let topY = min(anchor.minY, vis.maxY) - gap
        let y = max(vis.minY + gap, topY - frame.height)
        frame.origin = NSPoint(x: x, y: y)
        setFrame(frame, display: true)
    }

    private func defaultAnchor() -> NSRect {
        let screen = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return NSRect(x: screen.maxX - 40, y: screen.maxY - 24, width: 24, height: 24)
    }

    /// Solo diagnostica: salva il pannello come PNG.
    func snap(to path: String) {
        guard let cv = contentView, let rep = cv.bitmapImageRepForCachingDisplay(in: cv.bounds) else { return }
        cv.cacheDisplay(in: cv.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: URL(fileURLWithPath: path))
    }

    // ================================================================== navigazione

    private func setPage(_ view: NSView, animated: Bool) {
        for v in pageHost.subviews { v.removeFromSuperview() }
        view.translatesAutoresizingMaskIntoConstraints = false
        view.wantsLayer = true
        pageHost.addSubview(view)
        pin(view, to: pageHost)
        if animated {
            view.alphaValue = 0
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.18
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                view.animator().alphaValue = 1
            }
        }
    }

    func showMain(_ tab: Int) {
        if tab == 0 { tabSeg.select(0); onTabChanged(0) }
        if tab == 1 { tabSeg.select(1); onTabChanged(1) }
        if !currentPageIsMain {
            currentPageIsMain = true
            setPage(mainPage, animated: true)
        }
    }

    func openApplyEditor(_ a: AdapterInfo) {
        showFlyout()
        guard let app = appRef else { return }
        currentPageIsMain = false
        setPage(EditorPage(fly: self, app: app, kind: .apply, adapter: a, editing: nil, initial: nil), animated: true)
    }

    func openConfigEditor(_ editing: SavedConfig?, _ initial: SavedConfig?) {
        showFlyout()
        guard let app = appRef else { return }
        currentPageIsMain = false
        setPage(EditorPage(fly: self, app: app, kind: .config, adapter: nil, editing: editing, initial: initial ?? editing), animated: true)
    }

    // ================================================================== pagina principale

    private func buildMainPage() -> NSView {
        let page = NSView()
        page.wantsLayer = true
        page.translatesAutoresizingMaskIntoConstraints = false
        page.widthAnchor.constraint(equalToConstant: Flyout.panelWidth).isActive = true

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 0
        root.distribution = .fill
        root.translatesAutoresizingMaskIntoConstraints = false
        page.addSubview(root)
        pin(root, to: page)

        // ---------------------------------------------------- intestazione
        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 0
        header.edgeInsets = NSEdgeInsets(top: 12, left: 16, bottom: 8, right: 8)
        header.widthAnchor.constraint(equalToConstant: Flyout.panelWidth).isActive = true
        let logo = UI.logo(26)
        header.addArrangedSubview(logo)
        header.setCustomSpacing(9, after: logo)
        header.addArrangedSubview(UI.text("NetSwitch", 14, Theme.fg, weight: .semibold))
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        header.addArrangedSubview(spacer)
        let refreshBtn = UI.iconButton(UI.Glyph.refresh, "Aggiorna", { [weak self] in
            self?.appRef?.refresh(); self?.toast("Aggiornato")
        })
        header.addArrangedSubview(refreshBtn)
        let moreBtn = UI.iconButton(UI.Glyph.more, "Altre opzioni", nil)
        moreBtn.onClick = { [weak self, weak moreBtn] in
            guard let self = self, let moreBtn = moreBtn else { return }
            self.showMoreMenu(moreBtn)
        }
        header.addArrangedSubview(moreBtn)
        root.addArrangedSubview(header)

        // ---------------------------------------------------- schede
        let segWrap = NSView()
        segWrap.translatesAutoresizingMaskIntoConstraints = false
        segWrap.widthAnchor.constraint(equalToConstant: Flyout.panelWidth).isActive = true
        tabSeg = UI.segmented(["Interfacce", "Configurazioni"], initial: 0, onChange: { [weak self] i in self?.onTabChanged(i) })
        tabSeg.translatesAutoresizingMaskIntoConstraints = false
        tabSeg.heightAnchor.constraint(equalToConstant: 30).isActive = true
        segWrap.addSubview(tabSeg)
        NSLayoutConstraint.activate([
            tabSeg.leadingAnchor.constraint(equalTo: segWrap.leadingAnchor, constant: 16),
            tabSeg.trailingAnchor.constraint(equalTo: segWrap.trailingAnchor, constant: -16),
            tabSeg.topAnchor.constraint(equalTo: segWrap.topAnchor),
            tabSeg.bottomAnchor.constraint(equalTo: segWrap.bottomAnchor, constant: -10),
        ])
        root.addArrangedSubview(segWrap)

        // ---------------------------------------------------- contenuto (interfacce / configurazioni)
        let contentContainer = NSView()
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.widthAnchor.constraint(equalToConstant: Flyout.panelWidth).isActive = true
        root.addArrangedSubview(contentContainer)

        ifScroll = buildIfScroll()
        cfgScroll = buildCfgScroll()
        ifScroll.translatesAutoresizingMaskIntoConstraints = false
        cfgScroll.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(ifScroll)
        contentContainer.addSubview(cfgScroll)
        pin(ifScroll, to: contentContainer)
        pin(cfgScroll, to: contentContainer)
        cfgScroll.isHidden = true

        return page
    }

    private func onTabChanged(_ i: Int) {
        ifScroll.isHidden = (i != 0)
        cfgScroll.isHidden = (i != 1)
    }

    private func buildIfScroll() -> NSScrollView {
        let ifPanel = NSStackView()
        ifPanel.orientation = .vertical
        ifPanel.alignment = .leading
        ifPanel.spacing = 0
        ifPanel.edgeInsets = NSEdgeInsets(top: 2, left: 16, bottom: 16, right: 12)

        let ifTop = NSStackView()
        ifTop.orientation = .horizontal
        ifTop.alignment = .centerY
        ifTop.addArrangedSubview(ifSummary)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        ifTop.addArrangedSubview(spacer)
        onlyConnected.onToggle = { [weak self] _ in self?.updateAdapters() }
        ifTop.addArrangedSubview(onlyConnected)
        ifTop.widthAnchor.constraint(equalToConstant: 352).isActive = true
        ifPanel.addArrangedSubview(ifTop)
        ifPanel.setCustomSpacing(10, after: ifTop)

        ifList.orientation = .vertical
        ifList.alignment = .leading
        ifList.spacing = 6
        ifPanel.addArrangedSubview(ifList)

        return UI.scroll(ifPanel)
    }

    private func buildCfgScroll() -> NSScrollView {
        let cfgPanel = NSStackView()
        cfgPanel.orientation = .vertical
        cfgPanel.alignment = .leading
        cfgPanel.spacing = 0
        cfgPanel.edgeInsets = NSEdgeInsets(top: 2, left: 16, bottom: 16, right: 12)

        let newBtn = UI.iconTextButton(.plain, UI.Glyph.add, "Nuova configurazione", glyphAfter: false, { [weak self] in
            self?.openConfigEditor(nil, nil)
        })
        newBtn.widthAnchor.constraint(equalToConstant: 352).isActive = true
        cfgPanel.addArrangedSubview(newBtn)
        cfgPanel.setCustomSpacing(8, after: newBtn)

        cfgList.orientation = .vertical
        cfgList.alignment = .leading
        cfgList.spacing = 6
        cfgPanel.addArrangedSubview(cfgList)

        return UI.scroll(cfgPanel)
    }

    // ================================================================== interfacce

    func updateAdapters() {
        guard let app = appRef else { return }
        let only = onlyConnected.isOn
        let list = app.adapters.filter { !only || $0.isConnected }
        var ordered: [NSView] = []
        var seen = Set<String>()
        let groupNames = ["Connesse", "Non connesse", "Disattivate"]
        var lastGroup = -1
        for a in list {
            let g = a.isConnected ? 0 : (a.adminEnabled ? 1 : 2)
            if g != lastGroup {
                lastGroup = g
                let n = list.filter { ($0.isConnected ? 0 : ($0.adminEnabled ? 1 : 2)) == g }.count
                let header = groupHeaderView(g)
                header.stringValue = "\(groupNames[g])  ·  \(n)"
                ordered.append(header)
            }
            let key = a.key
            let card: AdapterCardView
            if let existing = cards[key] { card = existing }
            else { card = AdapterCardView(fly: self, app: app); cards[key] = card }
            card.update(a, expanded: expandedAdapters.contains(key))
            ordered.append(card)
            seen.insert(key)
        }
        for k in cards.keys where !seen.contains(k) { cards.removeValue(forKey: k) }

        for v in ifList.arrangedSubviews { ifList.removeArrangedSubview(v); v.removeFromSuperview() }
        if ordered.isEmpty {
            let empty = UI.text(only ? "Nessuna interfaccia connessa." : "Nessuna interfaccia trovata.", 12.5, Theme.fg2)
            ifList.addArrangedSubview(empty)
        } else {
            for v in ordered { ifList.addArrangedSubview(v) }
        }
        let conn = app.adapters.filter { $0.isConnected }.count
        ifSummary.stringValue = "\(conn) " + (conn == 1 ? "connessa" : "connesse") + " su \(app.adapters.count)"
    }

    private func groupHeaderView(_ g: Int) -> NSTextField {
        if let h = groupHeaders[g] { return h }
        let h = UI.text("", 11.5, Theme.fg3, weight: .semibold)
        groupHeaders[g] = h
        return h
    }

    func toggleAdapterExpanded(_ a: AdapterInfo, _ card: AdapterCardView) {
        let k = a.key
        let exp = !expandedAdapters.contains(k)
        if exp { expandedAdapters.insert(k) } else { expandedAdapters.remove(k) }
        card.setExpanded(exp, animate: true)
    }

    func demoExpand(_ a: AdapterInfo) {
        if let c = cards[a.key] { toggleAdapterExpanded(a, c) }
    }

    func showApplyConfigMenu(_ target: NSView, _ a: AdapterInfo) {
        guard let app = appRef else { return }
        let menu = newMenu()
        if app.configs.isEmpty {
            let none = NSMenuItem(title: "Nessuna configurazione salvata", action: nil, keyEquivalent: "")
            none.isEnabled = false
            menu.addItem(none)
            menu.addItem(.separator())
            menu.addItem(UI.menuItem("Nuova configurazione...", { [weak self] in self?.openConfigEditor(nil, nil) }))
        }
        for c in app.configs {
            menu.addItem(menuItem2(c.name, c.summary, { app.applyConfig(a, c) }))
        }
        UI.showMenu(menu, relativeTo: target)
    }

    func showApplyToMenu(_ target: NSView, _ c: SavedConfig) {
        guard let app = appRef else { return }
        let menu = newMenu()
        let enabled = app.adapters.filter { $0.adminEnabled }
        if enabled.isEmpty {
            let none = NSMenuItem(title: "Nessuna interfaccia attiva", action: nil, keyEquivalent: "")
            none.isEnabled = false
            menu.addItem(none)
        }
        for a in enabled {
            let mi = menuItem2(a.name, a.addresses.first ?? a.statusText, { app.applyConfig(a, c) })
            mi.image = AppIcon.dotFor(a)
            menu.addItem(mi)
        }
        UI.showMenu(menu, relativeTo: target)
    }

    private func showMoreMenu(_ target: NSView) {
        guard let app = appRef else { return }
        let menu = newMenu()
        let startupItem = ClosureMenuItem(title: "Avvia con il Mac", action: { [weak app] in app?.toggleStartup() })
        startupItem.state = app.startupEnabled ? .on : .off
        menu.addItem(startupItem)
        menu.addItem(UI.menuItem("Apri cartella configurazioni", {
            try? FileManager.default.createDirectory(atPath: ConfigStore.folder, withIntermediateDirectories: true)
            NSWorkspace.shared.open(URL(fileURLWithPath: ConfigStore.folder))
        }))
        menu.addItem(.separator())
        menu.addItem(UI.menuItem("Esci da NetSwitch", { [weak app] in app?.exitApp() }))
        UI.showMenu(menu, relativeTo: target)
    }

    private func newMenu() -> NSMenu {
        let m = NSMenu()
        m.delegate = self
        openMenus.append(m)
        return m
    }

    func menuDidClose(_ menu: NSMenu) {
        openMenus.removeAll { $0 === menu }
    }

    private func menuItem2(_ title: String, _ subtitle: String?, _ action: @escaping () -> Void) -> NSMenuItem {
        let mi = ClosureMenuItem(title: title, action: action)
        if let subtitle = subtitle, !subtitle.isEmpty {
            let s = NSMutableAttributedString(string: title + "\n", attributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: Theme.fg])
            s.append(NSAttributedString(string: subtitle, attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: Theme.fg2]))
            mi.attributedTitle = s
        }
        return mi
    }

    // ================================================================== configurazioni

    func buildConfigs() {
        guard let app = appRef else { return }
        for v in cfgList.arrangedSubviews { cfgList.removeArrangedSubview(v); v.removeFromSuperview() }
        if app.configs.isEmpty {
            let empty = UI.wrappingText("Nessuna configurazione salvata.\nCreane una qui oppure da una interfaccia con «Salva».", 12.5, Theme.fg2)
            cfgList.addArrangedSubview(empty)
        }
        for (i, c) in app.configs.enumerated() {
            let card = ConfigCardView(fly: self, app: app, c: c, index: i, count: app.configs.count, expanded: expandedConfigs.contains(c.name))
            cfgList.addArrangedSubview(card)
        }
    }

    func toggleConfigExpanded(_ c: SavedConfig, _ card: ConfigCardView) {
        let exp = !expandedConfigs.contains(c.name)
        if exp { expandedConfigs.insert(c.name) } else { expandedConfigs.remove(c.name) }
        card.setExpanded(exp, animate: true)
    }

    // ================================================================== conferme

    func confirm(title: String, message: String, okText: String, danger: Bool, onOk: @escaping () -> Void) {
        if !isVisible { showFlyout() }
        overlay.subviews.forEach { $0.removeFromSuperview() }

        let dim = HoverableView()
        dim.wantsLayer = true
        dim.layer?.backgroundColor = Theme.overlay.cgColor
        dim.translatesAutoresizingMaskIntoConstraints = false
        dim.onClick = { [weak self] in self?.closeOverlay() }
        overlay.addSubview(dim)
        pin(dim, to: overlay)

        let card = NSView()
        card.wantsLayer = true
        card.layer?.cornerRadius = 8
        card.layer?.borderWidth = 1
        card.layer?.backgroundColor = Theme.menuBg.cgColor
        card.layer?.borderColor = Theme.cardBorder.cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        card.widthAnchor.constraint(equalToConstant: 300).isActive = true
        overlay.addSubview(card)
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
        ])

        let sp = NSStackView()
        sp.orientation = .vertical
        sp.alignment = .leading
        sp.spacing = 8
        sp.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(sp)
        NSLayoutConstraint.activate([
            sp.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            sp.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
            sp.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            sp.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
        ])
        let titleLabel = UI.wrappingText(title, 15, Theme.fg)
        titleLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        sp.addArrangedSubview(titleLabel)
        sp.addArrangedSubview(UI.wrappingText(message, 12.5, Theme.fg2))
        sp.setCustomSpacing(20, after: sp.arrangedSubviews.last!)

        let btns = NSStackView()
        btns.orientation = .horizontal
        btns.distribution = .fillEqually
        btns.spacing = 8
        let cancelBtn = UI.button(.plain, "Annulla", { [weak self] in self?.closeOverlay() })
        let okBtn = UI.button(danger ? .danger : .accent, okText, { [weak self] in self?.closeOverlay(); onOk() })
        btns.addArrangedSubview(cancelBtn)
        btns.addArrangedSubview(okBtn)
        btns.translatesAutoresizingMaskIntoConstraints = false
        btns.widthAnchor.constraint(equalToConstant: 260).isActive = true
        sp.addArrangedSubview(btns)

        overlay.isHidden = false
        overlay.alphaValue = 0
        overlay.wantsLayer = true
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            self.overlay.animator().alphaValue = 1
        }
        makeFirstResponder(okBtn)
    }

    private func closeOverlay() {
        overlay.isHidden = true
        overlay.subviews.forEach { $0.removeFromSuperview() }
    }

    // ================================================================== notifiche

    func showBusy(_ text: String) { setSnack(UI.Glyph.sync, Theme.accent, text + "…", autoHide: 0, closable: false, spin: true) }

    func showResult(_ ok: Bool, _ text: String) {
        if ok { setSnack(UI.Glyph.check, Theme.success, text, autoHide: 6, closable: true, spin: false) }
        else { setSnack(UI.Glyph.error, Theme.danger, text, autoHide: 0, closable: true, spin: false) }
    }

    func toast(_ text: String) { setSnack(UI.Glyph.info, Theme.accent, text, autoHide: 2.5, closable: true, spin: false) }

    func warn(_ text: String) { setSnack(UI.Glyph.warning, Theme.warning, text, autoHide: 5, closable: true, spin: false) }

    private func buildSnack() {
        snack.wantsLayer = true
        snack.layer?.cornerRadius = 6
        snack.layer?.borderWidth = 1
        snack.layer?.backgroundColor = Theme.menuBg.cgColor
        snack.layer?.borderColor = Theme.cardBorder.cgColor
        snack.isHidden = true
        snack.translatesAutoresizingMaskIntoConstraints = false
        layers.addSubview(snack)
        NSLayoutConstraint.activate([
            snack.leadingAnchor.constraint(equalTo: layers.leadingAnchor, constant: 12),
            snack.trailingAnchor.constraint(equalTo: layers.trailingAnchor, constant: -12),
            snack.bottomAnchor.constraint(equalTo: layers.bottomAnchor, constant: -12),
        ])
        snackCloseBtn = UI.iconButton(UI.Glyph.close, "Chiudi", { [weak self] in self?.hideSnack() })
        let row = NSStackView(views: [snackIcon, snackText, snackCloseBtn])
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        snack.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: snack.topAnchor, constant: 9),
            row.bottomAnchor.constraint(equalTo: snack.bottomAnchor, constant: -9),
            row.leadingAnchor.constraint(equalTo: snack.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: snack.trailingAnchor, constant: -6),
        ])
    }

    private func setSnack(_ glyph: String, _ color: NSColor, _ text: String, autoHide: TimeInterval, closable: Bool, spin: Bool) {
        snackTimer?.invalidate()
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        snackIcon.image = NSImage(systemSymbolName: glyph, accessibilityDescription: nil)?.withSymbolConfiguration(config)
        snackIcon.contentTintColor = color
        snackText.stringValue = text
        snackCloseBtn.isHidden = !closable
        snackIcon.wantsLayer = true
        if spin {
            let anim = CABasicAnimation(keyPath: "transform.rotation.z")
            anim.fromValue = 0
            anim.toValue = Double.pi * 2
            anim.duration = 1
            anim.repeatCount = .infinity
            snackIcon.layer?.add(anim, forKey: "spin")
        } else {
            snackIcon.layer?.removeAnimation(forKey: "spin")
        }
        if snack.isHidden {
            snack.isHidden = false
            snack.alphaValue = 0
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                self.snack.animator().alphaValue = 1
            }
        }
        if autoHide > 0 {
            snackTimer = Timer.scheduledTimer(withTimeInterval: autoHide, repeats: false) { [weak self] _ in self?.hideSnack() }
        }
    }

    private func hideSnack() {
        snackTimer?.invalidate()
        snackIcon.layer?.removeAnimation(forKey: "spin")
        snack.isHidden = true
    }

    func copyToClipboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        toast("Copiato: " + value)
    }
}
