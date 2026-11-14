import AppKit

/// Vista che inoltra click e hover (equivalente del Grid "cliccabile" nelle intestazioni
/// delle card WPF: cursore a manina, evidenziazione al passaggio del mouse).
class HoverableView: NSView {
    var onClick: (() -> Void)?
    var onHover: ((Bool) -> Void)?
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = trackingArea { removeTrackingArea(t) }
        let t = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow], owner: self, userInfo: nil)
        addTrackingArea(t); trackingArea = t
    }
    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    override func mouseExited(with event: NSEvent) { onHover?(false) }
    override func mouseDown(with event: NSEvent) { onClick?() }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
}

/// Etichetta cliccabile per copiare un valore negli appunti (dettagli dell'interfaccia).
class CopyableLabel: NSTextField {
    var onClick: (() -> Void)?
    private var trackingArea: NSTrackingArea?
    private var plain: NSAttributedString?

    func setup(_ text: String) {
        plain = NSAttributedString(string: text, attributes: [.foregroundColor: Theme.fg, .font: NSFont.systemFont(ofSize: 12)])
        attributedStringValue = plain!
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = trackingArea { removeTrackingArea(t) }
        let t = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow], owner: self, userInfo: nil)
        addTrackingArea(t); trackingArea = t
    }
    override func mouseEntered(with event: NSEvent) {
        guard let plain = plain else { return }
        let underlined = NSMutableAttributedString(attributedString: plain)
        underlined.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: underlined.length))
        attributedStringValue = underlined
    }
    override func mouseExited(with event: NSEvent) { if let plain = plain { attributedStringValue = plain } }
    override func mouseDown(with event: NSEvent) { onClick?() }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
}

/// Scheda di una interfaccia: riepilogo cliccabile, dettagli espandibili e azioni.
/// Porting di AdapterCard in Cards.cs (Auto Layout al posto di Grid/DockPanel).
class AdapterCardView: NSView {
    private weak var fly: Flyout?
    private weak var app: Controller?
    private var a: AdapterInfo!
    private var expanded = false

    private let header = HoverableView()
    private let glyph = UI.icon(UI.Glyph.ethernet, 16, Theme.fg)
    private let dot = NSView()
    private let nameLabel = UI.text("", 13.5, Theme.fg, weight: .semibold)
    private let subLabel = UI.text("", 12, Theme.fg2)
    private let badge = NSView()
    private let badgeText = UI.text("", 11, Theme.fg2)
    private let sw = UI.switchControl(nil)
    private let chevron = UI.icon(UI.Glyph.down, 10, Theme.fg3)
    private let details = NSStackView()
    private let infoGrid = NSGridView(numberOfColumns: 2, rows: 0)
    private var btnSet: StyledButton!
    private var btnDhcp: StyledButton!
    private var btnCfg: StyledButton!
    private var btnSave: StyledButton!

    init(fly: Flyout, app: Controller) {
        self.fly = fly
        self.app = app
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        layer?.borderColor = Theme.cardBorder.cgColor

        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 0
        root.alignment = .leading
        root.translatesAutoresizingMaskIntoConstraints = false
        addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: topAnchor), root.bottomAnchor.constraint(equalTo: bottomAnchor),
            root.leadingAnchor.constraint(equalTo: leadingAnchor), root.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        // ---------------------------------------------------- intestazione
        header.translatesAutoresizingMaskIntoConstraints = false
        header.heightAnchor.constraint(equalToConstant: 50).isActive = true
        header.widthAnchor.constraint(equalToConstant: 380).isActive = true
        header.onClick = { [weak self] in
            guard let self = self, let fly = self.fly else { return }
            fly.toggleAdapterExpanded(self.a, self)
        }
        header.onHover = { [weak self] hovering in self?.setHover(hovering) }

