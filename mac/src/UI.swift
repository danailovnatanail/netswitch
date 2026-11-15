import AppKit

/// Piccole factory per costruire l'interfaccia da codice con gli stili del tema
/// (porting di UI.cs; AppKit usa Auto Layout al posto di Grid/DockPanel di WPF, ma la
/// struttura visiva — testi, pulsanti, switch, segmented control — resta la stessa).
enum UI {

    /// Icone SF Symbols al posto dei glifi Segoe Fluent Icons della versione Windows.
    enum Glyph {
        static let network = "network"
        static let ethernet = "cable.connector"
        static let wifi = "wifi"
        static let bluetooth = "antenna.radiowaves.left.and.right"
        static let vpn = "lock.shield"
        static let refresh = "arrow.clockwise"
        static let more = "ellipsis"
        static let back = "chevron.left"
        static let add = "plus"
        static let edit = "pencil"
        static let delete = "trash"
        static let copy = "doc.on.doc"
        static let save = "square.and.arrow.down"
        static let down = "chevron.down"
        static let up = "chevron.up"
        static let check = "checkmark.circle.fill"
        static let close = "xmark"
        static let warning = "exclamationmark.triangle.fill"
        static let error = "xmark.circle.fill"
        static let info = "info.circle.fill"
        static let sync = "arrow.triangle.2.circlepath"
    }

    // ---------------------------------------------------------------- testo

    static func text(_ s: String, _ size: CGFloat, _ color: NSColor, weight: NSFont.Weight = .regular) -> NSTextField {
        let t = NSTextField(labelWithString: s)
        t.font = NSFont.systemFont(ofSize: size, weight: weight)
        t.textColor = color
        t.lineBreakMode = .byTruncatingTail
        t.cell?.truncatesLastVisibleLine = true
        t.maximumNumberOfLines = 1
        return t
    }

    static func wrappingText(_ s: String, _ size: CGFloat, _ color: NSColor) -> NSTextField {
        let t = text(s, size, color)
        t.lineBreakMode = .byWordWrapping
        t.cell?.wraps = true
        t.maximumNumberOfLines = 0
        return t
    }

    /// Logo dell'app (stesso disegno di AppIcon): tre nodi collegati su fondo sfumato.
    static func logo(_ size: CGFloat) -> NSImageView {
        let iv = NSImageView(image: AppIcon.drawApp(size: size * 2))
        iv.imageScaling = .scaleProportionallyUpOrDown
        NSLayoutConstraint.activate([iv.widthAnchor.constraint(equalToConstant: size), iv.heightAnchor.constraint(equalToConstant: size)])
        return iv
    }

