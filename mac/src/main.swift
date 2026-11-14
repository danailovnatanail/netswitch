import AppKit

/// Punto di ingresso, equivalente a Program.cs: gestisce le modalità diagnostiche
/// (--dump, --make-icon), l'istanza singola (al posto del Mutex di Windows si usa un
/// file di lock con flock, e al posto dell'EventWaitHandle una notifica distribuita)
/// e l'avvio dell'applicazione AppKit.

/// Istanza singola: rilanciare l'app mentre è già attiva chiede all'istanza esistente
/// di mostrare il pannello, invece di aprirne una seconda.
enum SingleInstance {
    private static let base = "ch.netswit.netswitch.show"
    static var showNotificationName: String { base + (Program.debugOn ? ".debug" : "") }

    private static var lockPath: String {
        (ConfigStore.folder as NSString).appendingPathComponent(".lock" + (Program.debugOn ? "_debug" : ""))
    }

    private static var lockFd: Int32 = -1

    /// true se questa è la prima istanza (ha ottenuto il lock esclusivo).
    static func acquire() -> Bool {
        try? FileManager.default.createDirectory(atPath: ConfigStore.folder, withIntermediateDirectories: true)
        let fd = open(lockPath, O_CREAT | O_RDWR, 0o600)
        if fd == -1 { return true } // non dovrebbe succedere; si prosegue comunque come istanza unica
        if flock(fd, LOCK_EX | LOCK_NB) != 0 {
            close(fd)
            return false
        }
        lockFd = fd
        return true
    }

    static func signalShow() {
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name(showNotificationName), object: nil, userInfo: nil, deliverImmediately: true)
    }
}

/// Modalità diagnostica: NetSwitch --dump <file> (stesso output informativo di Program.Dump).
func runDump(to path: String) {
    var lines: [String] = []
    for a in NetInfo.getAdapters() {
        lines.append("== " + a.name)
        lines.append("   Stato:   \(a.statusText) (admin \(a.adminEnabled ? "on" : "off"), present \(a.present))")
        lines.append("   Modo:    \(a.modeText)")
        lines.append("   IP:      \(a.addressText)")
        lines.append("   GW:      \(a.gatewayText)")
        lines.append("   DNS:     \(a.dnsText)")
        lines.append("   MAC:     \(a.mac)")
        lines.append("   Vel.:    \(a.speedText)")
        lines.append("   Descr.:  \(a.description)")
    }

    lines.append("")
    lines.append("== Test parsing IP/subnet")
    for t in ["192.168.1.10/24", "10.0.0.5/255.255.0.0", "10.0.0.5/255.0.255.0", "192.168.1.10",
              "300.1.1.1/24", "1.2.3/24", "172.16.5.4/33", " 192.168.100.1 / 30 "] {
        let (r, err) = NetOps.tryParseCidrVerbose(t)
        if let r = r { lines.append("   '\(t)' -> \(r.ip)/\(r.prefix) mask \(NetOps.maskFromPrefix(r.prefix))") }
        else { lines.append("   '\(t)' -> ERR: \(err ?? "")") }
    }
    for t in ["10.1.2.3/23, 192.168.20.5/24;192.168.30.5 / 24", "10.0.0.1/24, 10.0.0.1/24", "10.0.0.1/24, x"] {
        let (list, err) = NetOps.tryParseCidrList(t)
        if let list = list { lines.append("   LIST '\(t)' -> \(NetOps.formatCidrList(list))") }
        else { lines.append("   LIST '\(t)' -> ERR: \(err ?? "")") }
    }
    lines.append("   SameSubnet(192.168.1.10, 192.168.1.1, 24) = \(NetOps.sameSubnet("192.168.1.10", "192.168.1.1", 24))")
    lines.append("   SameSubnet(192.168.1.10, 192.168.2.1, 24) = \(NetOps.sameSubnet("192.168.1.10", "192.168.2.1", 24))")
    try? lines.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
}

// ---------------------------------------------------------------- avvio

let arguments = CommandLine.arguments

if arguments.count >= 3, arguments[1] == "--dump" {
    runDump(to: arguments[2])
    exit(0)
}
if arguments.count >= 3, arguments[1] == "--make-icon" {
    AppIcon.writeIcns(to: arguments[2])
    exit(0)
}

let backgroundFlag = arguments.contains("--background")

if !SingleInstance.acquire() {
    SingleInstance.signalShow()
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate(background: backgroundFlag)
app.delegate = delegate
app.run()