        let iconBox = NSView()
        iconBox.translatesAutoresizingMaskIntoConstraints = false
        glyph.translatesAutoresizingMaskIntoConstraints = false
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 5
        dot.layer?.borderWidth = 2
        iconBox.addSubview(glyph); iconBox.addSubview(dot)
        header.addSubview(iconBox)
        NSLayoutConstraint.activate([
            iconBox.widthAnchor.constraint(equalToConstant: 30), iconBox.heightAnchor.constraint(equalToConstant: 30),
            iconBox.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 12),
            iconBox.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            glyph.centerXAnchor.constraint(equalTo: iconBox.centerXAnchor), glyph.centerYAnchor.constraint(equalTo: iconBox.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 10), dot.heightAnchor.constraint(equalToConstant: 10),
            dot.trailingAnchor.constraint(equalTo: iconBox.trailingAnchor), dot.bottomAnchor.constraint(equalTo: iconBox.bottomAnchor),
        ])

        let texts = NSStackView(views: [nameLabel, subLabel])
        texts.orientation = .vertical
        texts.alignment = .leading
        texts.spacing = 1
        texts.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(texts)

        badge.wantsLayer = true
        badge.layer?.cornerRadius = 4
        badge.translatesAutoresizingMaskIntoConstraints = false
        badgeText.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(badgeText)
        header.addSubview(badge)
        NSLayoutConstraint.activate([
            badgeText.topAnchor.constraint(equalTo: badge.topAnchor, constant: 1), badgeText.bottomAnchor.constraint(equalTo: badge.bottomAnchor, constant: -2),
            badgeText.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: 6), badgeText.trailingAnchor.constraint(equalTo: badge.trailingAnchor, constant: -6),
        ])

        sw.translatesAutoresizingMaskIntoConstraints = false
        sw.toolTip = "Attiva / disattiva interfaccia"
        sw.onToggle = { [weak self] want in
            guard let self = self, let app = self.app else { return }
            self.sw.setOn(self.a.adminEnabled, notify: false) // lo stato reale arriverà con l'aggiornamento
            app.setEnabled(self.a, want)
        }
        header.addSubview(sw)

        chevron.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(chevron)

        NSLayoutConstraint.activate([
            texts.leadingAnchor.constraint(equalTo: iconBox.trailingAnchor, constant: 10),
            texts.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            badge.leadingAnchor.constraint(greaterThanOrEqualTo: texts.trailingAnchor, constant: 8),
            badge.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            sw.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 10),
            sw.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            chevron.leadingAnchor.constraint(equalTo: sw.trailingAnchor, constant: 6),
            chevron.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -12),
            chevron.centerYAnchor.constraint(equalTo: header.centerYAnchor),
        ])
        root.addArrangedSubview(header)

        // ---------------------------------------------------- dettagli
        details.orientation = .vertical
        details.alignment = .leading
        details.spacing = 10
        details.translatesAutoresizingMaskIntoConstraints = false
        details.edgeInsets = NSEdgeInsets(top: 0, left: 12, bottom: 12, right: 10)
        details.widthAnchor.constraint(equalToConstant: 380).isActive = true
        details.isHidden = true
        details.addArrangedSubview(UI.divider())
        details.arrangedSubviews.last?.widthAnchor.constraint(equalTo: details.widthAnchor, constant: -22).isActive = true

        infoGrid.rowSpacing = 4
        infoGrid.columnSpacing = 8
        details.addArrangedSubview(infoGrid)

        btnSet = UI.button(.accent, "Imposta IP", { [weak self] in
            guard let self = self, let fly = self.fly else { return }
            fly.openApplyEditor(self.a)
        })
        btnDhcp = UI.button(.plain, "DHCP", { [weak self] in
            guard let self = self, let app = self.app else { return }
            app.useDhcp(self.a)
        })
        btnDhcp.toolTip = "Indirizzo e DNS automatici"
        btnCfg = UI.iconTextButton(.plain, UI.Glyph.down, "Configurazione", glyphAfter: true, nil)
        btnCfg.onClick = { [weak self] in
            guard let self = self, let fly = self.fly else { return }
            fly.showApplyConfigMenu(self.btnCfg, self.a)
        }
        btnCfg.toolTip = "Applica una configurazione salvata"
        btnSave = UI.iconButton(UI.Glyph.save, "Salva come configurazione", { [weak self] in
            guard let self = self, let app = self.app else { return }
            app.newConfigFrom(self.a)
        })
        let actions = NSStackView(views: [btnSet, btnDhcp, btnCfg, btnSave])
        actions.orientation = .horizontal
        actions.spacing = 6
        details.addArrangedSubview(actions)

        root.addArrangedSubview(details)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setHover(_ hovering: Bool) {
        layer?.backgroundColor = (hovering ? Theme.cardHover : (a?.adminEnabled == false ? Theme.cardOff : Theme.card)).cgColor
    }

    func update(_ info: AdapterInfo, expanded: Bool) {
        a = info
        let off = !a.adminEnabled
        glyph.image = NSImage(systemSymbolName: UI.glyphFor(a), accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 16, weight: .regular))
        glyph.alphaValue = off ? 0.45 : 1
        nameLabel.stringValue = a.name
        nameLabel.alphaValue = off ? 0.6 : 1

        if off {
            dot.layer?.backgroundColor = NSColor.clear.cgColor
            dot.layer?.borderColor = Theme.fg3.cgColor
        } else {
            dot.layer?.backgroundColor = (a.isConnected ? Theme.success : Theme.amber).cgColor
            dot.layer?.borderColor = Theme.card.cgColor
        }
        layer?.backgroundColor = (off ? Theme.cardOff : Theme.card).cgColor

        if off {
            subLabel.stringValue = "Disattivata"
            subLabel.textColor = Theme.fg3
        } else if a.isConnected {
            subLabel.stringValue = a.addresses.isEmpty
                ? "Connessa · nessun indirizzo IPv4"
                : a.addresses[0] + (a.addresses.count > 1 ? "   +\(a.addresses.count - 1)" : "")
            subLabel.textColor = Theme.fg2
        } else {
            let state = a.connectionStatus == 0 ? "Non connessa" : a.statusText
            let suffix = a.addresses.isEmpty ? "" : "  ·  " + a.addresses[0] + (a.addresses.count > 1 ? " +\(a.addresses.count - 1)" : "")
            let s = NSMutableAttributedString(string: state, attributes: [.foregroundColor: Theme.warning])
            if !suffix.isEmpty { s.append(NSAttributedString(string: suffix, attributes: [.foregroundColor: Theme.fg2])) }
            subLabel.attributedStringValue = s
        }

        let showBadge = a.adminEnabled && a.modeText != "-"
        badge.isHidden = !showBadge
        badge.layer?.backgroundColor = Theme.subtle.cgColor
        badgeText.stringValue = a.modeText
        sw.setOn(a.adminEnabled, notify: false)

        buildInfo()
        btnSet.isEnabled = a.adminEnabled
        btnDhcp.isEnabled = a.adminEnabled
        btnCfg.isEnabled = a.adminEnabled
        setExpanded(expanded, animate: false)
    }

    private func buildInfo() {
        while infoGrid.numberOfRows > 0 { infoGrid.removeRow(at: 0) }
        let speed = a.speedText
        addInfo("Stato", a.statusText + (speed.isEmpty ? "" : "  ·  " + speed), copy: false)
        addInfo("IP", a.addresses.isEmpty ? "-" : a.addresses.joined(separator: "\n"), copy: true)
        addInfo("Gateway", a.gatewayText, copy: true)
        addInfo("DNS", a.dns.isEmpty ? "-" : a.dns.joined(separator: "\n"), copy: true)
        addInfo("MAC", a.mac.isEmpty ? "-" : a.mac, copy: true)
        addInfo("Adattatore", a.description, copy: false)
    }

    private func addInfo(_ label: String, _ value: String, copy: Bool) {
        let l = UI.text(label, 12, Theme.fg3)
        l.widthAnchor.constraint(equalToConstant: 78).isActive = true
        let v = CopyableLabel()
        v.isBordered = false; v.isEditable = false; v.drawsBackground = false
        v.lineBreakMode = .byWordWrapping
        v.cell?.wraps = true
        v.maximumNumberOfLines = 0
        v.setup(value.isEmpty ? "-" : value)
        v.preferredMaxLayoutWidth = 270
        if copy, value != "-", !value.isEmpty {
            let flat = value.replacingOccurrences(of: "\n", with: ", ")
            v.toolTip = "Clic per copiare"
            v.onClick = { [weak self] in self?.fly?.copyToClipboard(flat) }
        }
        infoGrid.addRow(with: [l, v])
    }

    func setExpanded(_ expanded: Bool, animate: Bool) {
        let was = !details.isHidden
        self.expanded = expanded
        chevron.image = NSImage(systemSymbolName: expanded ? UI.Glyph.up : UI.Glyph.down, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 10, weight: .regular))
        if expanded {
            details.isHidden = false
            if animate && !was {
                details.alphaValue = 0
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.16
                    details.animator().alphaValue = 1
                }
            } else {
                details.alphaValue = 1
            }
        } else {
            details.isHidden = true
        }
    }
}

