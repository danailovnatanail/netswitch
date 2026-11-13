using System;
using System.Collections.Generic;
using System.IO;
using System.Xml.Serialization;

namespace NetSwitch
{
    /// <summary>Configurazione IP salvata, applicabile a qualsiasi interfaccia.</summary>
    public class SavedConfig
    {
        public string Name = "";
        public bool Dhcp;
        public string Address = "";   // formato IP/prefisso
        public string Gateway = "";
        public string Dns1 = "";
        public string Dns2 = "";

        [XmlIgnore]
        public string DnsText
        {
            get
            {
                var l = new List<string>();
                if (!string.IsNullOrWhiteSpace(Dns1)) l.Add(Dns1);
                if (!string.IsNullOrWhiteSpace(Dns2)) l.Add(Dns2);
                return l.Count == 0 ? "" : string.Join(", ", l);
            }
        }

        [XmlIgnore]
        public string Summary
        {
            get
            {
                if (Dhcp) return "DHCP (automatico)";
                string s = Address;
                if (!string.IsNullOrWhiteSpace(Gateway)) s += "  gw " + Gateway;
                if (DnsText.Length > 0) s += "  dns " + DnsText;
                return s;
            }
        }

        public SavedConfig Clone() { return (SavedConfig)MemberwiseClone(); }

        public override string ToString() { return Name; }
    }

    public static class ConfigStore
    {
        public static string Folder
        {
            get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "NetSwitch"); }
        }

        public static string FilePath { get { return Path.Combine(Folder, "configurazioni.xml"); } }

        public static List<SavedConfig> Load()
        {
            if (Program.Fake) return DemoData.Configs();
            try
            {
                if (!File.Exists(FilePath)) return new List<SavedConfig>();
                var ser = new XmlSerializer(typeof(List<SavedConfig>));
                using (var fs = File.OpenRead(FilePath))
                    return (List<SavedConfig>)ser.Deserialize(fs) ?? new List<SavedConfig>();
            }
            catch
            {
                // file corrotto: lo conserva come backup e riparte vuoto
                try { File.Copy(FilePath, FilePath + ".bak", true); } catch { }
                return new List<SavedConfig>();
            }
        }

        public static void Save(List<SavedConfig> list)
        {
            if (Program.Fake) return; // i dati fittizi non vanno mai salvati
            Directory.CreateDirectory(Folder);
            var ser = new XmlSerializer(typeof(List<SavedConfig>));
            string tmp = FilePath + ".tmp";
            using (var fs = File.Create(tmp)) ser.Serialize(fs, list);
            if (File.Exists(FilePath)) File.Replace(tmp, FilePath, null);
            else File.Move(tmp, FilePath);
        }
    }
}
