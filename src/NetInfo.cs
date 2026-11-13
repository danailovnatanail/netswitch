using System;
using System.Collections.Generic;
using System.Linq;
using System.Management;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using Microsoft.Win32;

namespace NetSwitch
{
    /// <summary>Informazioni su una connessione di rete (adattatore con nome di connessione).</summary>
    public class AdapterInfo
    {
        public string Name = "";
        public string Description = "";
        public string Guid = "";
        public string DeviceId = "";
        public string Mac = "";
        public bool AdminEnabled = true;
        public int ConnectionStatus = -1;
        public bool Present;
        public bool Dhcp;
        public long Speed;
        public List<string> Addresses = new List<string>();
        public List<string> Gateways = new List<string>();
        public List<string> Dns = new List<string>();

        public bool IsConnected { get { return AdminEnabled && ConnectionStatus == 2; } }

        public string StatusText
        {
            get
            {
                if (!AdminEnabled) return "Disattivata";
                switch (ConnectionStatus)
                {
                    case 0: return "Disconnessa";
                    case 1: return "Connessione...";
                    case 2: return "Connessa";
                    case 3: return "Disconnessione...";
                    case 4: return "Hardware assente";
                    case 5: return "Hardware disattivato";
                    case 6: return "Malfunzionamento";
                    case 7: return "Cavo scollegato";
                    case 8: return "Autenticazione...";
                    case 9: return "Autenticata";
                    case 10: return "Autenticazione fallita";
                    case 11: return "Indirizzo non valido";
                    case 12: return "Credenziali richieste";
                    default: return "Sconosciuto";
                }
            }
        }

        public string ModeText
        {
            get
            {
                if (!Present && Addresses.Count == 0 && !Dhcp) return "-";
                return Dhcp ? "DHCP" : "Statico";
            }
        }

        public string AddressText { get { return Join(Addresses); } }
        public string GatewayText { get { return Join(Gateways); } }
        public string DnsText { get { return Join(Dns); } }

        public string SpeedText
        {
            get
            {
                if (!IsConnected || Speed <= 0) return "";
                if (Speed >= 1000000000L) return (Speed / 1000000000.0).ToString("0.#") + " Gbps";
                return (Speed / 1000000.0).ToString("0.#") + " Mbps";
            }
        }

        static string Join(List<string> l) { return l.Count == 0 ? "-" : string.Join(", ", l); }
    }

    public static class NetInfo
    {
        public static List<AdapterInfo> GetAdapters()
        {
            if (Program.Fake) return DemoData.Adapters();
            var nics = new Dictionary<string, NetworkInterface>(StringComparer.OrdinalIgnoreCase);
            try
            {
                foreach (var ni in NetworkInterface.GetAllNetworkInterfaces()) nics[ni.Id] = ni;
            }
            catch { }

            var list = new List<AdapterInfo>();
            const string q = "SELECT DeviceID, NetConnectionID, Name, GUID, MACAddress, NetEnabled, NetConnectionStatus, ConfigManagerErrorCode " +
                             "FROM Win32_NetworkAdapter WHERE NetConnectionID IS NOT NULL";
            using (var searcher = new ManagementObjectSearcher(q))
            using (var results = searcher.Get())
            {
                foreach (ManagementObject mo in results)
                {
                    using (mo)
                    {
                        var a = new AdapterInfo();
                        a.Name = Str(mo["NetConnectionID"]);
                        a.Description = Str(mo["Name"]);
                        a.Guid = Str(mo["GUID"]);
                        a.DeviceId = Str(mo["DeviceID"]);
                        a.Mac = Str(mo["MACAddress"]).Replace(':', '-');
                        object en = mo["NetEnabled"];
                        object cme = mo["ConfigManagerErrorCode"];
                        if (en != null) a.AdminEnabled = (bool)en;
                        else a.AdminEnabled = !(cme != null && Convert.ToInt32(cme) == 22);
                        object st = mo["NetConnectionStatus"];
                        a.ConnectionStatus = st == null ? -1 : Convert.ToInt32(st);

                        NetworkInterface ni;
                        // per le interfacce disattivate Windows riporta indirizzi obsoleti: si usa la config del registro
                        if (a.AdminEnabled && a.Guid.Length > 0 && nics.TryGetValue(a.Guid, out ni)) FillFromInterface(a, ni);
                        if (a.Guid.Length > 0 && (!a.Present || (!a.Dhcp && a.Addresses.Count == 0))) FillFromRegistry(a);
                        list.Add(a);
                    }
                }
            }

            if (Program.DebugOn && Environment.GetEnvironmentVariable("NETSWITCH_DEMO") == "states")
            {
                // simula interfacce attive ma non collegate, per verificare la grafica
                var off = list.Where(x => !x.AdminEnabled).Take(2).ToList();
                if (off.Count > 0) { off[0].AdminEnabled = true; off[0].ConnectionStatus = 7; if (off[0].Addresses.Count == 0) off[0].Addresses.Add("192.168.50.10/24"); }
                if (off.Count > 1) { off[1].AdminEnabled = true; off[1].ConnectionStatus = 0; off[1].Dhcp = true; }
            }

            return list
                .OrderBy(x => x.IsConnected ? 0 : x.AdminEnabled ? 1 : 2)
                .ThenBy(x => x.Name, StringComparer.CurrentCultureIgnoreCase)
                .ToList();
        }

