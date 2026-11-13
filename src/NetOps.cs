using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Management;
using System.Net;
using System.Net.NetworkInformation;
using System.Text;

namespace NetSwitch
{
    public class OpResult
    {
        public bool Ok;
        public string Message;
        public OpResult(bool ok, string message) { Ok = ok; Message = message; }
    }

    /// <summary>Validazione indirizzi e operazioni sulle interfacce (netsh / WMI).</summary>
    public static class NetOps
    {
        // ---------------------------------------------------------------- validazione

        public static bool IsValidIPv4(string s)
        {
            if (string.IsNullOrWhiteSpace(s)) return false;
            var parts = s.Trim().Split('.');
            if (parts.Length != 4) return false;
            foreach (var p in parts)
            {
                int v;
                if (p.Length == 0 || p.Length > 3 || !p.All(char.IsDigit) || !int.TryParse(p, out v) || v > 255) return false;
            }
            return true;
        }

        public static uint ToUInt(string ip)
        {
            var b = IPAddress.Parse(ip.Trim()).GetAddressBytes();
            return ((uint)b[0] << 24) | ((uint)b[1] << 16) | ((uint)b[2] << 8) | b[3];
        }

        public static string FromUInt(uint v)
        {
            return string.Format("{0}.{1}.{2}.{3}", v >> 24, (v >> 16) & 255, (v >> 8) & 255, v & 255);
        }

        public static uint MaskBits(int prefix) { return prefix <= 0 ? 0u : 0xFFFFFFFFu << (32 - prefix); }

        public static string MaskFromPrefix(int prefix) { return FromUInt(MaskBits(prefix)); }

        /// <summary>Restituisce il prefisso di una subnet mask, -1 se non valida (non contigua).</summary>
        public static int PrefixFromMask(string mask)
        {
            if (!IsValidIPv4(mask)) return -1;
            uint m = ToUInt(mask);
            int prefix = 0;
            while (prefix < 32 && (m & (0x80000000u >> prefix)) != 0) prefix++;
            return MaskBits(prefix) == m ? prefix : -1;
        }

        /// <summary>Accetta "IP/prefisso" o "IP/subnetmask".</summary>
        public static bool TryParseCidr(string text, out string ip, out int prefix, out string error)
        {
            ip = null; prefix = 0; error = null;
            text = (text ?? "").Trim();
            if (text.Length == 0) { error = "Inserire l'indirizzo IP nel formato IP/subnet (es. 192.168.1.10/24)."; return false; }
            int slash = text.IndexOf('/');
            if (slash < 0) { error = "Manca la subnet: usare il formato IP/subnet (es. 192.168.1.10/24 o 192.168.1.10/255.255.255.0)."; return false; }
            string ipPart = text.Substring(0, slash).Trim();
            string snPart = text.Substring(slash + 1).Trim();
            if (!IsValidIPv4(ipPart)) { error = "Indirizzo IP non valido: '" + ipPart + "'."; return false; }

            int p;
            if (snPart.Contains('.'))
            {
                p = PrefixFromMask(snPart);
                if (p < 0) { error = "Subnet mask non valida: '" + snPart + "'."; return false; }
            }
            else if (!int.TryParse(snPart, NumberStyles.None, CultureInfo.InvariantCulture, out p) || p < 1 || p > 32)
            {
                error = "Prefisso subnet non valido: '" + snPart + "' (deve essere tra 1 e 32)."; return false;
            }
            if (p < 1) { error = "Subnet mask non valida."; return false; }

            uint addr = ToUInt(ipPart);
            if (addr == 0 || (addr >> 24) == 127 || (addr >> 28) >= 14)
            {
                error = "Indirizzo IP non utilizzabile su un'interfaccia: '" + ipPart + "'."; return false;
            }
            if (p <= 30)
            {
                uint host = addr & ~MaskBits(p);
                if (host == 0) { error = ipPart + " è l'indirizzo di rete della subnet /" + p + "."; return false; }
                if (host == ~MaskBits(p)) { error = ipPart + " è l'indirizzo di broadcast della subnet /" + p + "."; return false; }
            }
            ip = FromUInt(addr);
            prefix = p;
            return true;
        }

