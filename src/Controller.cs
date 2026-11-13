using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Linq;
using System.Net.NetworkInformation;
using System.Threading.Tasks;
using System.Windows.Threading;
using Microsoft.Win32;
using SD = System.Drawing;
using WF = System.Windows.Forms;

namespace NetSwitch
{
    /// <summary>Controller: icona nell'area di notifica, dati, operazioni sulle interfacce e configurazioni.</summary>
    public class Controller
    {
        readonly WF.NotifyIcon tray;
        readonly WF.ContextMenuStrip menu;
        readonly Flyout flyout;
        readonly DispatcherTimer debounce;
        readonly Dispatcher dispatcher;
        bool startupEnabled;
        bool refreshing, pendingRefresh;

        public List<SavedConfig> Configs { get; private set; }
        public List<AdapterInfo> Adapters { get; private set; }
        public bool Busy { get; private set; }
        public bool StartupEnabled { get { return startupEnabled; } }

        public event EventHandler AdaptersChanged;
        public event EventHandler ConfigsChanged;

        public Controller()
        {
            dispatcher = Dispatcher.CurrentDispatcher;
            Configs = ConfigStore.Load();
            Adapters = new List<AdapterInfo>();
            try { Adapters = NetInfo.GetAdapters(); } catch { }

            flyout = new Flyout(this);

            menu = new WF.ContextMenuStrip();
            menu.ShowItemToolTips = true;
            menu.Items.Add("...");
            menu.Opening += OnMenuOpening;

            tray = new WF.NotifyIcon();
            tray.Icon = AppIcon.App;
            tray.ContextMenuStrip = menu;
            tray.MouseClick += (s, e) => { if (e.Button == WF.MouseButtons.Left) flyout.Toggle(); };
            tray.BalloonTipClicked += (s, e) => flyout.ShowFlyout();
            tray.Visible = true;
            UpdateTrayText();

            debounce = new DispatcherTimer();
            debounce.Interval = TimeSpan.FromMilliseconds(800);
            debounce.Tick += (s, e) => { debounce.Stop(); var t = RefreshAsync(); };
            NetworkChange.NetworkAddressChanged += OnNetworkChanged;
            NetworkChange.NetworkAvailabilityChanged += OnNetworkChanged;
            SystemEvents.UserPreferenceChanged += OnUserPreferenceChanged;

            try { startupEnabled = Startup.IsEnabled(); } catch { }
        }

        // ================================================================== dati

        public async Task RefreshAsync()
        {
            if (refreshing) { pendingRefresh = true; return; }
            refreshing = true;
            try
            {
                do
                {
                    pendingRefresh = false;
                    List<AdapterInfo> list = null;
                    try { list = await Task.Run(() => NetInfo.GetAdapters()); }
                    catch { }
                    if (list != null)
                    {
                        Adapters = list;
                        UpdateTrayText();
                        var h = AdaptersChanged;
                        if (h != null) h(this, EventArgs.Empty);
                    }
                } while (pendingRefresh);
            }
            finally { refreshing = false; }
        }

        void OnNetworkChanged(object sender, EventArgs e)
        {
            dispatcher.BeginInvoke((Action)(() => { debounce.Stop(); debounce.Start(); }));
        }

        void OnUserPreferenceChanged(object sender, UserPreferenceChangedEventArgs e)
        {
            // cambio tema chiaro/scuro o colore d'accento
            dispatcher.BeginInvoke((Action)(() => { try { Theme.Apply(System.Windows.Application.Current); } catch { } }));
        }

        void UpdateTrayText()
        {
            string text = "NetSwitch";
            foreach (var a in Adapters.Where(x => x.IsConnected))
            {
                string line = "\n" + a.Name + ": " + (a.Addresses.Count > 0 ? a.Addresses[0] : "-");
                if ((text + line).Length > 63) break;
                text += line;
            }
            tray.Text = text;
        }