    static func icon(_ systemName: String, _ size: CGFloat, _ color: NSColor?) -> NSImageView {
        let iv = NSImageView()
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
        let img = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)?.withSymbolConfiguration(config)
        iv.image = img
        iv.contentTintColor = color ?? Theme.fg
        iv.imageScaling = .scaleProportionallyUpOrDown
        return iv
    }

    // ---------------------------------------------------------------- pulsanti

    enum ButtonStyle { case plain, accent, danger, ghost, icon }

    static func button(_ style: ButtonStyle, _ title: String, _ onClick: (() -> Void)?) -> StyledButton {
        let b = StyledButton(style: style, title: title)
        b.onClick = onClick
        return b
    }

    static func iconButton(_ glyph: String, _ tooltip: String, _ onClick: (() -> Void)?) -> StyledButton {
        let b = StyledButton(style: .icon, image: glyph, symbolSize: 13)
        b.onClick = onClick
        b.toolTip = tooltip
        NSLayoutConstraint.activate([b.widthAnchor.constraint(equalToConstant: 30), b.heightAnchor.constraint(equalToConstant: 30)])
        return b
    }

    /// Pulsante con icona + testo.
    static func iconTextButton(_ style: ButtonStyle, _ glyph: String, _ text: String, glyphAfter: Bool, _ onClick: (() -> Void)?) -> StyledButton {
        let b = StyledButton(style: style, title: text, image: glyph, symbolSize: 11, imageAfter: glyphAfter)
        b.onClick = onClick
        return b
    }

    // ---------------------------------------------------------------- switch

    static func switchControl(_ content: NSView?) -> SwitchControl {
        SwitchControl(content: content)
    }

    // ---------------------------------------------------------------- campi di testo

    static func input(_ placeholder: String) -> NSTextField {
        let t = StyledTextField()
        t.placeholderString = placeholder
        return t
    }

    // ---------------------------------------------------------------- contenitori

    static func card() -> NSView {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.cornerRadius = 6
        v.layer?.borderWidth = 1
        v.layer?.backgroundColor = Theme.card.cgColor
        v.layer?.borderColor = Theme.cardBorder.cgColor
        return v
    }

    static func divider() -> NSView {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.backgroundColor = Theme.divider.cgColor
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return v
    }

    /// Controllo segmentato (es. schede o Statico/DHCP).
    static func segmented(_ items: [String], initial: Int = 0, onChange: ((Int) -> Void)?) -> SegmentedControl {
        SegmentedControl(items: items, initial: initial, onChange: onChange)
    }

    /// Avvolge una vista (tipicamente un NSStackView verticale) in uno scroll view,
    /// con la vista contenuto che si allarga alla larghezza disponibile (equivalente a UI.Scroll).
    static func scroll(_ content: NSView) -> NSScrollView {
        let sv = NSScrollView()
        sv.hasVerticalScroller = true
        sv.hasHorizontalScroller = false
        sv.autohidesScrollers = true
        sv.drawsBackground = false
        let clip = FlippedClipView()
        clip.drawsBackground = false
        sv.contentView = clip
        let holder = FlippedView()
        holder.translatesAutoresizingMaskIntoConstraints = false
        holder.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: holder.topAnchor),
            content.leadingAnchor.constraint(equalTo: holder.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: holder.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: holder.bottomAnchor),
        ])
        sv.documentView = holder
        holder.widthAnchor.constraint(equalTo: sv.widthAnchor).isActive = true
        return sv
    }

    static func menuItem(_ title: String, _ onClick: (() -> Void)?) -> NSMenuItem {
        let mi = ClosureMenuItem(title: title, action: onClick)
        return mi
    }

    static func showMenu(_ menu: NSMenu, relativeTo view: NSView) {
        let p = NSPoint(x: 0, y: -4)
        menu.popUp(positioning: nil, at: p, in: view)
    }

    static func glyphFor(_ a: AdapterInfo) -> String {
        let d = (a.description + " " + a.name).lowercased()
        if d.contains("bluetooth") { return Glyph.bluetooth }
        if d.contains("wi-fi") || d.contains("wifi") || d.contains("wireless") || d.contains("wlan") || d.contains("802.11") { return Glyph.wifi }
        if d.contains("vpn") || d.contains("virtual") || d.contains("tap-") || d.contains("wireguard") || d.contains("utun") { return Glyph.vpn }
        return Glyph.ethernet
    }
}

// ============================================================== helper views

/// NSView "flipped" (origine in alto a sinistra) per avere lo stesso verso di impilamento
/// dall'alto verso il basso usato in WPF (StackPanel).
class FlippedView: NSView { override var isFlipped: Bool { true } }
class FlippedClipView: NSClipView { override var isFlipped: Bool { true } }

/// NSMenuItem con azione come closure invece che target/selector.
class ClosureMenuItem: NSMenuItem {
    private var handler: (() -> Void)?
    init(title: String, action: (() -> Void)?) {
        self.handler = action
        super.init(title: title, action: action == nil ? nil : #selector(fire), keyEquivalent: "")
        self.target = self
    }
    required init(coder: NSCoder) { fatalError() }
    @objc private func fire() { handler?() }
}

/// Pulsante piatto in stile "Windows 11", con stati hover/pressed/disabled disegnati a mano.
class StyledButton: NSButton {
    var style: UI.ButtonStyle
    var onClick: (() -> Void)?
    private var hovering = false { didSet { updateAppearance() } }
    private var trackingArea: NSTrackingArea?
    private let symbolSize: CGFloat
    private let imageAfter: Bool