/// Scheda di una configurazione salvata. Porting di ConfigCard in Cards.cs.
class ConfigCardView: NSView {
    private weak var fly: Flyout?
    private weak var app: Controller?
    private var c: SavedConfig!
    private let header = HoverableView()
    private let nameLabel = UI.text("", 13.5, Theme.fg, weight: .semibold)
    private let sumLabel = UI.text("", 12, Theme.fg2)
    private let chevron = UI.icon(UI.Glyph.down, 10, Theme.fg3)
    private let details = NSStackView()
    private var applyBtn: StyledButton!
    private var upBtn: StyledButton!
    private var downBtn: StyledButton!

    init(fly: Flyout, app: Controller, c: SavedConfig, index: Int, count: Int, expanded: Bool) {
        self.fly = fly
        self.app = app
        self.c = c
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        layer?.borderColor = Theme.cardBorder.cgColor
        layer?.backgroundColor = Theme.card.cgColor

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.translatesAutoresizingMaskIntoConstraints = false
        addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: topAnchor), root.bottomAnchor.constraint(equalTo: bottomAnchor),
            root.leadingAnchor.constraint(equalTo: leadingAnchor), root.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        header.translatesAutoresizingMaskIntoConstraints = false
        header.heightAnchor.constraint(equalToConstant: 50).isActive = true
        header.widthAnchor.constraint(equalToConstant: 380).isActive = true
        header.onClick = { [weak self] in
            guard let self = self, let fly = self.fly else { return }
            fly.toggleConfigExpanded(self.c, self)
        }
        header.onHover = { [weak self] h in self?.layer?.backgroundColor = (h ? Theme.cardHover : Theme.card).cgColor }