        void SaveConfigs()
        {
            try { ConfigStore.Save(Configs); }
            catch (Exception ex) { flyout.ShowResult(false, "Impossibile salvare le configurazioni:\n" + ex.Message); }
            var h = ConfigsChanged;
            if (h != null) h(this, EventArgs.Empty);
        }

        AdapterInfo Fresh(AdapterInfo a)
        {
            return Adapters.FirstOrDefault(x => string.Equals(x.Guid, a.Guid, StringComparison.OrdinalIgnoreCase)) ?? a;
        }

        // ================================================================== operazioni di rete

        public void UseDhcp(AdapterInfo a)
        {
            RunOp("DHCP su " + a.Name, () => NetOps.ApplyDhcp(a.Name));
        }

        public void ApplyConfig(AdapterInfo a, SavedConfig c)
        {
            var copy = c.Clone();
            RunOp("«" + c.Name + "» su " + a.Name, () => NetOps.Apply(a.Name, copy));
        }

        public void SetEnabled(AdapterInfo a, bool enable)
        {
            if (enable)
            {
                RunOp("Attivazione di " + a.Name, () => NetOps.SetEnabled(a, true));
                return;
            }
            flyout.Confirm("Disattivare " + a.Name + "?",
                a.IsConnected ? "L'interfaccia è connessa: la connettività su di essa verrà interrotta."
                              : "Potrai riattivarla in qualsiasi momento da NetSwitch.",
                "Disattiva", true,
                () => RunOp("Disattivazione di " + a.Name, () => NetOps.SetEnabled(a, false)));
        }

        /// <summary>Chiamato dall'editor "Imposta IP" (già validato).</summary>
        public void SubmitApply(AdapterInfo a, SavedConfig c, bool saveAsConfig)
        {
            if (saveAsConfig)
            {
                Configs.Add(c.Clone());
                SaveConfigs();
            }
            RunOp("Imposta IP su " + a.Name, () => NetOps.Apply(a.Name, c));
        }

        async void RunOp(string title, Func<OpResult> op)
        {
            if (Busy)
            {
                flyout.Warn("Un'altra operazione è in corso, attendere.");
                return;
            }
            Busy = true;
            flyout.ShowBusy(title);
            OpResult r;
            try { r = await Task.Run(op); }
            catch (Exception ex) { r = new OpResult(false, ex.Message); }
            Busy = false;
            await RefreshAsync();

            string text = r.Ok ? (string.IsNullOrEmpty(r.Message) ? title : r.Message) : title + " non riuscita.\n\n" + r.Message;
            flyout.ShowResult(r.Ok, text);
            if (!flyout.IsVisible)
                tray.ShowBalloonTip(5000, r.Ok ? "NetSwitch" : "NetSwitch - errore",
                    Truncate(r.Ok ? text : title + ": " + r.Message, 250), r.Ok ? WF.ToolTipIcon.Info : WF.ToolTipIcon.Error);

            // Windows aggiorna le informazioni IP con un leggero ritardo
            await Task.Delay(2500);
            await RefreshAsync();
        }

        static string Truncate(string s, int max) { return s.Length <= max ? s : s.Substring(0, max - 1) + "…"; }

        public void ToggleStartup()
        {
            var r = startupEnabled ? Startup.Disable() : Startup.Enable();
            if (r.Ok) startupEnabled = !startupEnabled;
            if (flyout.IsVisible) flyout.ShowResult(r.Ok, r.Message);
            else tray.ShowBalloonTip(3000, "NetSwitch", Truncate(r.Message, 250), r.Ok ? WF.ToolTipIcon.Info : WF.ToolTipIcon.Error);
        }

        // ================================================================== configurazioni

        public string ValidateConfigName(string name, SavedConfig editing)
        {
            name = (name ?? "").Trim();
            if (name.Length == 0) return "Inserisci un nome per la configurazione.";
            if (Configs.Any(c => c != editing && string.Equals(c.Name.Trim(), name, StringComparison.CurrentCultureIgnoreCase)))
                return "Esiste già una configurazione chiamata «" + name + "».";
            return null;
        }

