import AppKit

/// Tema in stile "Windows 11 flyout": segue chiaro/scuro di sistema e il colore d'accento
/// scelto dall'utente in Preferenze di Sistema (porting di Theme.cs; qui invece di un
/// ResourceDictionary WPF usiamo un semplice registro di NSColor dinamici).
enum Theme {
    static var isDark: Bool = false

    static func apply() {
        let appearance = NSApp.effectiveAppearance
        isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let forced = Program.debugOn ? ProcessInfo.processInfo.environment["NETSWITCH_THEME"] : nil
        if forced == "dark" || forced == "light" { isDark = (forced == "dark") }
    }

    static var accent: NSColor {
        if Program.fake {
            return isDark ? NSColor(red: 0x2D/255, green: 0xD4/255, blue: 0xBF/255, alpha: 1)
                           : NSColor(red: 0x0D/255, green: 0x94/255, blue: 0x88/255, alpha: 1)
        }
        return NSColor.controlAccentColor
    }

    static var accentFg: NSColor { isDark ? .black : .white }

    static var bg: NSColor { isDark ? hex("#202020") : hex("#F3F3F3") }
    static var card: NSColor { isDark ? hex("#2B2B2B") : hex("#FBFBFB") }
    static var cardHover: NSColor { isDark ? hex("#323232") : hex("#F5F5F5") }
    static var cardBorder: NSColor { isDark ? hex("#3A3A3A") : hex("#E3E3E3") }
    static var cardOff: NSColor { isDark ? NSColor.white.withAlphaComponent(0.04) : NSColor.black.withAlphaComponent(0.02) }
    static var menuBg: NSColor { isDark ? hex("#2C2C2C") : hex("#F9F9F9") }
    static var fg: NSColor { isDark ? hex("#FFFFFF") : hex("#1B1B1B") }
    static var fg2: NSColor { isDark ? hex("#C5C5C5") : hex("#5D5D5D") }
    static var fg3: NSColor { isDark ? hex("#8B8B8B") : hex("#8E8E8E") }
    static var subtle: NSColor { isDark ? NSColor.white.withAlphaComponent(0.06) : NSColor.black.withAlphaComponent(0.04) }
    static var subtleHover: NSColor { isDark ? NSColor.white.withAlphaComponent(0.10) : NSColor.black.withAlphaComponent(0.08) }
    static var hoverOverlay: NSColor { isDark ? NSColor.white.withAlphaComponent(0.08) : NSColor.black.withAlphaComponent(0.05) }
    static var inputBg: NSColor { isDark ? hex("#2D2D2D") : hex("#FFFFFF") }
    static var inputBorder: NSColor { isDark ? hex("#454545") : hex("#D1D1D1") }
    static var divider: NSColor { isDark ? hex("#383838") : hex("#E5E5E5") }
    static var overlay: NSColor { isDark ? NSColor.black.withAlphaComponent(0.60) : NSColor.black.withAlphaComponent(0.40) }
    static var danger: NSColor { isDark ? hex("#FF99A4") : hex("#C42B1C") }
    static var dangerFill: NSColor { hex("#C42B1C") }
    static var success: NSColor { isDark ? hex("#6CCB5F") : hex("#0F7B0F") }
    static var warning: NSColor { isDark ? hex("#FCE100") : hex("#9D5D00") }
    static var amber: NSColor { isDark ? hex("#FFB900") : hex("#E8A200") }

    private static func hex(_ s: String) -> NSColor {
        var h = s; if h.hasPrefix("#") { h.removeFirst() }
        guard let v = UInt32(h, radix: 16) else { return .black }
        let r = CGFloat((v >> 16) & 0xFF) / 255.0
        let g = CGFloat((v >> 8) & 0xFF) / 255.0
        let b = CGFloat(v & 0xFF) / 255.0
        return NSColor(red: r, green: g, blue: b, alpha: 1)
    }
}
