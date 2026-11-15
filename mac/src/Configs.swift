import Foundation

/// Configurazione IP salvata, applicabile a qualsiasi interfaccia (equivalente a SavedConfig in Configs.cs).
final class SavedConfig {
    var name: String = ""
    var dhcp: Bool = false
    var address: String = ""   // formato IP/prefisso
    var gateway: String = ""
    var dns1: String = ""
    var dns2: String = ""

    init() {}

    var dnsText: String {
        var l: [String] = []
        if !dns1.trimmingCharacters(in: .whitespaces).isEmpty { l.append(dns1) }
        if !dns2.trimmingCharacters(in: .whitespaces).isEmpty { l.append(dns2) }
        return l.joined(separator: ", ")
    }

    var summary: String {
        if dhcp { return "DHCP (automatico)" }
        var s = address
        if !gateway.trimmingCharacters(in: .whitespaces).isEmpty { s += "  gw " + gateway }
        if !dnsText.isEmpty { s += "  dns " + dnsText }
        return s
    }

    func clone() -> SavedConfig {
        let c = SavedConfig()
        c.name = name; c.dhcp = dhcp; c.address = address; c.gateway = gateway; c.dns1 = dns1; c.dns2 = dns2
        return c
    }
}

/// Caricamento/salvataggio delle configurazioni su XML, compatibile con il formato
/// prodotto da XmlSerializer su Windows (ArrayOfSavedConfig/SavedConfig).
enum ConfigStore {
    static var folder: String {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/NetSwitch", isDirectory: true)
        return base.path
    }

    static var filePath: String { (folder as NSString).appendingPathComponent("configurazioni.xml") }

    static func load() -> [SavedConfig] {
        if Program.fake { return DemoData.configs() }
        let path = filePath
        guard FileManager.default.fileExists(atPath: path),
              let data = FileManager.default.contents(atPath: path) else { return [] }
        if let list = try? parse(data) { return list }
        // file corrotto: lo conserva come backup e riparte vuoto
        try? FileManager.default.removeItem(atPath: path + ".bak")
        try? FileManager.default.copyItem(atPath: path, toPath: path + ".bak")
        return []
    }

    static func save(_ list: [SavedConfig]) throws {
        if Program.fake { return } // i dati fittizi non vanno mai salvati
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        let xml = serialize(list)
        let tmp = filePath + ".tmp"
        try xml.write(toFile: tmp, atomically: true, encoding: .utf8)
        if FileManager.default.fileExists(atPath: filePath) {
            _ = try FileManager.default.replaceItemAt(URL(fileURLWithPath: filePath), withItemAt: URL(fileURLWithPath: tmp))
        } else {
            try FileManager.default.moveItem(atPath: tmp, toPath: filePath)
        }
    }

    private static func xmlEscape(_ s: String) -> String {
        var r = s
        r = r.replacingOccurrences(of: "&", with: "&amp;")
        r = r.replacingOccurrences(of: "<", with: "&lt;")
        r = r.replacingOccurrences(of: ">", with: "&gt;")
        return r
    }

    private static func serialize(_ list: [SavedConfig]) -> String {
        var s = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"
        s += "<ArrayOfSavedConfig>\n"
        for c in list {
            s += "  <SavedConfig>\n"
            s += "    <Name>\(xmlEscape(c.name))</Name>\n"
            s += "    <Dhcp>\(c.dhcp ? "true" : "false")</Dhcp>\n"
            s += "    <Address>\(xmlEscape(c.address))</Address>\n"
            s += "    <Gateway>\(xmlEscape(c.gateway))</Gateway>\n"
            s += "    <Dns1>\(xmlEscape(c.dns1))</Dns1>\n"
            s += "    <Dns2>\(xmlEscape(c.dns2))</Dns2>\n"
            s += "  </SavedConfig>\n"
        }
        s += "</ArrayOfSavedConfig>\n"
        return s
    }

    private static func parse(_ data: Data) throws -> [SavedConfig] {
        let parser = XMLParser(data: data)
        let delegate = ConfigXmlDelegate()
        parser.delegate = delegate
        if !parser.parse() {
            throw NSError(domain: "ConfigStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "XML non valido"])
        }
        return delegate.list
    }
}

private final class ConfigXmlDelegate: NSObject, XMLParserDelegate {
    var list: [SavedConfig] = []
    var current: SavedConfig?
    var currentElement: String = ""
    var text: String = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        text = ""
        if elementName == "SavedConfig" { current = SavedConfig() }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard let c = current else { return }
        switch elementName {
        case "Name": c.name = text
        case "Dhcp": c.dhcp = (text.trimmingCharacters(in: .whitespacesAndNewlines) == "true")
        case "Address": c.address = text
        case "Gateway": c.gateway = text
        case "Dns1": c.dns1 = text
        case "Dns2": c.dns2 = text
        case "SavedConfig": list.append(c); current = nil
        default: break
        }
    }
}