        let iconBox = NSView()
        iconBox.wantsLayer = true
        iconBox.layer?.cornerRadius = 6
        iconBox.layer?.backgroundColor = Theme.subtle.cgColor
        iconBox.translatesAutoresizingMaskIntoConstraints = false
        let icon = UI.icon(c.dhcp ? UI.Glyph.refresh : UI.Glyph.network, 14, Theme.accent)
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconBox.addSubview(icon)
        header.addSubview(iconBox)
        NSLayoutConstraint.activate([
            iconBox.widthAnchor.constraint(equalToConstant: 30), iconBox.heightAnchor.constraint(equalToConstant: 30),
            iconBox.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 12),
            iconBox.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            icon.centerXAnchor.constraint(equalTo: iconBox.centerXAnchor), icon.centerYAnchor.constraint(equalTo: iconBox.centerYAnchor),
        ])

        let texts = NSStackView(views: [nameLabel, sumLabel])
        texts.orientation = .vertical
        texts.alignment = .leading
        texts.spacing = 1
        texts.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(texts)
        chevron.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(chevron)
        NSLayoutConstraint.activate([
            texts.leadingAnchor.constraint(equalTo: iconBox.trailingAnchor, constant: 10),
            texts.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            texts.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -8),
            chevron.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -14),
            chevron.centerYAnchor.constraint(equalTo: header.centerYAnchor),
        ])
        root.addArrangedSubview(header)

        details.orientation = .vertical
        details.alignment = .leading
        details.spacing = 10
        details.translatesAutoresizingMaskIntoConstraints = false
        details.edgeInsets = NSEdgeInsets(top: 0, left: 12, bottom: 12, right: 12)
        details.widthAnchor.constraint(equalToConstant: 380).isActive = true
        details.isHidden = true
        details.addArrangedSubview(UI.divider())
        details.arrangedSubviews.last?.widthAnchor.constraint(equalTo: details.widthAnchor, constant: -24).isActive = true

        if !c.dhcp {
            let grid = NSGridView(numberOfColumns: 2, rows: 0)
            grid.rowSpacing = 4; grid.columnSpacing = 8
            addRow(grid, "IP", c.address.replacingOccurrences(of: ", ", with: "\n"))
            addRow(grid, "Gateway", c.gateway.trimmingCharacters(in: .whitespaces).isEmpty ? "-" : c.gateway)
            addRow(grid, "DNS", c.dnsText.isEmpty ? "-" : c.dnsText.replacingOccurrences(of: ", ", with: "\n"))
            details.addArrangedSubview(grid)
        } else {
            details.addArrangedSubview(UI.wrappingText("Indirizzo IP e DNS assegnati automaticamente.", 12, Theme.fg2))
        }

        applyBtn = UI.iconTextButton(.accent, UI.Glyph.down, "Applica a", glyphAfter: true, nil)
        applyBtn.onClick = { [weak self] in
            guard let self = self, let fly = self.fly else { return }
            fly.showApplyToMenu(self.applyBtn, self.c)
        }
        let delBtn = UI.iconButton(UI.Glyph.delete, "Elimina", { [weak self] in
            guard let self = self, let app = self.app else { return }
            app.deleteConfig(self.c)
        })
        delBtn.contentTintColor = Theme.danger
        downBtn = UI.iconButton(UI.Glyph.down, "Sposta giù", { [weak self] in
            guard let self = self, let app = self.app else { return }
            app.moveConfig(self.c, 1)
        })
        downBtn.isEnabled = index < count - 1
        upBtn = UI.iconButton(UI.Glyph.up, "Sposta su", { [weak self] in
            guard let self = self, let app = self.app else { return }
            app.moveConfig(self.c, -1)
        })
        upBtn.isEnabled = index > 0
        let dupBtn = UI.iconButton(UI.Glyph.copy, "Duplica", { [weak self] in
            guard let self = self, let app = self.app else { return }
            app.duplicateConfig(self.c)
        })
        let editBtn = UI.iconButton(UI.Glyph.edit, "Modifica", { [weak self] in
            guard let self = self, let fly = self.fly else { return }
            fly.openConfigEditor(self.c, self.c)
        })
        let actions = NSStackView(views: [applyBtn, NSView(), editBtn, dupBtn, upBtn, downBtn, delBtn])
        actions.orientation = .horizontal
        actions.spacing = 4
        actions.translatesAutoresizingMaskIntoConstraints = false
        actions.widthAnchor.constraint(equalToConstant: 356).isActive = true
        details.addArrangedSubview(actions)

        root.addArrangedSubview(details)
        setExpanded(expanded, animate: false)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func addRow(_ g: NSGridView, _ label: String, _ value: String) {
        let l = UI.text(label, 12, Theme.fg3)
        l.widthAnchor.constraint(equalToConstant: 78).isActive = true
        let v = UI.wrappingText(value, 12, Theme.fg)
        v.preferredMaxLayoutWidth = 270
        g.addRow(with: [l, v])
    }

    func update(_ c: SavedConfig) {
        self.c = c
        nameLabel.stringValue = c.name
        sumLabel.stringValue = c.dhcp ? "DHCP (automatico)" : c.address
    }

    func setExpanded(_ expanded: Bool, animate: Bool) {
        let was = !details.isHidden
        chevron.image = NSImage(systemSymbolName: expanded ? UI.Glyph.up : UI.Glyph.down, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 10, weight: .regular))
        if expanded {
            details.isHidden = false
            if animate && !was {
                details.alphaValue = 0
                NSAnimationContext.runAnimationGroup { ctx in ctx.duration = 0.16; details.animator().alphaValue = 1 }
            } else { details.alphaValue = 1 }
        } else {
            details.isHidden = true
        }
    }
}
