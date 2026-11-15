import Foundation

/// Validazione indirizzi e operazioni sulle interfacce (networksetup / ifconfig),
/// porting fedele di NetOps.cs. La logica di validazione IP/CIDR è identica bit per bit.
enum NetOps {

    // ---------------------------------------------------------------- validazione

    static func isValidIPv4(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return false }
        let parts = t.split(separator: ".", omittingEmptySubsequences: false)
        if parts.count != 4 { return false }
        for p in parts {
            if p.isEmpty || p.count > 3 || !p.allSatisfy({ $0.isNumber }) { return false }
            guard let v = Int(p), v <= 255 else { return false }
        }
        return true
    }

    static func toUInt(_ ip: String) -> UInt32 {
        let parts = ip.trimmingCharacters(in: .whitespaces).split(separator: ".").compactMap { UInt32($0) }
        guard parts.count == 4 else { return 0 }
        return (parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3]
    }

    static func fromUInt(_ v: UInt32) -> String {
        return "\((v >> 24) & 255).\((v >> 16) & 255).\((v >> 8) & 255).\(v & 255)"
    }

    static func maskBits(_ prefix: Int) -> UInt32 {
        if prefix <= 0 { return 0 }
        if prefix >= 32 { return 0xFFFFFFFF }
        return 0xFFFFFFFF << (32 - prefix)
    }

    static func maskFromPrefix(_ prefix: Int) -> String { fromUInt(maskBits(prefix)) }

    /// Restituisce il prefisso di una subnet mask, -1 se non valida (non contigua).
    static func prefixFromMask(_ mask: String) -> Int {
        if !isValidIPv4(mask) { return -1 }
        let m = toUInt(mask)
        var prefix = 0
        while prefix < 32 && (m & (0x80000000 >> UInt32(prefix))) != 0 { prefix += 1 }
        return maskBits(prefix) == m ? prefix : -1
    }

    /// Accetta "IP/prefisso" o "IP/subnetmask"; in caso di errore restituisce il messaggio.
    static func tryParseCidr(_ text: String) -> ((ip: String, prefix: Int)?, String?) {
        let t = (text).trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return (nil, "Inserire l'indirizzo IP nel formato IP/subnet (es. 192.168.1.10/24).") }
        guard let slashIdx = t.firstIndex(of: "/") else {
            return (nil, "Manca la subnet: usare il formato IP/subnet (es. 192.168.1.10/24 o 192.168.1.10/255.255.255.0).")
        }
        let ipPart = String(t[t.startIndex..<slashIdx]).trimmingCharacters(in: .whitespaces)
        let snPart = String(t[t.index(after: slashIdx)...]).trimmingCharacters(in: .whitespaces)
        if !isValidIPv4(ipPart) { return (nil, "Indirizzo IP non valido: '\(ipPart)'.") }

        var p: Int
        if snPart.contains(".") {
            p = prefixFromMask(snPart)
            if p < 0 { return (nil, "Subnet mask non valida: '\(snPart)'.") }
        } else if let pp = Int(snPart), pp >= 1, pp <= 32 {
            p = pp
        } else {
            return (nil, "Prefisso subnet non valido: '\(snPart)' (deve essere tra 1 e 32).")
        }
        if p < 1 { return (nil, "Subnet mask non valida.") }

        let addr = toUInt(ipPart)
        if addr == 0 || (addr >> 24) == 127 || (addr >> 28) >= 14 {
            return (nil, "Indirizzo IP non utilizzabile su un'interfaccia: '\(ipPart)'.")
        }
        if p <= 30 {
            let host = addr & ~maskBits(p)
            if host == 0 { return (nil, "\(ipPart) è l'indirizzo di rete della subnet /\(p).") }
            if host == ~maskBits(p) { return (nil, "\(ipPart) è l'indirizzo di broadcast della subnet /\(p).") }
        }
        return ((fromUInt(addr), p), nil)
    }

    /// Uno o più indirizzi IP/subnet separati da virgola, punto e virgola o spazio.
    static func tryParseCidrList(_ text: String) -> (list: [(key: String, value: Int)]?, error: String?) {
        var list: [(key: String, value: Int)] = []
        let norm = text.replacingOccurrences(of: #"\s*/\s*"#, with: "/", options: .regularExpression)
        let parts = norm.split(whereSeparator: { $0 == "," || $0 == ";" || $0 == " " || $0 == "\t" }).map(String.init)
        if parts.isEmpty { return (nil, "Inserire l'indirizzo IP nel formato IP/subnet (es. 192.168.1.10/24).") }
        for p in parts {
            let (r, err) = tryParseCidr(p)
            guard let r = r else { return (nil, err) }
            if list.contains(where: { $0.key == r.ip }) { return (nil, "Indirizzo ripetuto: \(r.ip).") }
            list.append((r.ip, r.prefix))
        }
        return (list, nil)
    }

    static func formatCidrList(_ list: [(key: String, value: Int)]) -> String {
        list.map { "\($0.key)/\($0.value)" }.joined(separator: ", ")
    }

    static func sameSubnet(_ a: String, _ b: String, _ prefix: Int) -> Bool {
        let m = maskBits(prefix)
        return (toUInt(a) & m) == (toUInt(b) & m)
    }

    // ---------------------------------------------------------------- esecuzione comandi

    /// Esegue un processo senza privilegi elevati (letture, non modifica lo stato del sistema).
    @discardableResult
    static func runProcess(_ path: String, _ args: [String]) -> OpResult {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let outPipe = Pipe(), errPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = errPipe
        do { try p.run() } catch { return OpResult(false, "Impossibile avviare \(path): \(error.localizedDescription)") }

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        let so = String(data: outData, encoding: .utf8) ?? ""
        let se = String(data: errData, encoding: .utf8) ?? ""
        let msg = (so + "\n" + se).trimmingCharacters(in: .whitespacesAndNewlines)
        return OpResult(p.terminationStatus == 0, msg)
    }

    /// Esegue un comando come amministratore tramite AppleScript ("do shell script ... with
    /// administrator privileges"), equivalente al prompt UAC di Windows ma per singola operazione:
    /// macOS mostra la richiesta della password solo quando serve.
    @discardableResult
    static func runElevated(_ path: String, _ args: [String]) -> OpResult {
        let inner = ([path] + args).map(shellQuote).joined(separator: " ")
        let script = "do shell script \(appleScriptQuote(inner)) with administrator privileges"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", script]
        let outPipe = Pipe(), errPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = errPipe
        do { try p.run() } catch { return OpResult(false, "Impossibile avviare osascript: \(error.localizedDescription)") }
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        let so = String(data: outData, encoding: .utf8) ?? ""
        var se = String(data: errData, encoding: .utf8) ?? ""
        if se.contains("User canceled") { se = "Operazione annullata (password amministratore non fornita)." }
        let msg = (so + "\n" + se).trimmingCharacters(in: .whitespacesAndNewlines)
        return OpResult(p.terminationStatus == 0, msg)
    }

    /// Esegue una sequenza di comandi che modificano la rete chiedendo la password al massimo
    /// una volta. networksetup per un utente amministratore di solito funziona anche senza
    /// privilegi elevati (nessun prompt): si prova così e, dal primo comando che fallisce (o che
    /// richiede root, come ifconfig alias), i restanti vengono eseguiti tutti insieme in un'unica
    /// chiamata osascript. Il primo comando è quello principale: se fallisce, gli altri non
    /// vengono eseguiti. Restituisce un esito per ogni comando eseguito.
    static func runAdmin(_ cmds: [[String]]) -> [OpResult] {
        var results: [OpResult] = []
        var i = 0
        while i < cmds.count, cmds[i][0] == networksetup {
            let r = runProcess(cmds[i][0], Array(cmds[i].dropFirst()))
            if !r.ok { break }
            results.append(r)
            i += 1
        }
        if i == cmds.count { return results }

        // per ogni comando: output e codice di uscita, separati da un marcatore
        var script = ""
        for (k, c) in cmds[i...].enumerated() {
            script += "out=$(\(c.map(shellQuote).joined(separator: " ")) 2>&1); rc=$?; printf '%s\\n\(rcMarker)%d\\n' \"$out\" $rc; "
            if k == 0 && i == 0 { script += "[ $rc -eq 0 ] || exit 0; " }
        }
        let r = runElevated("/bin/sh", ["-c", script])
        guard r.ok else {
            // osascript non riuscito (es. password non fornita): nessun comando eseguito
            return results + [OpResult(false, r.message)]
        }
        var buf: [String] = []
        for line in r.message.components(separatedBy: "\n") {
            if line.hasPrefix(rcMarker) {
                results.append(OpResult(line.dropFirst(rcMarker.count) == "0", buf.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)))
                buf = []
            } else { buf.append(line) }
        }
        return results
    }

    private static let rcMarker = "__NETSWITCH_RC__"

    private static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleScriptQuote(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    static let networksetup = "/usr/sbin/networksetup"
    static let ifconfig = "/sbin/ifconfig"

    // ---------------------------------------------------------------- operazioni

    static func apply(_ a: AdapterInfo, _ c: SavedConfig) -> OpResult {
        if c.dhcp { return applyDhcp(a) }
        let (parsedAddrs, parseErr) = tryParseCidrList(c.address)
        guard let addrs = parsedAddrs else {
            return OpResult(false, parseErr ?? "Indirizzo non valido.")
        }
        var dns: [String] = []
        if !c.dns1.trimmingCharacters(in: .whitespaces).isEmpty { dns.append(c.dns1.trimmingCharacters(in: .whitespaces)) }
        if !c.dns2.trimmingCharacters(in: .whitespaces).isEmpty { dns.append(c.dns2.trimmingCharacters(in: .whitespaces)) }
        return applyStatic(a, addrs, c.gateway.trimmingCharacters(in: .whitespaces), dns)
    }

    /// Indirizzi aggiuntivi impostati come alias con ifconfig: tutti gli IPv4 del device
    /// diversi dall'indirizzo principale gestito da networksetup.
    private static func aliases(of a: AdapterInfo) -> [String] {
        a.addresses.map { $0.components(separatedBy: "/")[0] }.filter { $0 != a.primaryIP }
    }

    /// Comandi per togliere gli alias che non fanno parte della nuova configurazione: né
    /// networksetup -setdhcp né -setmanual li rimuovono.
    private static func removeAliasCommands(_ a: AdapterInfo, keeping keep: [String]) -> [[String]] {
        guard !a.device.isEmpty else { return [] }
        return aliases(of: a).filter { !keep.contains($0) }.map { [ifconfig, a.device, "-alias", $0] }
    }

    static func applyStatic(_ a: AdapterInfo, _ addrs: [(key: String, value: Int)], _ gateway: String, _ dns: [String]) -> OpResult {
        let serviceName = a.name, deviceName = a.device
        let mask = maskFromPrefix(addrs[0].value)
        var cmds: [[String]] = [[networksetup, "-setmanual", serviceName, addrs[0].key, mask, gateway]]
        var labels = [""]
        cmds.append([networksetup, "-setdnsservers", serviceName] + (dns.isEmpty ? ["Empty"] : dns))
        labels.append(dns.isEmpty ? "Rimozione DNS" : "DNS")
        for r in removeAliasCommands(a, keeping: addrs.map { $0.key }) {
            cmds.append(r)
            labels.append("Rimozione indirizzo \(r[3])")
        }
        // networksetup non supporta più indirizzi sulla stessa interfaccia: gli indirizzi
        // aggiuntivi vengono aggiunti come alias (non persistono dopo un riavvio).
        for i in 1..<addrs.count {
            cmds.append([ifconfig, deviceName, "alias", addrs[i].key, "netmask", maskFromPrefix(addrs[i].value)])
            labels.append("Indirizzo \(addrs[i].key)/\(addrs[i].value)")
        }
        let res = runAdmin(cmds)
        if res.isEmpty || !res[0].ok {
            return OpResult(false, "Impossibile impostare l'indirizzo IP su '\(serviceName)'.\n\n\(res.first?.message ?? "")")
        }
        var warnings: [String] = []
        for k in 1..<cmds.count {
            if k >= res.count { warnings.append("\(labels[k]): non eseguito. \(res.last?.message ?? "")"); continue }
            if !res[k].ok { warnings.append("\(labels[k]): \(res[k].message)") }
        }

        var msg = "\(serviceName): \(formatCidrList(addrs))"
        if !gateway.isEmpty { msg += "  gw \(gateway)" }
        if !dns.isEmpty { msg += "  dns \(dns.joined(separator: ", "))" }
        if !warnings.isEmpty {
            return OpResult(false, "Indirizzo IP principale impostato, ma con alcuni errori:\n\n" + warnings.joined(separator: "\n"))
        }
        return OpResult(true, msg)
    }

    static func applyDhcp(_ a: AdapterInfo) -> OpResult {
        let serviceName = a.name
        let res = runAdmin([[networksetup, "-setdhcp", serviceName], [networksetup, "-setdnsservers", serviceName, "Empty"]]
                           + removeAliasCommands(a, keeping: []))
        if res.isEmpty || !res[0].ok {
            return OpResult(false, "Impossibile attivare il DHCP su '\(serviceName)'.\n\n\(res.first?.message ?? "")")
        }
        let d = res.count > 1 ? res[1] : OpResult(false, "non eseguito")
        var note = d.ok ? "" : " (DNS: \(d.message))"
        if res.dropFirst(2).contains(where: { !$0.ok }) { note += " (alcuni indirizzi aggiuntivi non sono stati rimossi)" }
        return OpResult(true, "\(serviceName): indirizzo e DNS automatici (DHCP)\(note)")
    }

    static func setEnabled(_ serviceName: String, _ enable: Bool) -> OpResult {
        let r = runAdmin([[networksetup, "-setnetworkserviceenabled", serviceName, enable ? "on" : "off"]]).first ?? OpResult(false, "")
        if r.ok { return OpResult(true, "\(serviceName) \(enable ? "attivata" : "disattivata")") }
        return OpResult(false, "Operazione non riuscita su '\(serviceName)'.\n\n\(r.message)")
    }
}
