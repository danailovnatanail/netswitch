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

    /// Accetta "IP/prefisso" o "IP/subnetmask".
    static func tryParseCidr(_ text: String) -> (ip: String, prefix: Int)? {
        let (r, _) = tryParseCidrVerbose(text)
        return r
    }

    static func tryParseCidrVerbose(_ text: String) -> ((ip: String, prefix: Int)?, String?) {
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
            let (r, err) = tryParseCidrVerbose(p)
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

    private static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleScriptQuote(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    static let networksetup = "/usr/sbin/networksetup"
    static let ifconfig = "/sbin/ifconfig"

    // ---------------------------------------------------------------- operazioni

    static func apply(_ serviceName: String, _ deviceName: String, _ c: SavedConfig) -> OpResult {
        if c.dhcp { return applyDhcp(serviceName) }
        guard let addrs = tryParseCidrList(c.address).list else {
            return OpResult(false, tryParseCidrList(c.address).error ?? "Indirizzo non valido.")
        }
        var dns: [String] = []
        if !c.dns1.trimmingCharacters(in: .whitespaces).isEmpty { dns.append(c.dns1.trimmingCharacters(in: .whitespaces)) }
        if !c.dns2.trimmingCharacters(in: .whitespaces).isEmpty { dns.append(c.dns2.trimmingCharacters(in: .whitespaces)) }
        return applyStatic(serviceName, deviceName, addrs, c.gateway.trimmingCharacters(in: .whitespaces), dns)
    }

    static func applyStatic(_ serviceName: String, _ deviceName: String, _ addrs: [(key: String, value: Int)], _ gateway: String, _ dns: [String]) -> OpResult {
        let mask = maskFromPrefix(addrs[0].value)
        let r = runElevated(networksetup, ["-setmanual", serviceName, addrs[0].key, mask, gateway])
        if !r.ok {
            return OpResult(false, "Impossibile impostare l'indirizzo IP su '\(serviceName)'.\n\n\(r.message)")
        }

        var warnings: [String] = []
        // networksetup non supporta più indirizzi sulla stessa interfaccia: gli indirizzi
        // aggiuntivi vengono aggiunti come alias (non persistono dopo un riavvio).
        for i in 1..<addrs.count {
            let a = runElevated(ifconfig, [deviceName, "alias", addrs[i].key, "netmask", maskFromPrefix(addrs[i].value)])
            if !a.ok { warnings.append("Indirizzo \(addrs[i].key)/\(addrs[i].value): \(a.message)") }
        }

        let d: OpResult
        if dns.isEmpty {
            d = runElevated(networksetup, ["-setdnsservers", serviceName, "Empty"])
            if !d.ok { warnings.append("Rimozione DNS: \(d.message)") }
        } else {
            d = runElevated(networksetup, ["-setdnsservers", serviceName] + dns)
            if !d.ok { warnings.append("DNS: \(d.message)") }
        }

        var msg = "\(serviceName): \(formatCidrList(addrs))"
        if !gateway.isEmpty { msg += "  gw \(gateway)" }
        if !dns.isEmpty { msg += "  dns \(dns.joined(separator: ", "))" }
        if !warnings.isEmpty {
            return OpResult(false, "Indirizzo IP principale impostato, ma con alcuni errori:\n\n" + warnings.joined(separator: "\n"))
        }
        return OpResult(true, msg)
    }

    static func applyDhcp(_ serviceName: String) -> OpResult {
        let r = runElevated(networksetup, ["-setdhcp", serviceName])
        if !r.ok {
            return OpResult(false, "Impossibile attivare il DHCP su '\(serviceName)'.\n\n\(r.message)")
        }
        let d = runElevated(networksetup, ["-setdnsservers", serviceName, "Empty"])
        let note = d.ok ? "" : " (DNS: \(d.message))"
        return OpResult(true, "\(serviceName): indirizzo e DNS automatici (DHCP)\(note)")
    }

    static func setEnabled(_ serviceName: String, _ enable: Bool) -> OpResult {
        let r = runElevated(networksetup, ["-setnetworkserviceenabled", serviceName, enable ? "on" : "off"])
        if r.ok { return OpResult(true, "\(serviceName) \(enable ? "attivata" : "disattivata")") }
        return OpResult(false, "Operazione non riuscita su '\(serviceName)'.\n\n\(r.message)")
    }
}
