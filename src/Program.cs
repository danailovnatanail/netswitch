using System;
using System.IO;
using System.Text;
using System.Threading;

namespace NetSwitch
{
    static class Program
    {
        [STAThread]
        static void Main(string[] args)
        {
            // Modalità diagnostica: NetSwitch.exe --dump <file>
            if (args.Length >= 2 && args[0] == "--dump")
            {
                Dump(args[1]);
                return;
            }

            bool background = Array.IndexOf(args, "--background") >= 0;
            bool created;
            // in debug l'istanza di prova è separata da quella normale
            string inst = DebugOn ? "_debug" : "";
            using (var mutex = new Mutex(true, "Local\\NetSwitch_SingleInstance_8F2A61" + inst, out created))
            using (var showSignal = new EventWaitHandle(false, EventResetMode.AutoReset, "Local\\NetSwitch_Show_8F2A61" + inst))
            {
                if (!created)
                {
                    // già in esecuzione: chiede all'istanza esistente di mostrare il pannello
                    showSignal.Set();
                    return;
                }
                System.Windows.Forms.Application.EnableVisualStyles();
                var app = new System.Windows.Application();
                app.ShutdownMode = System.Windows.ShutdownMode.OnExplicitShutdown;
                app.DispatcherUnhandledException += (s, e) => { LogError(e.Exception); e.Handled = true; };
                Theme.Apply(app);
                var controller = new Controller();

                var listener = new Thread(() =>
                {
                    while (showSignal.WaitOne())
                        app.Dispatcher.BeginInvoke((Action)(() => controller.ShowFlyout()));
                });
                listener.IsBackground = true;
                listener.Start();

                if (!background)
                    app.Dispatcher.BeginInvoke(System.Windows.Threading.DispatcherPriority.ApplicationIdle, (Action)(() =>
                    {
                        controller.ShowFlyout();
                        if (DebugOn) controller.Demo(Environment.GetEnvironmentVariable("NETSWITCH_DEMO"));
                        // NETSWITCH_SNAP=file.png: salva un'immagine del pannello ed esce
                        string snap = DebugOn ? Environment.GetEnvironmentVariable("NETSWITCH_SNAP") : null;
                        if (!string.IsNullOrEmpty(snap))
                        {
                            var t = new System.Windows.Threading.DispatcherTimer { Interval = TimeSpan.FromMilliseconds(1800) };
                            t.Tick += (s, e) => { t.Stop(); controller.Snap(snap); controller.ExitApp(); };
                            t.Start();
                        }
                    }));
                app.Run();
                GC.KeepAlive(mutex);
            }
        }

        /// <summary>Solo per diagnostica: impostare la variabile d'ambiente NETSWITCH_DEBUG=1.</summary>
        public static readonly bool DebugOn = Environment.GetEnvironmentVariable("NETSWITCH_DEBUG") == "1";
        public static readonly bool NoAutoHide = Environment.GetEnvironmentVariable("NETSWITCH_NOHIDE") == "1";
        /// <summary>Interfacce e configurazioni fittizie (screenshot della documentazione).</summary>
        public static readonly bool Fake = DebugOn && Environment.GetEnvironmentVariable("NETSWITCH_FAKE") == "1";

        public static void Debug(string s)
        {
            if (!DebugOn) return;
            try { File.AppendAllText(Path.Combine(Path.GetTempPath(), "netswitch_debug.log"), DateTime.Now.ToString("HH:mm:ss.fff") + " " + s + Environment.NewLine); }
            catch { }
        }

        static void LogError(Exception ex)
        {
            try
            {
                Directory.CreateDirectory(ConfigStore.Folder);
                File.AppendAllText(Path.Combine(ConfigStore.Folder, "errori.log"), DateTime.Now + "  " + ex + Environment.NewLine + Environment.NewLine);
            }
            catch { }
        }

        static void Dump(string path)
        {
            var sb = new StringBuilder();
            try
            {
                foreach (var a in NetInfo.GetAdapters())
                {
                    sb.AppendLine("== " + a.Name);
                    sb.AppendLine("   Stato:   " + a.StatusText + " (admin " + (a.AdminEnabled ? "on" : "off") + ", present " + a.Present + ")");
                    sb.AppendLine("   Modo:    " + a.ModeText);
                    sb.AppendLine("   IP:      " + a.AddressText);
                    sb.AppendLine("   GW:      " + a.GatewayText);
                    sb.AppendLine("   DNS:     " + a.DnsText);
                    sb.AppendLine("   MAC:     " + a.Mac);
                    sb.AppendLine("   Vel.:    " + a.SpeedText);
                    sb.AppendLine("   Descr.:  " + a.Description);
                }
            }
            catch (Exception ex) { sb.AppendLine("ERRORE: " + ex); }

            sb.AppendLine();
            sb.AppendLine("== Test parsing IP/subnet");
            foreach (var t in new[] { "192.168.1.10/24", "10.0.0.5/255.255.0.0", "10.0.0.5/255.0.255.0", "192.168.1.10", "300.1.1.1/24", "1.2.3/24", "172.16.5.4/33", " 192.168.100.1 / 30 " })
            {
                string ip, err; int p;
                bool ok = NetOps.TryParseCidr(t, out ip, out p, out err);
                sb.AppendLine("   '" + t + "' -> " + (ok ? ip + "/" + p + " mask " + NetOps.MaskFromPrefix(p) : "ERR: " + err));
            }
            foreach (var t in new[] { "10.1.2.3/23, 192.168.20.5/24;192.168.30.5 / 24", "10.0.0.1/24, 10.0.0.1/24", "10.0.0.1/24, x" })
            {
                System.Collections.Generic.List<System.Collections.Generic.KeyValuePair<string, int>> l; string err;
                bool ok = NetOps.TryParseCidrList(t, out l, out err);
                sb.AppendLine("   LIST '" + t + "' -> " + (ok ? NetOps.FormatCidrList(l) : "ERR: " + err));
            }
            sb.AppendLine("   SameSubnet(192.168.1.10, 192.168.1.1, 24) = " + NetOps.SameSubnet("192.168.1.10", "192.168.1.1", 24));
            sb.AppendLine("   SameSubnet(192.168.1.10, 192.168.2.1, 24) = " + NetOps.SameSubnet("192.168.1.10", "192.168.2.1", 24));
            File.WriteAllText(path, sb.ToString(), Encoding.UTF8);
        }
    }
}
