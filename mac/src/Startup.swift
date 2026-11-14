import Foundation

/// Avvio automatico all'accesso tramite LaunchAgent (equivalente mac dell'Utilità di
/// pianificazione usata su Windows in Startup.cs). A differenza del Task Scheduler non
/// gira con privilegi elevati: i singoli comandi di rete richiedono comunque la password
/// di amministratore quando serve (vedi NetOps.runElevated).
enum Startup {
    static let label = "ch.netswit.netswitch"

    static var plistPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist").path
    }

    static let launchctl = "/bin/launchctl"

    static func isEnabled() -> Bool {
        FileManager.default.fileExists(atPath: plistPath)
    }

    static func enable() -> OpResult {
        let exe = Bundle.main.executablePath ?? CommandLine.arguments[0]
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [exe, "--background"],
            "RunAtLoad": true,
            "ProcessType": "Interactive",
            "LimitLoadToSessionType": ["Aqua"],
        ]
        do {
            let dir = (plistPath as NSString).deletingLastPathComponent
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: URL(fileURLWithPath: plistPath))
        } catch {
            return OpResult(false, "Impossibile scrivere il LaunchAgent: \(error.localizedDescription)")
        }
        let uid = getuid()
        let r = NetOps.runProcess(launchctl, ["bootstrap", "gui/\(uid)", plistPath])
        if r.ok || r.message.contains("already bootstrapped") {
            return OpResult(true, "NetSwitch verrà avviato all'accesso al Mac.")
        }
        // alcune versioni di launchctl non supportano 'bootstrap' per servizi utente: fallback
        let legacy = NetOps.runProcess(launchctl, ["load", "-w", plistPath])
        return legacy.ok ? OpResult(true, "NetSwitch verrà avviato all'accesso al Mac.") : legacy
    }

    static func disable() -> OpResult {
        let uid = getuid()
        _ = NetOps.runProcess(launchctl, ["bootout", "gui/\(uid)", plistPath])
        _ = NetOps.runProcess(launchctl, ["unload", "-w", plistPath])
        do {
            if FileManager.default.fileExists(atPath: plistPath) {
                try FileManager.default.removeItem(atPath: plistPath)
            }
            return OpResult(true, "Avvio automatico disattivato.")
        } catch {
            return OpResult(false, "Impossibile rimuovere il LaunchAgent: \(error.localizedDescription)")
        }
    }
}
