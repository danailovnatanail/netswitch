import Foundation

/// Informazioni su una connessione di rete (porting di AdapterInfo in NetInfo.cs).
/// I codici di ConnectionStatus mantengono lo stesso significato della versione Windows,
/// per poter riusare la stessa logica di presentazione (StatusText, IsConnected, ecc.);
/// su macOS se ne riconosce in modo affidabile solo un sottoinsieme.
final class AdapterInfo {
    var name: String = ""            // nome del "network service" (es. Wi-Fi, Ethernet)
    var hardwarePort: String = ""
    var device: String = ""          // es. en0
    var mac: String = ""
    var adminEnabled: Bool = true
    var connectionStatus: Int = -1
    var present: Bool = false
    var dhcp: Bool = false
    var speed: Int64 = 0
    var addresses: [String] = []
    var gateways: [String] = []
    var dns: [String] = []
    /// Indirizzo principale del servizio secondo networksetup -getinfo (statico o da DHCP);
    /// gli altri IPv4 presenti sul device sono alias aggiunti con ifconfig.
    var primaryIP: String = ""

    /// Identificativo stabile dell'interfaccia (equivalente al GUID su Windows): il nome del
    /// servizio, perché più servizi possono condividere lo stesso device (es. en5).
    var key: String { name }

    var description: String {
        hardwarePort.isEmpty ? name : (device.isEmpty ? hardwarePort : "\(hardwarePort) (\(device))")
    }

    var isConnected: Bool { adminEnabled && connectionStatus == 2 }

    var statusText: String {
        if !adminEnabled { return "Disattivata" }
        switch connectionStatus {
        case 0: return "Disconnessa"
        case 2: return "Connessa"
        case 7: return "Cavo scollegato"
        default: return "Sconosciuto"
        }
    }

    var modeText: String {
        if !present && addresses.isEmpty && !dhcp { return "-" }
        return dhcp ? "DHCP" : "Statico"
    }

    private static func join(_ l: [String]) -> String { l.isEmpty ? "-" : l.joined(separator: ", ") }
    var addressText: String { AdapterInfo.join(addresses) }
    var gatewayText: String { AdapterInfo.join(gateways) }
    var dnsText: String { AdapterInfo.join(dns) }

    var speedText: String {
        if !isConnected || speed <= 0 { return "" }
        if speed >= 1_000_000_000 { return String(format: "%.1f Gbps", Double(speed) / 1_000_000_000.0) }
        return String(format: "%.1f Mbps", Double(speed) / 1_000_000.0)
    }
}

enum NetInfo {

    static func getAdapters() -> [AdapterInfo] {
        if Program.fake { return DemoData.adapters() }

        let hwPorts = parseHardwarePorts()                 // device -> (hardwarePort, mac)
        let order = parseServiceOrder()                    // [(service, hardwarePort, device)]
        let enabledSet = parseEnabledServices()             // service -> enabled
        let vpnStatus = parseVpnStatus()                    // service -> connesso

        var list: [AdapterInfo] = []
        var usedDevices = Set<String>()
        for entry in order {
            let a = AdapterInfo()
            a.name = entry.service
            a.hardwarePort = entry.hardwarePort
            a.device = entry.device
            a.adminEnabled = enabledSet[entry.service] ?? true
            if let hw = hwPorts[entry.device] { a.mac = hw.mac }
            fillFromGetInfo(a)
            if let connected = vpnStatus[entry.service] {
                // servizio VPN (nessun device): lo stato viene da scutil --nc
                a.connectionStatus = connected ? 2 : 0
            } else if !a.device.isEmpty {
                if usedDevices.contains(a.device) {
                    // più servizi sullo stesso device: macOS attiva solo il primo abilitato
                    // nell'ordine dei servizi, gli altri restano inattivi
                    a.present = NetOps.runProcess(NetOps.ifconfig, [a.device]).ok
                    a.connectionStatus = 0
                } else {
                    fillFromIfconfig(a)
                    if a.adminEnabled { usedDevices.insert(a.device) }
                }
            }
            list.append(a)
        }

        if Program.debugOn && ProcessInfo.processInfo.environment["NETSWITCH_DEMO"] == "states" {
            // simula interfacce attive ma non collegate, per verificare la grafica
            let off = list.filter { !$0.adminEnabled }.prefix(2)
            if off.count > 0 {
                off[0].adminEnabled = true; off[0].connectionStatus = 7
                if off[0].addresses.isEmpty { off[0].addresses.append("192.168.50.10/24") }
            }
            if off.count > 1 { off[1].adminEnabled = true; off[1].connectionStatus = 0; off[1].dhcp = true }
        }

        return list.sorted { l, r in
            let gl = l.isConnected ? 0 : (l.adminEnabled ? 1 : 2)
            let gr = r.isConnected ? 0 : (r.adminEnabled ? 1 : 2)
            if gl != gr { return gl < gr }
            return l.name.localizedCaseInsensitiveCompare(r.name) == .orderedAscending
        }
    }