    init(style: UI.ButtonStyle, title: String = "", image: String? = nil, symbolSize: CGFloat = 11, imageAfter: Bool = false) {
        self.style = style
        self.symbolSize = symbolSize
        self.imageAfter = imageAfter
        super.init(frame: .zero)
        self.title = title
        if let image = image {
            let config = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .regular)
            self.image = NSImage(systemSymbolName: image, accessibilityDescription: nil)?.withSymbolConfiguration(config)
            self.imagePosition = title.isEmpty ? .imageOnly : (imageAfter ? .imageRight : .imageLeading)
            // icona e testo centrati insieme anche nei pulsanti larghi (come in WPF)
            self.imageHugsTitle = true
        }
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = 4
        font = NSFont.systemFont(ofSize: 12.5, weight: style == .accent || style == .danger ? .semibold : .regular)
        setButtonType(.momentaryChange)
        target = self
        action = #selector(handleClick)
        translatesAutoresizingMaskIntoConstraints = false
        contentTintColor = foregroundColor
        updateAppearance()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    @objc private func handleClick() { onClick?() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = trackingArea { removeTrackingArea(t) }
        let t = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow], owner: self, userInfo: nil)
        addTrackingArea(t); trackingArea = t
    }
    override func mouseEntered(with event: NSEvent) { hovering = true }
    override func mouseExited(with event: NSEvent) { hovering = false }

    override var isEnabled: Bool { didSet { updateAppearance() } }

    /// Padding interno del pulsante (stile 'Btn' di Theme.cs: 12,5,12,6): senza bordo NSButton
    /// si adatta al solo testo.
    var padding = NSEdgeInsets(top: 5, left: 12, bottom: 6, right: 12) { didSet { invalidateIntrinsicContentSize() } }

    override var intrinsicContentSize: NSSize {
        let s = super.intrinsicContentSize
        if style == .icon || title.isEmpty { return s }
        return NSSize(width: s.width + padding.left + padding.right, height: s.height + padding.top + padding.bottom)
    }

    /// Colore del contenuto al posto di quello dello stile (es. rosso per "Elimina").
    var tint: NSColor? { didSet { updateAppearance() } }

    private var foregroundColor: NSColor {
        if let tint = tint { return tint }
        switch style {
        case .plain, .ghost, .icon: return Theme.fg
        case .accent: return Theme.accentFg
        case .danger: return .white
        }
    }

    func updateAppearance() {
        let bg: NSColor
        switch style {
        case .plain: bg = hovering ? Theme.subtleHover : Theme.subtle
        case .accent: bg = Theme.accent
        case .danger: bg = Theme.dangerFill
        case .ghost, .icon: bg = hovering ? Theme.hoverOverlay : .clear
        }
        layer?.backgroundColor = bg.cgColor
        alphaValue = isEnabled ? 1.0 : 0.4
        let fg = foregroundColor
        contentTintColor = fg
        if !title.isEmpty {
            attributedTitle = NSAttributedString(string: title, attributes: [.foregroundColor: fg, .font: font as Any])
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        updateAppearance()
        super.draw(dirtyRect)
    }
}

/// Campo di testo con bordo arrotondato e accento sul focus (equivalente dello stile 'Input').
/// Cella con padding interno (stile 'Input' di Theme.cs: 8,6) e testo centrato verticalmente,
/// anche durante la modifica (l'editor di campo usa gli stessi rettangoli).
final class PaddedTextFieldCell: NSTextFieldCell {
    var inset = NSSize(width: 8, height: 6)

    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        let r = super.drawingRect(forBounds: rect.insetBy(dx: inset.width, dy: 0))
        let h = cellSize(forBounds: r).height
        return NSRect(x: r.minX, y: r.minY + max(0, (r.height - h) / 2), width: r.width, height: min(h, r.height))
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        super.edit(withFrame: drawingRect(forBounds: rect), in: controlView, editor: textObj, delegate: delegate, event: event)
    }

    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        super.select(withFrame: drawingRect(forBounds: rect), in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }
}

class StyledTextField: NSTextField {
    private var isFocused = false { didSet { needsDisplay = true } }