        /// <summary>Uno o più indirizzi IP/subnet separati da virgola, punto e virgola o spazio.</summary>
        public static bool TryParseCidrList(string text, out List<KeyValuePair<string, int>> list, out string error)
        {
            list = new List<KeyValuePair<string, int>>();
            error = null;
            // normalizza "1.2.3.4 / 24" -> "1.2.3.4/24" prima di separare sugli spazi
            string norm = System.Text.RegularExpressions.Regex.Replace(text ?? "", @"\s*/\s*", "/");
            var parts = norm.Split(new[] { ',', ';', ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length == 0) { error = "Inserire l'indirizzo IP nel formato IP/subnet (es. 192.168.1.10/24)."; return false; }
            foreach (var p in parts)
            {
                string ip; int prefix;
                if (!TryParseCidr(p, out ip, out prefix, out error)) return false;
                if (list.Any(x => x.Key == ip)) { error = "Indirizzo ripetuto: " + ip + "."; return false; }
                list.Add(new KeyValuePair<string, int>(ip, prefix));
            }
            return true;
        }

        public static string FormatCidrList(List<KeyValuePair<string, int>> list)
        {
            return string.Join(", ", list.Select(x => x.Key + "/" + x.Value));
        }

        public static bool SameSubnet(string a, string b, int prefix)
        {
            uint m = MaskBits(prefix);
            return (ToUInt(a) & m) == (ToUInt(b) & m);
        }

        // ---------------------------------------------------------------- esecuzione comandi

        public static OpResult RunProcess(string file, string args)
        {
            var psi = new ProcessStartInfo(file, args);
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            psi.RedirectStandardOutput = true;
            psi.RedirectStandardError = true;
            Encoding enc;
            try { enc = Encoding.GetEncoding(CultureInfo.CurrentCulture.TextInfo.OEMCodePage); }
            catch { enc = Encoding.Default; }
            psi.StandardOutputEncoding = enc;
            psi.StandardErrorEncoding = enc;

            using (var p = Process.Start(psi))
            {
                var errTask = p.StandardError.ReadToEndAsync();
                string so = p.StandardOutput.ReadToEnd();
                if (!p.WaitForExit(60000))
                {
                    try { p.Kill(); } catch { }
                    return new OpResult(false, "Timeout eseguendo: " + Path.GetFileName(file) + " " + args);
                }
                string se = errTask.Result;
                string msg = (so + "\n" + se).Trim();
                return new OpResult(p.ExitCode == 0, msg);
            }
        }

        static string NetshPath { get { return Path.Combine(Environment.SystemDirectory, "netsh.exe"); } }

        static OpResult Netsh(string args) { return RunProcess(NetshPath, args); }

        static string Q(string name) { return "\"" + name.Replace("\"", "") + "\""; }

        // ---------------------------------------------------------------- operazioni

        public static OpResult Apply(string ifName, SavedConfig c)
        {
            if (c.Dhcp) return ApplyDhcp(ifName);
            string err;
            List<KeyValuePair<string, int>> addrs;
            if (!TryParseCidrList(c.Address, out addrs, out err)) return new OpResult(false, err);
            var dns = new List<string>();
            if (!string.IsNullOrWhiteSpace(c.Dns1)) dns.Add(c.Dns1.Trim());
            if (!string.IsNullOrWhiteSpace(c.Dns2)) dns.Add(c.Dns2.Trim());
            return ApplyStatic(ifName, addrs, (c.Gateway ?? "").Trim(), dns);
        }

        public static OpResult ApplyStatic(string ifName, List<KeyValuePair<string, int>> addrs, string gateway, IList<string> dns)
        {
            string gw = string.IsNullOrEmpty(gateway) ? "gateway=none" : "gateway=" + gateway + " gwmetric=1";
            var r = Netsh("interface ipv4 set address name=" + Q(ifName) + " source=static address=" + addrs[0].Key +
                          " mask=" + MaskFromPrefix(addrs[0].Value) + " " + gw);
            if (!r.Ok)
                return new OpResult(false, "Impossibile impostare l'indirizzo IP su '" + ifName + "'.\n\n" + r.Message);

            var warnings = new StringBuilder();
            for (int i = 1; i < addrs.Count; i++)
            {
                var a = Netsh("interface ipv4 add address name=" + Q(ifName) + " address=" + addrs[i].Key + " mask=" + MaskFromPrefix(addrs[i].Value));
                if (!a.Ok) warnings.AppendLine("Indirizzo " + addrs[i].Key + "/" + addrs[i].Value + ": " + a.Message);
            }
            OpResult d;
            if (dns.Count == 0)
            {
                d = Netsh("interface ipv4 set dnsservers name=" + Q(ifName) + " source=static address=none register=primary validate=no");
                if (!d.Ok) warnings.AppendLine("Rimozione DNS: " + d.Message);
            }
            else
            {
                d = Netsh("interface ipv4 set dnsservers name=" + Q(ifName) + " source=static address=" + dns[0] + " register=primary validate=no");
                if (!d.Ok) warnings.AppendLine("DNS primario: " + d.Message);
                for (int i = 1; i < dns.Count; i++)
                {
                    d = Netsh("interface ipv4 add dnsservers name=" + Q(ifName) + " address=" + dns[i] + " index=" + (i + 1) + " validate=no");
                    if (!d.Ok) warnings.AppendLine("DNS " + (i + 1) + ": " + d.Message);
                }
            }

            var msg = new StringBuilder();
            msg.Append(ifName + ": " + FormatCidrList(addrs));
            if (!string.IsNullOrEmpty(gateway)) msg.Append("  gw " + gateway);
            if (dns.Count > 0) msg.Append("  dns " + string.Join(", ", dns));
            if (warnings.Length > 0)
                return new OpResult(false, "Indirizzo IP principale impostato, ma con alcuni errori:\n\n" + warnings);
            return new OpResult(true, msg.ToString());
        }

        public static OpResult ApplyDhcp(string ifName)
        {
            var r = Netsh("interface ipv4 set address name=" + Q(ifName) + " source=dhcp");
            // netsh restituisce errore se il DHCP è già attivo: in quel caso non è un problema.
            if (!r.Ok && !IsDhcpEnabled(ifName))
                return new OpResult(false, "Impossibile attivare il DHCP su '" + ifName + "'.\n\n" + r.Message);
            var d = Netsh("interface ipv4 set dnsservers name=" + Q(ifName) + " source=dhcp");
            string note = d.Ok ? "" : " (DNS: " + d.Message + ")";
            return new OpResult(true, ifName + ": indirizzo e DNS automatici (DHCP)" + note);
        }

        static bool IsDhcpEnabled(string ifName)
        {
            try
            {
                var ni = NetworkInterface.GetAllNetworkInterfaces().FirstOrDefault(x => string.Equals(x.Name, ifName, StringComparison.OrdinalIgnoreCase));
                return ni != null && ni.GetIPProperties().GetIPv4Properties().IsDhcpEnabled;
            }
            catch { return false; }
        }

        public static OpResult SetEnabled(AdapterInfo a, bool enable)
        {
            var r = Netsh("interface set interface name=" + Q(a.Name) + " admin=" + (enable ? "enabled" : "disabled"));
            if (r.Ok) return new OpResult(true, a.Name + (enable ? " attivata" : " disattivata"));

            // Fallback tramite WMI (alcuni adattatori, es. Wi-Fi, non accettano netsh)
            try
            {
                using (var mo = new ManagementObject("Win32_NetworkAdapter.DeviceID=\"" + a.DeviceId + "\""))
                {
                    object ret = mo.InvokeMethod(enable ? "Enable" : "Disable", null);
                    uint code = Convert.ToUInt32(ret);
                    if (code == 0) return new OpResult(true, a.Name + (enable ? " attivata" : " disattivata"));
                    return new OpResult(false, "Operazione non riuscita su '" + a.Name + "'.\n\nnetsh: " + r.Message + "\nWMI: codice " + code);
                }
            }
            catch (Exception ex)
            {
                return new OpResult(false, "Operazione non riuscita su '" + a.Name + "'.\n\nnetsh: " + r.Message + "\nWMI: " + ex.Message);
            }
        }
    }
}