    // ---------------------------------------------------------------- networksetup -listallhardwareports

    private static func parseHardwarePorts() -> [String: (hardwarePort: String, mac: String)] {
        let r = NetOps.runProcess(NetOps.networksetup, ["-listallhardwareports"])
        var result: [String: (String, String)] = [:]
        var currentPort = "", currentDevice = ""
        for rawLine in r.message.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("Hardware Port:") {
                currentPort = line.replacingOccurrences(of: "Hardware Port:", with: "").trimmingCharacters(in: .whitespaces)
                currentDevice = ""
            } else if line.hasPrefix("Device:") {
                currentDevice = line.replacingOccurrences(of: "Device:", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("Ethernet Address:") {
                let mac = line.replacingOccurrences(of: "Ethernet Address:", with: "").trimmingCharacters(in: .whitespaces)
                if !currentDevice.isEmpty { result[currentDevice] = (currentPort, mac == "N/A" ? "" : mac) }
            }
        }
        return result
    }

    // ---------------------------------------------------------------- networksetup -listnetworkserviceorder

    private static func parseServiceOrder() -> [(service: String, hardwarePort: String, device: String)] {
        let r = NetOps.runProcess(NetOps.networksetup, ["-listnetworkserviceorder"])
        var result: [(String, String, String)] = []
        var pendingService: String? = nil
        for rawLine in r.message.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("(Hardware Port:") {
                // riga di dettaglio: "(Hardware Port: Wi-Fi, Device: en0)"
                let inner = line.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
                var hw = "", dev = ""
                for part in inner.components(separatedBy: ",") {
                    let kv = part.trimmingCharacters(in: .whitespaces)
                    if kv.hasPrefix("Hardware Port:") { hw = kv.replacingOccurrences(of: "Hardware Port:", with: "").trimmingCharacters(in: .whitespaces) }
                    else if kv.hasPrefix("Device:") { dev = kv.replacingOccurrences(of: "Device:", with: "").trimmingCharacters(in: .whitespaces) }
                }
                if let svc = pendingService { result.append((svc, hw, dev)) }
                pendingService = nil
            } else if line.hasPrefix("("), let closeParen = line.firstIndex(of: ")") {
                // riga "(1) Wi-Fi"
                pendingService = line[line.index(after: closeParen)...].trimmingCharacters(in: .whitespaces)
            }
        }
        return result
    }

    // ---------------------------------------------------------------- networksetup -listallnetworkservices