        public void SubmitConfig(SavedConfig editing, SavedConfig c)
        {
            int i = editing == null ? -1 : Configs.IndexOf(editing);
            if (i >= 0) Configs[i] = c; else Configs.Add(c);
            SaveConfigs();
            flyout.ShowResult(true, "Configurazione «" + c.Name + "» salvata");
        }

        /// <summary>Nuova configurazione precompilata con i valori attuali di un'interfaccia.</summary>
        public void NewConfigFrom(AdapterInfo from)
        {
            from = Fresh(from);
            var init = new SavedConfig();
            string n = from.Name;
            int k = 2;
            while (ValidateConfigName(n, null) != null) n = from.Name + " " + k++;
            init.Name = n;
            init.Dhcp = from.Dhcp;
            init.Address = from.Addresses.Count == 0 ? "" : from.Dhcp ? from.Addresses[0] : string.Join(", ", from.Addresses);
            init.Gateway = from.Gateways.Count > 0 ? from.Gateways[0] : "";
            if (!from.Dhcp)
            {
                init.Dns1 = from.Dns.Count > 0 ? from.Dns[0] : "";
                init.Dns2 = from.Dns.Count > 1 ? from.Dns[1] : "";
            }
            flyout.OpenConfigEditor(null, init);
        }

        public void DuplicateConfig(SavedConfig c)
        {
            var copy = c.Clone();
            string baseName = c.Name + " (copia)";
            copy.Name = baseName;
            int n = 2;
            while (ValidateConfigName(copy.Name, null) != null) copy.Name = baseName + " " + n++;
            Configs.Insert(Configs.IndexOf(c) + 1, copy);
            SaveConfigs();
        }

        public void DeleteConfig(SavedConfig c)
        {
            flyout.Confirm("Eliminare «" + c.Name + "»?", "La configurazione verrà rimossa definitivamente.", "Elimina", true, () =>
            {
                Configs.Remove(c);
                SaveConfigs();
            });
        }

        public void MoveConfig(SavedConfig c, int delta)
        {
            int i = Configs.IndexOf(c);
            int j = i + delta;
            if (i < 0 || j < 0 || j >= Configs.Count) return;
            Configs.RemoveAt(i);
            Configs.Insert(j, c);
            SaveConfigs();
        }

        // ================================================================== menu tasto destro

        public void ShowFlyout() { flyout.ShowFlyout(); }

        static string Esc(string s) { return (s ?? "").Replace("&", "&&"); }