    override class var cellClass: AnyClass? { get { PaddedTextFieldCell.self } set {} }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        isBordered = false
        drawsBackground = false
        focusRingType = .none
        font = NSFont.systemFont(ofSize: 13)
        textColor = Theme.fg
        wantsLayer = true
        layer?.cornerRadius = 4
        (cell as? NSTextFieldCell)?.usesSingleLineMode = true
        (cell as? NSTextFieldCell)?.isScrollable = true
        isEditable = true
        isSelectable = true
    }

    override func becomeFirstResponder() -> Bool {
        let r = super.becomeFirstResponder()
        if r { isFocused = true }
        return r
    }

    override func resignFirstResponder() -> Bool {
        let r = super.resignFirstResponder()
        if r { isFocused = false }
        return r
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4)
        Theme.inputBg.setFill(); path.fill()
        (isFocused ? Theme.accent : Theme.inputBorder).setStroke()
        path.lineWidth = isFocused ? 1.5 : 1
        path.stroke()
        super.draw(dirtyRect)
    }
}

/// Interruttore on/off in stile pillola (equivalente allo stile 'Switch' WPF).
class SwitchControl: NSView {
    private(set) var isOn: Bool = false
    var onToggle: ((Bool) -> Void)?
    private let track = NSView()
    private let thumb = NSView()
    private var label: NSView?

    init(content: NSView?) {
        super.init(frame: .zero)
        self.label = content
        translatesAutoresizingMaskIntoConstraints = false
        track.wantsLayer = true
        track.layer?.cornerRadius = 10
        track.layer?.borderWidth = 1
        track.translatesAutoresizingMaskIntoConstraints = false
        addSubview(track)
        thumb.wantsLayer = true
        thumb.layer?.cornerRadius = 6
        thumb.translatesAutoresizingMaskIntoConstraints = false
        track.addSubview(thumb)

        NSLayoutConstraint.activate([
            track.leadingAnchor.constraint(equalTo: leadingAnchor),
            track.centerYAnchor.constraint(equalTo: centerYAnchor),
            track.widthAnchor.constraint(equalToConstant: 40),
            track.heightAnchor.constraint(equalToConstant: 20),
            thumb.widthAnchor.constraint(equalToConstant: 12),
            thumb.heightAnchor.constraint(equalToConstant: 12),
            thumb.centerYAnchor.constraint(equalTo: track.centerYAnchor),
        ])
        thumbLeading = thumb.leadingAnchor.constraint(equalTo: track.leadingAnchor, constant: 4)
        thumbLeading?.isActive = true

        if let label = label {
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: track.trailingAnchor, constant: 10),
                label.trailingAnchor.constraint(equalTo: trailingAnchor),
                label.centerYAnchor.constraint(equalTo: centerYAnchor),
                topAnchor.constraint(equalTo: track.topAnchor),
                bottomAnchor.constraint(equalTo: track.bottomAnchor),
            ])
        } else {
            NSLayoutConstraint.activate([trailingAnchor.constraint(equalTo: track.trailingAnchor),
                                          topAnchor.constraint(equalTo: track.topAnchor),
                                          bottomAnchor.constraint(equalTo: track.bottomAnchor)])
        }
        updateAppearance()
        let click = NSClickGestureRecognizer(target: self, action: #selector(handleClick))
        addGestureRecognizer(click)
    }
    required init?(coder: NSCoder) { fatalError() }

    private var thumbLeading: NSLayoutConstraint?
    private var thumbTrailing: NSLayoutConstraint?

    @objc private func handleClick() {
        guard isEnabled else { return }
        setOn(!isOn, notify: true)
    }

    func setOn(_ on: Bool, notify: Bool) {
        isOn = on
        updateAppearance()
        if notify { onToggle?(on) }
    }

    var isEnabled: Bool = true { didSet { alphaValue = isEnabled ? 1.0 : 0.4 } }

    private func updateAppearance() {
        track.layer?.backgroundColor = (isOn ? Theme.accent : NSColor.clear).cgColor
        track.layer?.borderColor = (isOn ? Theme.accent : Theme.fg2).cgColor
        thumb.layer?.backgroundColor = (isOn ? Theme.accentFg : Theme.fg2).cgColor
        thumbLeading?.isActive = false
        thumbTrailing?.isActive = false
        if isOn {
            thumbTrailing = thumb.trailingAnchor.constraint(equalTo: track.trailingAnchor, constant: -4)
            thumbTrailing?.isActive = true
        } else {
            thumbLeading = thumb.leadingAnchor.constraint(equalTo: track.leadingAnchor, constant: 4)
            thumbLeading?.isActive = true
        }
    }
}

