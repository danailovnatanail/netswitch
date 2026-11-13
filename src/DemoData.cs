using System.Collections.Generic;

namespace NetSwitch
{
    /// <summary>
    /// Dati fittizi usati solo per gli screenshot della documentazione
    /// (NETSWITCH_DEBUG=1 e NETSWITCH_FAKE=1): nessuna informazione reale del PC.
    /// </summary>
    public static class DemoData
    {
        public static List<AdapterInfo> Adapters()
        {
            var list = new List<AdapterInfo>();

            var eth = new AdapterInfo
            {
                Name = "Ethernet", Description = "Intel(R) Ethernet Connection I219-V",
                Guid = "{demo-eth}", Mac = "00-1A-2B-3C-4D-5E", ConnectionStatus = 2, Present = true,
                Dhcp = false, Speed = 1000000000
            };
            eth.Addresses.Add("192.168.10.20/24");
            eth.Addresses.Add("10.0.0.20/24");
            eth.Gateways.Add("192.168.10.1");
            eth.Dns.Add("1.1.1.1");
            eth.Dns.Add("8.8.8.8");
            list.Add(eth);

            var wifi = new AdapterInfo
            {
                Name = "Wi-Fi", Description = "Intel(R) Wi-Fi 6 AX201 160MHz",
                Guid = "{demo-wifi}", Mac = "A4-B1-C2-D3-E4-F5", ConnectionStatus = 2, Present = true,
                Dhcp = true, Speed = 866000000
            };
            wifi.Addresses.Add("192.168.1.34/24");
            wifi.Gateways.Add("192.168.1.1");
            wifi.Dns.Add("192.168.1.1");
            list.Add(wifi);

            var usb = new AdapterInfo
            {
                Name = "Ethernet USB", Description = "Realtek USB GbE Family Controller",
                Guid = "{demo-usb}", Mac = "00-E0-4C-68-01-02", ConnectionStatus = 7, Present = true,
                Dhcp = false
            };
            usb.Addresses.Add("172.16.0.10/16");
            list.Add(usb);

            var bt = new AdapterInfo
            {
                Name = "Connessione di rete Bluetooth", Description = "Bluetooth Device (Personal Area Network)",
                Guid = "{demo-bt}", Mac = "A4-B1-C2-D3-E4-F9", AdminEnabled = false, ConnectionStatus = 0, Present = true,
                Dhcp = true
            };
            list.Add(bt);

            var vpn = new AdapterInfo
            {
                Name = "VPN", Description = "WireGuard Tunnel",
                Guid = "{demo-vpn}", AdminEnabled = false, ConnectionStatus = 0, Present = true,
                Dhcp = false
            };
            list.Add(vpn);
            return list;
        }

        public static List<SavedConfig> Configs()
        {
            return new List<SavedConfig>
            {
                new SavedConfig { Name = "Laboratorio", Address = "192.168.0.250/24" },
                new SavedConfig { Name = "Ufficio", Address = "10.10.5.20/24", Gateway = "10.10.5.1", Dns1 = "10.10.5.1", Dns2 = "1.1.1.1" },
                new SavedConfig { Name = "Router di fabbrica", Address = "192.168.1.2/24, 192.168.0.2/24" },
                new SavedConfig { Name = "Automatico", Dhcp = true },
            };
        }
    }
}
