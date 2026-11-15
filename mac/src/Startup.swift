import Foundation

/// Avvio automatico all'accesso tramite LaunchAgent (equivalente mac dell'Utilità di
/// pianificazione usata su Windows in Startup.cs). A differenza del Task Scheduler non
/// gira con privilegi elevati: quando un comando di rete li richiede, viene chiesta la
/// password di amministratore (vedi NetOps.runAdmin).
enum Startup {
    static let label = "ch.netswit.netswitch"

    static var plistPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist").path
    }

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
        // Nessun 'launchctl bootstrap': con RunAtLoad avvierebbe subito una seconda istanza.
        // launchd carica i LaunchAgent della cartella utente al prossimo accesso.
        return OpResult(true, "NetSwitch verrà avviato all'accesso al Mac.")
    }

    static func disable() -> OpResult {
        // Solo rimozione del file: 'launchctl bootout' terminerebbe anche questa istanza,
        // se è stata avviata dal LaunchAgent all'accesso.
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