    private static func parseEnabledServices() -> [String: Bool] {
        let r = NetOps.runProcess(NetOps.networksetup, ["-listallnetworkservices"])
        var result: [String: Bool] = [:]
        var first = true
        for rawLine in r.message.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if first { first = false; continue } // "An asterisk (*) denotes..."
            if line.hasPrefix("*") {
                result[String(line.dropFirst())] = false
            } else {
                result[line] = true
            }
        }
        return result
    }

    // ---------------------------------------------------------------- scutil --nc list

    private static func parseVpnStatus() -> [String: Bool] {
        // es: '* (Disconnected)   84D6...  VPN (com.wireguard.macos) "Nome"   [VPN:...]'
        let r = NetOps.runProcess("/usr/sbin/scutil", ["--nc", "list"])
        var result: [String: Bool] = [:]
        for line in r.message.components(separatedBy: "\n") {
            guard let open = line.firstIndex(of: "("), let close = line[open...].firstIndex(of: ")"),
                  let q1 = line.firstIndex(of: "\""), let q2 = line[line.index(after: q1)...].firstIndex(of: "\"") else { continue }
            let state = line[line.index(after: open)..<close]
            result[String(line[line.index(after: q1)..<q2])] = (state == "Connected")
        }
        return result
    }

    // ---------------------------------------------------------------- networksetup -getinfo <service>

    private static func fillFromGetInfo(_ a: AdapterInfo) {
        let r = NetOps.runProcess(NetOps.networksetup, ["-getinfo", a.name])
        let lines = r.message.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        if lines.isEmpty { return }
        let head = lines.first ?? ""
        a.dhcp = head.hasPrefix("DHCP") || head.hasPrefix("BootP")
        var ip: String? = nil, mask: String? = nil, router: String? = nil
        for line in lines {
            if line.hasPrefix("IP address:") { ip = value(of: line) }
            else if line.hasPrefix("Subnet mask:") { mask = value(of: line) }
            else if line.hasPrefix("Router:") { router = value(of: line) }
        }
        if let ip = ip, NetOps.isValidIPv4(ip) {
            a.primaryIP = ip
            let prefix = mask.flatMap { NetOps.prefixFromMask($0) >= 0 ? NetOps.prefixFromMask($0) : nil } ?? 24
            if !a.addresses.contains(where: { $0.hasPrefix(ip + "/") }) {
                a.addresses.append("\(ip)/\(prefix)")
            }
        }
        if let router = router, NetOps.isValidIPv4(router) { a.gateways.append(router) }

        let d = NetOps.runProcess(NetOps.networksetup, ["-getdnsservers", a.name])
        if !d.message.lowercased().contains("there aren't any dns servers") {
            for line in d.message.components(separatedBy: "\n") {
                let s = line.trimmingCharacters(in: .whitespaces)
                if NetOps.isValidIPv4(s), !a.dns.contains(s) { a.dns.append(s) }
            }
        }
        if a.dns.isEmpty && a.dhcp && !a.device.isEmpty {
            // nessun DNS manuale: quelli ottenuti dal DHCP (come DnsAddresses su Windows)
            let p = NetOps.runProcess("/usr/sbin/ipconfig", ["getpacket", a.device])
            for line in p.message.components(separatedBy: "\n") where line.hasPrefix("domain_name_server") {
                guard let o = line.firstIndex(of: "{"), let c = line.firstIndex(of: "}"), o < c else { continue }
                for d in line[line.index(after: o)..<c].components(separatedBy: ",") {
                    let s = d.trimmingCharacters(in: .whitespaces)
                    if NetOps.isValidIPv4(s), !a.dns.contains(s) { a.dns.append(s) }
                }
            }
        }
    }

    private static func value(of line: String) -> String {
        guard let colon = line.firstIndex(of: ":") else { return "" }
        return String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
    }

    // ---------------------------------------------------------------- ifconfig <device>

    private static func fillFromIfconfig(_ a: AdapterInfo) {
        let r = NetOps.runProcess(NetOps.ifconfig, [a.device])
        guard r.ok || !r.message.isEmpty else { return }
        a.present = r.ok
        var sawAddress = false
        for rawLine in r.message.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("ether ") {
                let mac = line.replacingOccurrences(of: "ether ", with: "").trimmingCharacters(in: .whitespaces)
                if a.mac.isEmpty { a.mac = mac }
            } else if line.hasPrefix("inet ") {
                let parts = line.split(separator: " ").map(String.init)
                guard parts.count >= 2 else { continue }
                let ip = parts[1]
                var prefix = 24
                if let nmIdx = parts.firstIndex(of: "netmask"), nmIdx + 1 < parts.count {
                    prefix = prefixFromHexMask(parts[nmIdx + 1]) ?? 24
                }
                let entry = "\(ip)/\(prefix)"
                if !a.addresses.contains(where: { $0.hasPrefix(ip + "/") }) { a.addresses.append(entry) }
                sawAddress = true
            } else if line.hasPrefix("status:") {
                let s = value(of: line)
                a.connectionStatus = (s == "active") ? 2 : 7
            } else if line.contains("media:") {
                if let speed = speedFromMediaLine(line) { a.speed = speed }
            }
        }
        if a.connectionStatus == -1 {
            // alcune interfacce (es. Wi-Fi) non riportano "status:": si deduce dalla presenza di un indirizzo
            a.connectionStatus = sawAddress ? 2 : 0
        }
    }

    private static func prefixFromHexMask(_ hex: String) -> Int? {
        var h = hex
        if h.hasPrefix("0x") { h.removeFirst(2) }
        guard let v = UInt32(h, radix: 16) else { return nil }
        return NetOps.prefixFromMask(NetOps.fromUInt(v))
    }

    private static func speedFromMediaLine(_ line: String) -> Int64? {
        // es: "media: autoselect (1000baseT <full-duplex>)" oppure "media: 100baseTX <full-duplex>"
        let pattern = #"(\d+)base"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line),
              let mbps = Int64(line[range]) else { return nil }
        return mbps * 1_000_000
    }
}