        static void FillFromInterface(AdapterInfo a, NetworkInterface ni)
        {
            a.Present = true;
            try { if (ni.Speed > 0) a.Speed = ni.Speed; } catch { }
            IPInterfaceProperties p;
            try { p = ni.GetIPProperties(); } catch { return; }
            try
            {
                var v4 = p.GetIPv4Properties();
                if (v4 != null) a.Dhcp = v4.IsDhcpEnabled;
            }
            catch { }

            foreach (UnicastIPAddressInformation u in p.UnicastAddresses)
            {
                if (u.Address.AddressFamily != AddressFamily.InterNetwork) continue;
                a.Addresses.Add(u.Address + "/" + PrefixOf(u));
            }
            foreach (GatewayIPAddressInformation g in p.GatewayAddresses)
            {
                if (g.Address.AddressFamily != AddressFamily.InterNetwork) continue;
                string s = g.Address.ToString();
                if (s != "0.0.0.0" && !a.Gateways.Contains(s)) a.Gateways.Add(s);
            }
            foreach (IPAddress d in p.DnsAddresses)
            {
                if (d.AddressFamily != AddressFamily.InterNetwork) continue;
                string s = d.ToString();
                if (!a.Dns.Contains(s)) a.Dns.Add(s);
            }
        }

        static int PrefixOf(UnicastIPAddressInformation u)
        {
            try { return u.PrefixLength; }
            catch
            {
                try { return NetOps.PrefixFromMask(u.IPv4Mask.ToString()); } catch { return 0; }
            }
        }

        /// <summary>Legge la configurazione IPv4 salvata nel registro (utile per interfacce disattivate o scollegate).</summary>
        static void FillFromRegistry(AdapterInfo a)
        {
            try
            {
                using (var k = Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\" + a.Guid))
                {
                    if (k == null) return;
                    object dhcp = k.GetValue("EnableDHCP");
                    bool isDhcp = dhcp != null && Convert.ToInt32(dhcp) == 1;
                    if (!a.Present) a.Dhcp = isDhcp;
                    if (isDhcp) return;

                    var ips = k.GetValue("IPAddress") as string[];
                    var masks = k.GetValue("SubnetMask") as string[];
                    if (ips != null && a.Addresses.Count == 0)
                    {
                        for (int i = 0; i < ips.Length; i++)
                        {
                            if (string.IsNullOrEmpty(ips[i]) || ips[i] == "0.0.0.0") continue;
                            int pfx = (masks != null && i < masks.Length) ? NetOps.PrefixFromMask(masks[i]) : -1;
                            a.Addresses.Add(ips[i] + (pfx >= 0 ? "/" + pfx : ""));
                        }
                    }
                    var gws = k.GetValue("DefaultGateway") as string[];
                    if (gws != null && a.Gateways.Count == 0)
                        foreach (var g in gws) if (!string.IsNullOrEmpty(g) && g != "0.0.0.0") a.Gateways.Add(g);
                    var ns = k.GetValue("NameServer") as string;
                    if (!string.IsNullOrEmpty(ns) && a.Dns.Count == 0)
                        foreach (var d in ns.Split(new[] { ',', ' ' }, StringSplitOptions.RemoveEmptyEntries)) a.Dns.Add(d);
                }
            }
            catch { }
        }

        static string Str(object o) { return o == null ? "" : o.ToString(); }
    }
}