/// Controllo segmentato stile "Statico / DHCP" o schede.
class SegmentedControl: NSView {
    private(set) var selectedIndex: Int
    var onChange: ((Int) -> Void)?
    private var buttons: [NSButton] = []
    private let track = NSView()

    init(items: [String], initial: Int, onChange: ((Int) -> Void)?) {
        self.selectedIndex = initial
        self.onChange = onChange
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        track.wantsLayer = true
        track.layer?.cornerRadius = 6
        track.layer?.backgroundColor = Theme.subtle.cgColor
        track.translatesAutoresizingMaskIntoConstraints = false
        addSubview(track)
        NSLayoutConstraint.activate([
            track.topAnchor.constraint(equalTo: topAnchor), track.bottomAnchor.constraint(equalTo: bottomAnchor),
            track.leadingAnchor.constraint(equalTo: leadingAnchor), track.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 2
        stack.edgeInsets = NSEdgeInsets(top: 3, left: 3, bottom: 3, right: 3)
        stack.translatesAutoresizingMaskIntoConstraints = false
        track.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: track.topAnchor), stack.bottomAnchor.constraint(equalTo: track.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: track.leadingAnchor), stack.trailingAnchor.constraint(equalTo: track.trailingAnchor),
        ])
        for (i, title) in items.enumerated() {
            let b = NSButton(title: title, target: self, action: #selector(tap(_:)))
            b.tag = i
            b.isBordered = false
            b.wantsLayer = true
            b.layer?.cornerRadius = 5
            b.layer?.masksToBounds = false
            b.font = NSFont.systemFont(ofSize: 12.5)
            b.refusesFirstResponder = true
            buttons.append(b)
            stack.addArrangedSubview(b)
            // il segmento occupa tutta l'altezza della traccia (meno il bordo interno): con
            // l'altezza naturale del testo l'evidenziazione risultava schiacciata
            b.heightAnchor.constraint(equalTo: stack.heightAnchor, constant: -6).isActive = true
        }
        updateAppearance()
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func tap(_ sender: NSButton) {
        selectedIndex = sender.tag
        updateAppearance()
        onChange?(selectedIndex)
    }

    func select(_ index: Int) { selectedIndex = index; updateAppearance() }

    private func updateAppearance() {
        for (i, b) in buttons.enumerated() {
            let sel = i == selectedIndex
            // segmento selezionato in rilievo (bordo sottile e ombra leggera), ben distinto
            // dalla traccia anche col tema scuro, dove Card e traccia hanno toni molto vicini
            let selBg = Theme.isDark ? NSColor(white: 0.36, alpha: 1) : NSColor.white
            b.layer?.backgroundColor = (sel ? selBg : .clear).cgColor
            b.layer?.borderWidth = sel ? 0.5 : 0
            b.layer?.borderColor = (Theme.isDark ? NSColor.white.withAlphaComponent(0.10) : NSColor.black.withAlphaComponent(0.08)).cgColor
            b.layer?.shadowOpacity = sel ? 1 : 0
            b.layer?.shadowColor = NSColor.black.withAlphaComponent(Theme.isDark ? 0.35 : 0.10).cgColor
            b.layer?.shadowOffset = NSSize(width: 0, height: -1)
            b.layer?.shadowRadius = 1.5
            let fg = sel ? Theme.fg : Theme.fg2
            b.attributedTitle = NSAttributedString(string: b.title, attributes: [
                .foregroundColor: fg,
                .font: NSFont.systemFont(ofSize: 12.5, weight: sel ? .semibold : .regular),
            ])
        }
    }
}
