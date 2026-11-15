import AppKit

/// Pagina interna al flyout per impostare l'IP o creare/modificare una configurazione.
/// Porting di EditorPage.cs.
class EditorPage: NSView {
    enum Kind { case apply, config }

    private weak var fly: Flyout?
    private weak var app: Controller?
    private let kind: Kind
    private let adapter: AdapterInfo?
    private let editing: SavedConfig?

    private var txtName: NSTextField!
    private let txtIp = UI.input("192.168.1.10/24")
    private let txtGw = UI.input("facoltativo")
    private let txtDns1 = UI.input("facoltativo")
    private let txtDns2 = UI.input("facoltativo")
    private var seg: SegmentedControl!
    private var swSave: SwitchControl?
    private let staticFields = NSStackView()
    private let msg = UI.wrappingText("", 12.5, Theme.danger)
    private var gwWarned = false
    private var ipChangeForwarder: ChangeForwarder?
    private var gwChangeForwarder: ChangeForwarder?

    init(fly: Flyout, app: Controller, kind: Kind, adapter: AdapterInfo?, editing: SavedConfig?, initial: SavedConfig?) {
        self.fly = fly
        self.app = app
        self.kind = kind
        self.adapter = adapter
        self.editing = editing
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 380).isActive = true

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 0
        root.translatesAutoresizingMaskIntoConstraints = false
        addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: topAnchor), root.bottomAnchor.constraint(equalTo: bottomAnchor),
            root.leadingAnchor.constraint(equalTo: leadingAnchor), root.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        // ---------------------------------------------------- intestazione
        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 6
        header.edgeInsets = NSEdgeInsets(top: 10, left: 8, bottom: 6, right: 16)
        let back = UI.iconButton(UI.Glyph.back, "Indietro (Esc)", { [weak self] in self?.fly?.showMain(-1) })
        header.addArrangedSubview(back)
        let titles = NSStackView()
        titles.orientation = .vertical
        titles.alignment = .leading
        titles.spacing = 1
        let title = kind == .apply ? "Imposta IP" : (editing == nil ? "Nuova configurazione" : "Modifica configurazione")
        titles.addArrangedSubview(UI.text(title, 15, Theme.fg, weight: .semibold))
        let subtitle = kind == .apply ? "\(adapter?.name ?? "")  ·  \(adapter?.description ?? "")" : "Configurazione salvata"
        titles.addArrangedSubview(UI.text(subtitle, 12, Theme.fg2))
        header.addArrangedSubview(titles)
        header.widthAnchor.constraint(equalToConstant: 380).isActive = true
        root.addArrangedSubview(header)

        // ---------------------------------------------------- campi
        let form = NSStackView()
        form.orientation = .vertical
        form.alignment = .leading
        form.spacing = 14
        form.edgeInsets = NSEdgeInsets(top: 4, left: 16, bottom: 12, right: 12)
        form.widthAnchor.constraint(equalToConstant: 380).isActive = true

        if kind == .apply, !app.configs.isEmpty {
            let load = UI.iconTextButton(.ghost, UI.Glyph.down, "Carica da configurazione", glyphAfter: true, nil)
            load.tint = Theme.accent
            load.onClick = { [weak self] in self?.showLoadMenu(load) }
            form.addArrangedSubview(load)
            form.setCustomSpacing(10, after: load)
        }

        if kind == .config {
            txtName = UI.input("es. Ufficio, Laboratorio, Cliente X")
            form.addArrangedSubview(fullWidthField("Nome", txtName))
        } else {
            txtName = UI.input("Nome della configurazione")
        }

        seg = UI.segmented(["IP statico", "Automatico (DHCP)"], initial: 0, onChange: { [weak self] _ in self?.updateMode() })
        form.addArrangedSubview(fullWidthField("Modalità", seg))

        staticFields.orientation = .vertical
        staticFields.alignment = .leading
        staticFields.spacing = 14
        staticFields.addArrangedSubview(fullWidthField("Indirizzo IP / subnet", txtIp))
        let hint = UI.wrappingText("Subnet anche come 255.255.255.0 · più indirizzi separati da virgola", 11.5, Theme.fg3)
        hint.preferredMaxLayoutWidth = 352
        staticFields.addArrangedSubview(hint)
        staticFields.setCustomSpacing(4, after: staticFields.arrangedSubviews[0])
        staticFields.addArrangedSubview(fullWidthField("Gateway", txtGw))
        let dnsGrid = NSStackView(views: [field("DNS primario", txtDns1), field("DNS secondario", txtDns2)])
        dnsGrid.orientation = .horizontal
        dnsGrid.distribution = .fillEqually
        dnsGrid.spacing = 8
        dnsGrid.translatesAutoresizingMaskIntoConstraints = false
        dnsGrid.widthAnchor.constraint(equalToConstant: 352).isActive = true
        staticFields.addArrangedSubview(dnsGrid)
        form.addArrangedSubview(staticFields)

        if kind == .apply {
            let sw = UI.switchControl(UI.text("Salva anche come configurazione", 12.5, Theme.fg))
            sw.onToggle = { [weak self] on in self?.txtName.isHidden = !on; if on { self?.window?.makeFirstResponder(self?.txtName) } }
            swSave = sw
            form.addArrangedSubview(sw)
            form.setCustomSpacing(18, after: staticFields)
            txtName.isHidden = true
            txtName.translatesAutoresizingMaskIntoConstraints = false
            txtName.heightAnchor.constraint(equalToConstant: 30).isActive = true
            txtName.widthAnchor.constraint(equalToConstant: 352).isActive = true
            form.addArrangedSubview(txtName)
        }

        msg.isHidden = true
        form.addArrangedSubview(msg)

        let scroll = UI.scroll(form)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        root.addArrangedSubview(scroll)
        scroll.widthAnchor.constraint(equalToConstant: 380).isActive = true
        scroll.setContentHuggingPriority(.defaultLow, for: .vertical)

        // ---------------------------------------------------- pulsanti
        let footer = NSStackView()
        footer.orientation = .horizontal
        footer.distribution = .fillEqually
        footer.spacing = 8
        footer.edgeInsets = NSEdgeInsets(top: 6, left: 16, bottom: 16, right: 16)
        footer.widthAnchor.constraint(equalToConstant: 380).isActive = true
        let cancel = UI.button(.plain, "Annulla", { [weak self] in self?.fly?.showMain(-1) })
        let ok = UI.button(.accent, kind == .apply ? "Applica" : "Salva", { [weak self] in self?.submit() })
        footer.addArrangedSubview(cancel)
        footer.addArrangedSubview(ok)
        root.addArrangedSubview(footer)

        gwChangeForwarder = ChangeForwarder { [weak self] in self?.gwWarned = false }
        ipChangeForwarder = ChangeForwarder { [weak self] in self?.gwWarned = false }
        txtGw.delegate = gwChangeForwarder
        txtIp.delegate = ipChangeForwarder

        // ---------------------------------------------------- valori iniziali
        if kind == .apply, let adapter = adapter { loadFromAdapter(adapter) }
        else if let initial = initial { loadConfig(initial) }
        if kind == .config, let initial = initial { txtName.stringValue = initial.name }
        updateMode()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let first: NSTextField = (self.kind == .config && self.txtName.stringValue.isEmpty) ? self.txtName : self.txtIp
            if first.isEnabled { self.window?.makeFirstResponder(first); first.currentEditor()?.selectAll(nil) }
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Etichetta + controllo impilati verticalmente; la larghezza segue il contenitore
    /// (va vincolata esplicitamente dal chiamante, vedi fullWidthField).
    private func field(_ label: String, _ control: NSView) -> NSView {
        let sp = NSStackView()
        sp.orientation = .vertical
        sp.alignment = .leading
        sp.spacing = 5
        let l = UI.text(label, 12, Theme.fg2)
        sp.addArrangedSubview(l)
        control.translatesAutoresizingMaskIntoConstraints = false
        control.heightAnchor.constraint(equalToConstant: 30).isActive = true
        sp.addArrangedSubview(control)
        control.widthAnchor.constraint(equalTo: sp.widthAnchor).isActive = true
        return sp
    }

    /// Come field(), ma occupa l'intera larghezza di una riga del form (352pt = 380 - margini 16 + 12).
    private func fullWidthField(_ label: String, _ control: NSView) -> NSView {
        let sp = field(label, control)
        sp.translatesAutoresizingMaskIntoConstraints = false
        sp.widthAnchor.constraint(equalToConstant: 352).isActive = true
        return sp
    }

    private func updateMode() {
        let st = seg.selectedIndex == 0
        staticFields.alphaValue = st ? 1 : 0.5
        for tb in [txtIp, txtGw, txtDns1, txtDns2] { tb.isEnabled = st }
        hideMsg()
    }

    private func loadFromAdapter(_ a: AdapterInfo) {
        seg.select(a.dhcp ? 1 : 0)
        txtIp.stringValue = a.addresses.isEmpty ? "" : (a.dhcp ? a.addresses[0] : a.addresses.joined(separator: ", "))
        txtGw.stringValue = a.gateways.first ?? ""
        txtDns1.stringValue = !a.dhcp && a.dns.count > 0 ? a.dns[0] : ""
        txtDns2.stringValue = !a.dhcp && a.dns.count > 1 ? a.dns[1] : ""
    }

    private func loadConfig(_ c: SavedConfig) {
        seg.select(c.dhcp ? 1 : 0)
        txtIp.stringValue = c.address
        txtGw.stringValue = c.gateway
        txtDns1.stringValue = c.dns1
        txtDns2.stringValue = c.dns2
        hideMsg()
    }

    private func showLoadMenu(_ target: NSView) {
        guard let app = app, let adapter = adapter else { return }
        let menu = NSMenu()
        menu.addItem(UI.menuItem("Valori attuali dell'interfaccia", { [weak self] in self?.loadFromAdapter(adapter) }))
        menu.addItem(.separator())
        for c in app.configs {
            menu.addItem(UI.menuItem("\(c.name)   —   \(c.summary)", { [weak self] in self?.loadConfig(c) }))
        }
        UI.showMenu(menu, relativeTo: target)
    }

    private func showMsg(_ text: String, warning: Bool) {
        msg.stringValue = text
        msg.textColor = warning ? Theme.warning : Theme.danger
        msg.isHidden = false
    }
    private func hideMsg() { msg.isHidden = true }

    private func submit() {
        guard let app = app else { return }
        let c = SavedConfig()
        c.dhcp = seg.selectedIndex == 1
        let save = kind == .config || (swSave?.isOn == true)
        c.name = txtName.stringValue.trimmingCharacters(in: .whitespaces)
        if save {
            if let nErr = app.validateConfigName(c.name, editing) {
                showMsg(nErr, warning: false); window?.makeFirstResponder(txtName); return
            }
        }

        if !c.dhcp {
            let (parsed, err) = NetOps.tryParseCidrList(txtIp.stringValue)
            guard let addrs = parsed else {
                showMsg(err ?? "Indirizzo non valido.", warning: false); window?.makeFirstResponder(txtIp); return
            }
            c.address = NetOps.formatCidrList(addrs)

            var gw = txtGw.stringValue.trimmingCharacters(in: .whitespaces)
            if !gw.isEmpty {
                if !NetOps.isValidIPv4(gw) {
                    showMsg("Gateway non valido: '\(gw)'.", warning: false); window?.makeFirstResponder(txtGw); return
                }
                gw = NetOps.fromUInt(NetOps.toUInt(gw))
                if addrs.contains(where: { $0.key == gw }) {
                    showMsg("Il gateway non può coincidere con un indirizzo dell'interfaccia.", warning: false)
                    window?.makeFirstResponder(txtGw); return
                }
                if !addrs.contains(where: { NetOps.sameSubnet($0.key, gw, $0.value) }) && !gwWarned {
                    gwWarned = true
                    showMsg("Il gateway \(gw) non appartiene a nessuna delle subnet indicate. Premi di nuovo «\(kind == .apply ? "Applica" : "Salva")» per confermare.", warning: true)
                    return
                }
            }
            c.gateway = gw

            var dns: [String] = []
            for tb in [txtDns1, txtDns2] {
                let d = tb.stringValue.trimmingCharacters(in: .whitespaces)
                if d.isEmpty { continue }
                if !NetOps.isValidIPv4(d) {
                    showMsg("Server DNS non valido: '\(d)'.", warning: false); window?.makeFirstResponder(tb); return
                }
                dns.append(NetOps.fromUInt(NetOps.toUInt(d)))
            }
            c.dns1 = dns.first ?? ""
            c.dns2 = dns.count > 1 ? dns[1] : ""
        }

        if kind == .apply, let adapter = adapter {
            app.submitApply(adapter, c, save)
            fly?.showMain(0)
        } else {
            app.submitConfig(editing, c)
            fly?.showMain(1)
        }
    }
}

/// NSTextFieldDelegate minimale per inoltrare textDidChange a una closure.
private class ChangeForwarder: NSObject, NSTextFieldDelegate {
    let onChange: () -> Void
    init(_ onChange: @escaping () -> Void) { self.onChange = onChange }
    func controlTextDidChange(_ obj: Notification) { onChange() }
}
