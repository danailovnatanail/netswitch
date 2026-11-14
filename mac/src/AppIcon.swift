import AppKit

/// Icone disegnate a runtime (nessun file esterno necessario), porting di AppIcon.cs.
/// Logo: tre nodi di rete collegati da curve, su fondo arrotondato con sfumatura
/// verde acqua -> blu. Stesse coordinate (griglia 32x32) della versione Windows.
enum AppIcon {

    private static var cachedApp: NSImage?
    private static var cachedGreen: NSImage?
    private static var cachedAmber: NSImage?
    private static var cachedRing: NSImage?

    static var app: NSImage {
        if let c = cachedApp { return c }
        let img = drawApp(size: 18) // dimensione tipica di una status bar icon
        cachedApp = img
        return img
    }

    static var dotConnected: NSImage { cachedGreen ?? { let i = dot(NSColor(red: 46/255, green: 160/255, blue: 67/255, alpha: 1)); cachedGreen = i; return i }() }
    static var dotDisconnected: NSImage { cachedAmber ?? { let i = dot(NSColor(red: 232/255, green: 162/255, blue: 0, alpha: 1)); cachedAmber = i; return i }() }
    static var dotDisabled: NSImage { cachedRing ?? { let i = ring(NSColor(white: 142/255, alpha: 1)); cachedRing = i; return i }() }

    static func dotFor(_ a: AdapterInfo) -> NSImage {
        if !a.adminEnabled { return dotDisabled }
        return a.isConnected ? dotConnected : dotDisconnected
    }

    private static func dot(_ c: NSColor) -> NSImage {
        NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            let oval = NSBezierPath(ovalIn: rect.insetBy(dx: 3, dy: 3))
            c.setFill(); oval.fill()
            NSColor.black.withAlphaComponent(0.35).setStroke()
            oval.lineWidth = 1
            oval.stroke()
            return true
        }
    }

    private static func ring(_ c: NSColor) -> NSImage {
        NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            let oval = NSBezierPath(ovalIn: rect.insetBy(dx: 3.5, dy: 3.5))
            c.setStroke(); oval.lineWidth = 1.6; oval.stroke()
            return true
        }
    }

    /// Disegna il logo alla dimensione richiesta (coordinate su griglia 32x32).
    static func drawApp(size: CGFloat) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let s = size / 32.0
            let boost: CGFloat = size <= 20 ? 1.25 : 1.0
            let bgRect = NSRect(x: 1 * s, y: 1 * s, width: 30 * s, height: 30 * s)
            let path = NSBezierPath(roundedRect: bgRect, xRadius: 9 * s, yRadius: 9 * s)
            let gradient = NSGradient(starting: NSColor(red: 0x2D/255, green: 0xD4/255, blue: 0xBF/255, alpha: 1),
                                       ending: NSColor(red: 0x02/255, green: 0x84/255, blue: 0xC7/255, alpha: 1))
            gradient?.draw(in: path, angle: -45) // WPF (0,0)->(1,1) ~ in basso a sinistra -> alto a destra

            // nodi collegati da curve (il sistema di coordinate NSImage è "flipped: false",
            // quindi l'asse Y cresce verso l'alto: y' = 32*s - y_originale)
            func P(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x * s, y: (32 - y) * s) }

            let links = NSBezierPath()
            links.lineWidth = 2.6 * s * boost
            links.lineCapStyle = .round
            links.move(to: P(16, 10.5))
            links.curve(to: P(9.5, 21.5), controlPoint1: P(16, 16), controlPoint2: P(9.5, 15.5))
            links.move(to: P(16, 10.5))
            links.curve(to: P(22.5, 21.5), controlPoint1: P(16, 16), controlPoint2: P(22.5, 15.5))
            NSColor.white.setStroke()
            links.stroke()

            func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ color: NSColor) {
                let p = P(cx, cy)
                let oval = NSBezierPath(ovalIn: NSRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
                color.setFill(); oval.fill()
            }
            circle(16, 10, 4.2 * s * boost, .white)
            circle(9.5, 22, 3.3 * s * boost, .white)
            circle(22.5, 22, 3.3 * s * boost, .white)
            circle(16, 10, 1.7 * s * boost, NSColor(red: 0x0E/255, green: 0xA5/255, blue: 0xE9/255, alpha: 1))
            return true
        }
    }

    /// Scrive un'icona .icns multi-risoluzione nella cartella indicata (usata da build.sh).
    static func writeIcns(to path: String) {
        let sizes: [Int] = [16, 32, 128, 256, 512]
        let iconset = path.replacingOccurrences(of: ".icns", with: ".iconset")
        try? FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)
        for size in sizes {
            for scale in [1, 2] {
                let px = size * scale
                let img = drawApp(size: CGFloat(px))
                guard let tiff = img.tiffRepresentation,
                      let rep = NSBitmapImageRep(data: tiff),
                      let png = rep.representation(using: .png, properties: [:]) else { continue }
                let name = scale == 1 ? "icon_\(size)x\(size).png" : "icon_\(size)x\(size)@2x.png"
                try? png.write(to: URL(fileURLWithPath: (iconset as NSString).appendingPathComponent(name)))
            }
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        p.arguments = ["-c", "icns", iconset, "-o", path]
        try? p.run()
        p.waitUntilExit()
        try? FileManager.default.removeItem(atPath: iconset)
    }
}