        void OnMenuOpening(object sender, CancelEventArgs e)
        {
            WF.ToolStripManager.Renderer = new TrayMenuRenderer(Theme.IsDark);
            menu.RenderMode = WF.ToolStripRenderMode.ManagerRenderMode;
            menu.Font = new SD.Font("Segoe UI", 9.5f);
            menu.Items.Clear();

            var open = new WF.ToolStripMenuItem("Apri NetSwitch", null, (s, a) => flyout.ShowFlyout());
            open.Font = new SD.Font(menu.Font, SD.FontStyle.Bold);
            menu.Items.Add(open);
            menu.Items.Add(new WF.ToolStripSeparator());

            foreach (var a in Adapters)
            {
                var ad = a;
                string detail = !a.AdminEnabled ? "disattivata"
                    : !a.IsConnected ? (a.ConnectionStatus == 0 ? "non connessa" : a.StatusText.ToLowerInvariant())
                    : a.Addresses.Count > 0 ? a.Addresses[0] + (a.Dhcp ? "  (DHCP)" : "")
                    : "connessa";
                var item = new WF.ToolStripMenuItem(Esc(a.Name) + "    " + Esc(detail));
                item.Image = AppIcon.DotFor(a);
                bool can = a.AdminEnabled && !Busy;
                var set = new WF.ToolStripMenuItem("Imposta IP...", null, (s, x) => flyout.OpenApplyEditor(Fresh(ad)));
                set.Enabled = can;
                var dhcp = new WF.ToolStripMenuItem("Usa DHCP", null, (s, x) => UseDhcp(ad));
                dhcp.Enabled = can;
                var cfg = new WF.ToolStripMenuItem("Applica configurazione");
                cfg.Enabled = can && Configs.Count > 0;
                foreach (var c in Configs)
                {
                    var cc = c;
                    cfg.DropDownItems.Add(new WF.ToolStripMenuItem(Esc(c.Name) + "    " + Esc(c.Summary), null, (s, x) => ApplyConfig(ad, cc)));
                }
                var toggle = new WF.ToolStripMenuItem(a.AdminEnabled ? "Disattiva" : "Attiva", null, (s, x) => SetEnabled(ad, !ad.AdminEnabled));
                toggle.Enabled = !Busy;
                item.DropDownItems.AddRange(new WF.ToolStripItem[] { set, dhcp, cfg, new WF.ToolStripSeparator(), toggle });
                menu.Items.Add(item);
            }

            menu.Items.Add(new WF.ToolStripSeparator());
            var cfgRoot = new WF.ToolStripMenuItem("Configurazioni salvate");
            if (Configs.Count == 0)
            {
                var none = new WF.ToolStripMenuItem("(nessuna)");
                none.Enabled = false;
                cfgRoot.DropDownItems.Add(none);
            }
            foreach (var c in Configs)
            {
                var cc = c;
                var ci = new WF.ToolStripMenuItem(Esc(c.Name) + "    " + Esc(c.Summary));
                foreach (var a in Adapters.Where(x => x.AdminEnabled))
                {
                    var ad = a;
                    var ai = new WF.ToolStripMenuItem("Applica a " + Esc(a.Name), AppIcon.DotFor(a), (s, x) => ApplyConfig(ad, cc));
                    ai.Enabled = !Busy;
                    ci.DropDownItems.Add(ai);
                }
                cfgRoot.DropDownItems.Add(ci);
            }
            cfgRoot.DropDownItems.Add(new WF.ToolStripSeparator());
            cfgRoot.DropDownItems.Add(new WF.ToolStripMenuItem("Gestisci...", null, (s, x) => flyout.ShowFlyout(1)));
            menu.Items.Add(cfgRoot);

            menu.Items.Add(new WF.ToolStripSeparator());
            var startup = new WF.ToolStripMenuItem("Avvia con Windows", null, (s, x) => ToggleStartup());
            startup.Checked = startupEnabled;
            menu.Items.Add(startup);
            menu.Items.Add(new WF.ToolStripMenuItem("Esci", null, (s, x) => ExitApp()));

            TrayMenuRenderer.Pad(menu.Items);
            e.Cancel = false;
        }

        /// <summary>Solo diagnostica (NETSWITCH_DEBUG=1): porta l'interfaccia in uno stato per gli screenshot.</summary>
        public void Demo(string mode)
        {
            if (string.IsNullOrEmpty(mode) || Adapters.Count == 0) return;
            var a = Adapters.FirstOrDefault(x => x.Addresses.Count > 1) ?? Adapters[0];
            if (mode == "expand") flyout.DemoExpand(a);
            else if (mode == "editor") flyout.OpenApplyEditor(a);
            else if (mode == "configs") flyout.ShowFlyout(1);
            else if (mode == "confirm") SetEnabled(a, false);
            else if (mode == "error") flyout.ShowResult(false, "Imposta IP su Ethernet non riuscita.\n\nL'oggetto esiste già.");
        }

        // ================================================================== uscita

        public void ExitApp()
        {
            NetworkChange.NetworkAddressChanged -= OnNetworkChanged;
            NetworkChange.NetworkAvailabilityChanged -= OnNetworkChanged;
            SystemEvents.UserPreferenceChanged -= OnUserPreferenceChanged;
            tray.Visible = false;
            tray.Dispose();
            flyout.ForceClose();
            System.Windows.Application.Current.Shutdown();
        }
    }
}
