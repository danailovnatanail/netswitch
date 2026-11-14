import Foundation

/// Dati fittizi usati solo per gli screenshot della documentazione
/// (NETSWITCH_DEBUG=1 e NETSWITCH_FAKE=1): nessuna informazione reale del Mac.
/// Porting diretto di DemoData.cs.
enum DemoData {
    static func adapters() -> [AdapterInfo] {
        var list: [AdapterInfo] = []

        let eth = AdapterInfo()
        eth.name = "Ethernet"; eth.hardwarePort = "Ethernet"; eth.device = "en5"
        eth.mac = "00-1A-2B-3C-4D-5E"; eth.connectionStatus = 2; eth.present = true
        eth.dhcp = false; eth.speed = 1_000_000_000
        eth.addresses = ["192.168.10.20/24", "10.0.0.20/24"]
        eth.gateways = ["192.168.10.1"]
        eth.dns = ["1.1.1.1", "8.8.8.8"]
        list.append(eth)

        let wifi = AdapterInfo()
        wifi.name = "Wi-Fi"; wifi.hardwarePort = "Wi-Fi"; wifi.device = "en0"
        wifi.mac = "A4-B1-C2-D3-E4-F5"; wifi.connectionStatus = 2; wifi.present = true
        wifi.dhcp = true; wifi.speed = 866_000_000
        wifi.addresses = ["192.168.1.34/24"]
        wifi.gateways = ["192.168.1.1"]
        wifi.dns = ["192.168.1.1"]
        list.append(wifi)

        let usb = AdapterInfo()
        usb.name = "Ethernet USB"; usb.hardwarePort = "Ethernet Adapter (en6)"; usb.device = "en6"
        usb.mac = "00-E0-4C-68-01-02"; usb.connectionStatus = 7; usb.present = true
        usb.dhcp = false
        usb.addresses = ["172.16.0.10/16"]
        list.append(usb)

        let bt = AdapterInfo()
        bt.name = "Bluetooth PAN"; bt.hardwarePort = "Bluetooth PAN"; bt.device = "en7"
        bt.mac = "A4-B1-C2-D3-E4-F9"; bt.adminEnabled = false; bt.connectionStatus = 0; bt.present = true
        bt.dhcp = true
        list.append(bt)

        let vpn = AdapterInfo()
        vpn.name = "VPN"; vpn.hardwarePort = "WireGuard Tunnel"
        vpn.adminEnabled = false; vpn.connectionStatus = 0; vpn.present = true
        vpn.dhcp = false
        list.append(vpn)

        return list
    }

    static func configs() -> [SavedConfig] {
        let lab = SavedConfig(); lab.name = "Laboratorio"; lab.address = "192.168.0.250/24"
        let office = SavedConfig(); office.name = "Ufficio"; office.address = "10.10.5.20/24"
        office.gateway = "10.10.5.1"; office.dns1 = "10.10.5.1"; office.dns2 = "1.1.1.1"
        let factory = SavedConfig(); factory.name = "Router di fabbrica"; factory.address = "192.168.1.2/24, 192.168.0.2/24"
        let auto = SavedConfig(); auto.name = "Automatico"; auto.dhcp = true
        return [lab, office, factory, auto]
    }
}
