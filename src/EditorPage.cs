using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Threading;

namespace NetSwitch
{
    /// <summary>Pagina interna al flyout per impostare l'IP o creare/modificare una configurazione.</summary>
    public class EditorPage : Grid
    {
        public enum Kind { Apply, Config }

        readonly Flyout fly;
        readonly Controller app;
        readonly Kind kind;
        readonly AdapterInfo adapter;
        readonly SavedConfig editing;
        readonly TextBox txtName, txtIp, txtGw, txtDns1, txtDns2;
        readonly RadioButton rbStatic, rbDhcp;
        readonly ToggleButton swSave;
        readonly StackPanel staticFields;
        readonly TextBlock msg;
        bool gwWarned;

        public EditorPage(Flyout fly, Controller app, Kind kind, AdapterInfo adapter, SavedConfig editing, SavedConfig init)
        {
            this.fly = fly;
            this.app = app;
            this.kind = kind;
            this.adapter = adapter;
            this.editing = editing;

            RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
            RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

            // ---------------------------------------------------- intestazione
            var header = new DockPanel { Margin = new Thickness(8, 10, 16, 6) };
            var back = UI.IconButton(UI.Glyph.Back, "Indietro (Esc)", (s, e) => fly.ShowMain(-1));
            back.Margin = new Thickness(0, 0, 6, 0);
            header.Children.Add(back);
            var titles = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
            string title = kind == Kind.Apply ? "Imposta IP"
                         : editing == null ? "Nuova configurazione" : "Modifica configurazione";
            titles.Children.Add(UI.Text(title, 15, "Fg", FontWeights.SemiBold));
            string subtitle = kind == Kind.Apply ? adapter.Name + "  ·  " + adapter.Description : "Configurazione salvata";
            titles.Children.Add(UI.Text(subtitle, 12, "Fg2"));
            header.Children.Add(titles);
            Children.Add(header);

            // ---------------------------------------------------- campi
            var form = new StackPanel { Margin = new Thickness(16, 4, 12, 12) };

            if (kind == Kind.Apply && app.Configs.Count > 0)
            {
                Button load = null;
                load = UI.IconTextButton("GhostBtn", UI.Glyph.Down, "Carica da configurazione", true, (s, e) => ShowLoadMenu(load));
                load.HorizontalAlignment = HorizontalAlignment.Left;
                load.Margin = new Thickness(-8, 0, 0, 2);
                load.SetResourceReference(Control.ForegroundProperty, "Accent");
                form.Children.Add(load);
            }

            if (kind == Kind.Config)
            {
                txtName = UI.Input("es. Ufficio, Laboratorio, Cliente X");
                form.Children.Add(Field("Nome", txtName));
            }

            rbStatic = UI.Seg("IP statico");
            rbDhcp = UI.Seg("Automatico (DHCP)");
            rbStatic.IsChecked = true;
            form.Children.Add(Field("Modalità", UI.Segmented("mode" + Guid.NewGuid().ToString("N"), rbStatic, rbDhcp)));

            staticFields = new StackPanel();
            txtIp = UI.Input("192.168.1.10/24");
            staticFields.Children.Add(Field("Indirizzo IP / subnet", txtIp));
            var hint = UI.Text("Subnet anche come 255.255.255.0 · più indirizzi separati da virgola", 11.5, "Fg3");
            hint.TextWrapping = TextWrapping.Wrap;
            hint.Margin = new Thickness(2, 4, 0, 0);
            staticFields.Children.Add(hint);
            txtGw = UI.Input("facoltativo");
            staticFields.Children.Add(Field("Gateway", txtGw));
            var dnsGrid = new UniformGrid { Rows = 1 };
            txtDns1 = UI.Input("facoltativo");
            txtDns2 = UI.Input("facoltativo");
            var f1 = Field("DNS primario", txtDns1);
            f1.Margin = new Thickness(0, 0, 4, 0);
            var f2 = Field("DNS secondario", txtDns2);
            f2.Margin = new Thickness(4, 0, 0, 0);
            dnsGrid.Children.Add(f1);
            dnsGrid.Children.Add(f2);
            staticFields.Children.Add(dnsGrid);
            form.Children.Add(staticFields);

            if (kind == Kind.Apply)
            {
                swSave = UI.Switch(UI.Text("Salva anche come configurazione", 12.5, "Fg"));
                swSave.Margin = new Thickness(0, 18, 0, 0);
                swSave.HorizontalAlignment = HorizontalAlignment.Left;
                txtName = UI.Input("Nome della configurazione");
                txtName.Margin = new Thickness(0, 8, 0, 0);
                txtName.Visibility = Visibility.Collapsed;
                swSave.Click += (s, e) =>
                {
                    txtName.Visibility = swSave.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
                    if (swSave.IsChecked == true) txtName.Focus();
                };
                form.Children.Add(swSave);
                form.Children.Add(txtName);
            }

            msg = UI.Text("", 12.5, "Danger");
            msg.TextWrapping = TextWrapping.Wrap;
            msg.TextTrimming = TextTrimming.None;
            msg.Margin = new Thickness(2, 12, 0, 0);
            msg.Visibility = Visibility.Collapsed;
            form.Children.Add(msg);

            var scroll = UI.Scroll(form);
            Grid.SetRow(scroll, 1);
            Children.Add(scroll);

            // ---------------------------------------------------- pulsanti
            var footer = new UniformGrid { Rows = 1, Margin = new Thickness(16, 6, 16, 16) };
            var cancel = UI.Button("Btn", "Annulla", (s, e) => fly.ShowMain(-1));
            cancel.Margin = new Thickness(0, 0, 4, 0);
            cancel.Padding = new Thickness(12, 7, 12, 8);
            var ok = UI.Button("AccentBtn", kind == Kind.Apply ? "Applica" : "Salva", (s, e) => Submit());
            ok.Margin = new Thickness(4, 0, 0, 0);
            ok.Padding = new Thickness(12, 7, 12, 8);
            footer.Children.Add(cancel);
            footer.Children.Add(ok);
            Grid.SetRow(footer, 2);
            Children.Add(footer);

            rbStatic.Checked += (s, e) => UpdateMode();
            rbDhcp.Checked += (s, e) => UpdateMode();
            txtGw.TextChanged += (s, e) => gwWarned = false;
            txtIp.TextChanged += (s, e) => gwWarned = false;
            PreviewKeyDown += (s, e) =>
            {
                if (e.Key == Key.Enter) { e.Handled = true; Submit(); }
            };

            // ---------------------------------------------------- valori iniziali
            if (kind == Kind.Apply) LoadFromAdapter(adapter);
            else if (init != null) LoadConfig(init);
            if (kind == Kind.Config && init != null) txtName.Text = editing != null ? init.Name : init.Name;
            UpdateMode();

            Loaded += (s, e) => Dispatcher.BeginInvoke(DispatcherPriority.Input, (Action)(() =>
            {
                var first = kind == Kind.Config && txtName.Text.Length == 0 ? txtName : txtIp;
                if (first.IsEnabled) { first.Focus(); first.SelectAll(); }
            }));
        }

        static StackPanel Field(string label, UIElement control)
        {
            var sp = new StackPanel();
            var l = UI.Text(label, 12, "Fg2");
            l.Margin = new Thickness(2, 12, 0, 5);
            sp.Children.Add(l);
            sp.Children.Add(control);
            return sp;
        }

        void UpdateMode()
        {
            bool st = rbStatic.IsChecked == true;
            staticFields.IsEnabled = st;
            staticFields.Opacity = st ? 1 : 0.5;
            HideMsg();
        }

        void LoadFromAdapter(AdapterInfo a)
        {
            rbDhcp.IsChecked = a.Dhcp;
            rbStatic.IsChecked = !a.Dhcp;
            txtIp.Text = a.Addresses.Count == 0 ? "" : a.Dhcp ? a.Addresses[0] : string.Join(", ", a.Addresses);
            txtGw.Text = a.Gateways.Count > 0 ? a.Gateways[0] : "";
            txtDns1.Text = !a.Dhcp && a.Dns.Count > 0 ? a.Dns[0] : "";
            txtDns2.Text = !a.Dhcp && a.Dns.Count > 1 ? a.Dns[1] : "";
        }

        void LoadConfig(SavedConfig c)
        {
            rbDhcp.IsChecked = c.Dhcp;
            rbStatic.IsChecked = !c.Dhcp;
            txtIp.Text = c.Address ?? "";
            txtGw.Text = c.Gateway ?? "";
            txtDns1.Text = c.Dns1 ?? "";
            txtDns2.Text = c.Dns2 ?? "";
            HideMsg();
        }

        void ShowLoadMenu(FrameworkElement target)
        {
            var cm = new ContextMenu();
            cm.Items.Add(UI.MenuItem("Valori attuali dell'interfaccia", (s, e) => LoadFromAdapter(adapter)));
            cm.Items.Add(UI.MenuSeparator());
            foreach (var c in app.Configs)
            {
                var cc = c;
                cm.Items.Add(UI.MenuItem(c.Name + "   —   " + c.Summary, (s, e) => LoadConfig(cc)));
            }
            UI.ShowMenu(cm, target);
        }

        void ShowMsg(string text, bool warning)
        {
            msg.Text = text;
            msg.SetResourceReference(TextBlock.ForegroundProperty, warning ? "Warning" : "Danger");
            msg.Visibility = Visibility.Visible;
        }

        void HideMsg() { msg.Visibility = Visibility.Collapsed; }

        void Submit()
        {
            var c = new SavedConfig();
            c.Dhcp = rbDhcp.IsChecked == true;
            bool save = kind == Kind.Config || (swSave != null && swSave.IsChecked == true);
            c.Name = txtName == null ? "" : txtName.Text.Trim();
            if (save)
            {
                string nErr = app.ValidateConfigName(c.Name, editing);
                if (nErr != null) { ShowMsg(nErr, false); txtName.Focus(); return; }
            }

            if (!c.Dhcp)
            {
                string err;
                List<KeyValuePair<string, int>> addrs;
                if (!NetOps.TryParseCidrList(txtIp.Text, out addrs, out err)) { ShowMsg(err, false); txtIp.Focus(); return; }
                c.Address = NetOps.FormatCidrList(addrs);

                string gw = txtGw.Text.Trim();
                if (gw.Length > 0)
                {
                    if (!NetOps.IsValidIPv4(gw)) { ShowMsg("Gateway non valido: '" + gw + "'.", false); txtGw.Focus(); return; }
                    gw = NetOps.FromUInt(NetOps.ToUInt(gw));
                    if (addrs.Any(x => x.Key == gw)) { ShowMsg("Il gateway non può coincidere con un indirizzo dell'interfaccia.", false); txtGw.Focus(); return; }
                    if (!addrs.Any(x => NetOps.SameSubnet(x.Key, gw, x.Value)) && !gwWarned)
                    {
                        gwWarned = true;
                        ShowMsg("Il gateway " + gw + " non appartiene a nessuna delle subnet indicate. Premi di nuovo «" +
                                (kind == Kind.Apply ? "Applica" : "Salva") + "» per confermare.", true);
                        return;
                    }
                }
                c.Gateway = gw;

                var dns = new List<string>();
                foreach (var tb in new[] { txtDns1, txtDns2 })
                {
                    string d = tb.Text.Trim();
                    if (d.Length == 0) continue;
                    if (!NetOps.IsValidIPv4(d)) { ShowMsg("Server DNS non valido: '" + d + "'.", false); tb.Focus(); return; }
                    dns.Add(NetOps.FromUInt(NetOps.ToUInt(d)));
                }
                c.Dns1 = dns.Count > 0 ? dns[0] : "";
                c.Dns2 = dns.Count > 1 ? dns[1] : "";
            }

            if (kind == Kind.Apply)
            {
                app.SubmitApply(adapter, c, save);
                fly.ShowMain(0);
            }
            else
            {
                app.SubmitConfig(editing, c);
                fly.ShowMain(1);
            }
        }
    }
}
