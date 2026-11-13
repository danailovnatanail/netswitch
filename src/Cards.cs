using System;
using System.Collections.Generic;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Shapes;

namespace NetSwitch
{
    /// <summary>Scheda di una interfaccia: riepilogo cliccabile, dettagli espandibili e azioni.</summary>
    public class AdapterCard : Border
    {
        readonly Flyout fly;
        readonly Controller app;
        AdapterInfo a;
        string bgKey = "Card";

        readonly Grid header;
        readonly TextBlock glyph, name, sub, badgeText, chevron;
        readonly Border badge;
        readonly Ellipse dot;
        readonly ToggleButton sw;
        readonly StackPanel details;
        readonly Grid info;
        readonly Button btnSet, btnDhcp, btnCfg, btnSave;

        public AdapterCard(Flyout fly, Controller app)
        {
            this.fly = fly;
            this.app = app;
            CornerRadius = new CornerRadius(6);
            BorderThickness = new Thickness(1);
            Margin = new Thickness(0, 0, 0, 6);
            SetResourceReference(BackgroundProperty, "Card");
            SetResourceReference(BorderBrushProperty, "CardBorder");

            var root = new StackPanel();
            Child = root;

            // ---------------------------------------------------- intestazione
            header = new Grid();
            header.Background = Brushes.Transparent;
            header.Cursor = Cursors.Hand;
            header.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            header.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            header.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            header.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            header.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            var iconBox = new Grid { Width = 30, Height = 30, Margin = new Thickness(12, 10, 10, 10) };
            glyph = UI.Icon(UI.Glyph.Ethernet, 18, "Fg");
            dot = new Ellipse { Width = 10, Height = 10, StrokeThickness = 2, HorizontalAlignment = HorizontalAlignment.Right, VerticalAlignment = VerticalAlignment.Bottom };
            dot.SetResourceReference(Shape.StrokeProperty, "Card");
            iconBox.Children.Add(glyph);
            iconBox.Children.Add(dot);
            header.Children.Add(iconBox);

            var texts = new StackPanel { VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 8, 8, 8) };
            name = UI.Text("", 13.5, "Fg", FontWeights.SemiBold);
            sub = UI.Text("", 12, "Fg2");
            sub.Margin = new Thickness(0, 1, 0, 0);
            texts.Children.Add(name);
            texts.Children.Add(sub);
            Grid.SetColumn(texts, 1);
            header.Children.Add(texts);

            badge = new Border { CornerRadius = new CornerRadius(4), Padding = new Thickness(6, 1, 6, 2), VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 0, 10, 0) };
            badge.SetResourceReference(Border.BackgroundProperty, "Subtle");
            badgeText = UI.Text("", 11, "Fg2");
            badge.Child = badgeText;
            Grid.SetColumn(badge, 2);
            header.Children.Add(badge);

            sw = UI.Switch(null);
            sw.VerticalAlignment = VerticalAlignment.Center;
            sw.Margin = new Thickness(0, 0, 4, 0);
            sw.ToolTip = "Attiva / disattiva interfaccia";
            sw.Click += (s, e) =>
            {
                bool want = sw.IsChecked == true;
                sw.IsChecked = a.AdminEnabled; // lo stato reale arriverà con l'aggiornamento
                app.SetEnabled(a, want);
            };
            Grid.SetColumn(sw, 3);
            header.Children.Add(sw);

            chevron = UI.Icon(UI.Glyph.Down, 10, "Fg3");
            chevron.Margin = new Thickness(6, 0, 12, 0);
            Grid.SetColumn(chevron, 4);
            header.Children.Add(chevron);

            header.MouseEnter += (s, e) => SetResourceReference(BackgroundProperty, "CardHover");
            header.MouseLeave += (s, e) => SetResourceReference(BackgroundProperty, bgKey);
            header.MouseLeftButtonUp += (s, e) => fly.ToggleAdapterExpanded(a, this);
            root.Children.Add(header);

            // ---------------------------------------------------- dettagli
            details = new StackPanel { Margin = new Thickness(12, 0, 10, 12), Visibility = Visibility.Collapsed };
            details.Children.Add(UI.Divider(new Thickness(0, 0, 0, 10)));
            info = new Grid();
            info.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(78) });
            info.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            details.Children.Add(info);

            var actions = new WrapPanel { Margin = new Thickness(0, 12, 0, 0) };
            btnSet = UI.Button("AccentBtn", "Imposta IP", (s, e) => fly.OpenApplyEditor(a));
            btnDhcp = UI.Button("Btn", "DHCP", (s, e) => app.UseDhcp(a));
            btnDhcp.ToolTip = "Indirizzo e DNS automatici";
            btnCfg = UI.IconTextButton("Btn", UI.Glyph.Down, "Configurazione", true, null);
            btnCfg.Click += (s, e) => fly.ShowApplyConfigMenu(btnCfg, a);
            btnCfg.ToolTip = "Applica una configurazione salvata";
            btnSave = UI.Button("Btn", UI.Icon(UI.Glyph.Save, 13, null), (s, e) => app.NewConfigFrom(a));
            btnSave.ToolTip = "Salva come configurazione";
            btnSave.Padding = new Thickness(9, 5, 9, 6);
            foreach (var b in new[] { btnSet, btnDhcp, btnCfg, btnSave })
            {
                b.Margin = new Thickness(0, 0, 4, 4);
                if (b != btnSave) b.Padding = new Thickness(10, 5, 10, 6);
                actions.Children.Add(b);
            }
            details.Children.Add(actions);
            root.Children.Add(details);
        }

        public void Update(AdapterInfo info, bool expanded)
        {
            a = info;
            bool off = !a.AdminEnabled;
            glyph.Text = UI.GlyphFor(a);
            glyph.Opacity = off ? 0.45 : 1;
            name.Text = a.Name;
            name.Opacity = off ? 0.6 : 1;

            // connessa = verde pieno, non connessa = ambra, disattivata = cerchio vuoto grigio
            if (off)
            {
                dot.Fill = Brushes.Transparent;
                dot.SetResourceReference(Shape.StrokeProperty, "Fg3");
                dot.StrokeThickness = 1.5;
            }
            else
            {
                dot.SetResourceReference(Shape.FillProperty, a.IsConnected ? "Success" : "Amber");
                dot.SetResourceReference(Shape.StrokeProperty, "Card");
                dot.StrokeThickness = 2;
            }

            // le disattivate hanno uno sfondo "vuoto", le altre la scheda normale
            bgKey = off ? "CardOff" : "Card";
            if (!header.IsMouseOver) SetResourceReference(BackgroundProperty, bgKey);

            sub.Inlines.Clear();
            if (off)
            {
                sub.Text = "Disattivata";
                sub.SetResourceReference(TextBlock.ForegroundProperty, "Fg3");
            }
            else if (a.IsConnected)
            {
                sub.Text = a.Addresses.Count > 0
                    ? a.Addresses[0] + (a.Addresses.Count > 1 ? "   +" + (a.Addresses.Count - 1) : "")
                    : "Connessa · nessun indirizzo IPv4";
                sub.SetResourceReference(TextBlock.ForegroundProperty, "Fg2");
            }
            else
            {
                // non connessa: lo stato in evidenza, l'IP configurato (se c'è) dopo
                sub.Text = "";
                var st = new System.Windows.Documents.Run(a.ConnectionStatus == 0 ? "Non connessa" : a.StatusText);
                st.SetResourceReference(TextElement.ForegroundProperty, "Warning");
                sub.Inlines.Add(st);
                if (a.Addresses.Count > 0)
                {
                    var ip = new System.Windows.Documents.Run("  ·  " + a.Addresses[0] + (a.Addresses.Count > 1 ? " +" + (a.Addresses.Count - 1) : ""));
                    ip.SetResourceReference(TextElement.ForegroundProperty, "Fg2");
                    sub.Inlines.Add(ip);
                }
            }

            bool showBadge = a.AdminEnabled && a.ModeText != "-";
            badge.Visibility = showBadge ? Visibility.Visible : Visibility.Collapsed;
            badgeText.Text = a.ModeText;
            sw.IsChecked = a.AdminEnabled;

            BuildInfo();
            btnSet.IsEnabled = a.AdminEnabled;
            btnDhcp.IsEnabled = a.AdminEnabled;
            btnCfg.IsEnabled = a.AdminEnabled;
            SetExpanded(expanded, false);
        }

        void BuildInfo()
        {
            info.Children.Clear();
            info.RowDefinitions.Clear();
            string speed = a.SpeedText;
            AddInfo("Stato", a.StatusText + (speed.Length > 0 ? "  ·  " + speed : ""), false);
            AddInfo("IP", a.Addresses.Count == 0 ? "-" : string.Join("\n", a.Addresses), true);
            AddInfo("Gateway", a.GatewayText, true);
            AddInfo("DNS", a.Dns.Count == 0 ? "-" : string.Join("\n", a.Dns), true);
            AddInfo("MAC", string.IsNullOrEmpty(a.Mac) ? "-" : a.Mac, true);
            AddInfo("Adattatore", a.Description, false);
        }

        void AddInfo(string label, string value, bool copy)
        {
            int row = info.RowDefinitions.Count;
            info.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            var l = UI.Text(label, 12, "Fg3");
            l.Margin = new Thickness(0, 2, 0, 2);
            Grid.SetRow(l, row);
            info.Children.Add(l);
            var v = UI.Text(string.IsNullOrEmpty(value) ? "-" : value, 12, "Fg");
            v.TextWrapping = TextWrapping.Wrap;
            v.TextTrimming = TextTrimming.None;
            v.Margin = new Thickness(0, 2, 0, 2);
            if (copy && value != "-" && !string.IsNullOrEmpty(value))
            {
                v.Cursor = Cursors.Hand;
                v.ToolTip = "Clic per copiare";
                string val = value.Replace("\n", ", ");
                v.MouseLeftButtonUp += (s, e) => fly.CopyToClipboard(val);
                v.MouseEnter += (s, e) => v.TextDecorations = TextDecorations.Underline;
                v.MouseLeave += (s, e) => v.TextDecorations = null;
            }
            Grid.SetRow(v, row);
            Grid.SetColumn(v, 1);
            info.Children.Add(v);
        }

        public void SetExpanded(bool expanded, bool animate)
        {
            bool was = details.Visibility == Visibility.Visible;
            details.Visibility = expanded ? Visibility.Visible : Visibility.Collapsed;
            chevron.Text = expanded ? UI.Glyph.Up : UI.Glyph.Down;
            if (animate && expanded && !was)
                details.BeginAnimation(OpacityProperty, new DoubleAnimation(0, 1, TimeSpan.FromMilliseconds(160)));
        }
    }

    /// <summary>Scheda di una configurazione salvata.</summary>
    public class ConfigCard : Border
    {
        readonly StackPanel details;
        readonly TextBlock chevron;

        public ConfigCard(Flyout fly, Controller app, SavedConfig c, int index, int count, bool expanded)
        {
            CornerRadius = new CornerRadius(6);
            BorderThickness = new Thickness(1);
            Margin = new Thickness(0, 0, 0, 6);
            SetResourceReference(BackgroundProperty, "Card");
            SetResourceReference(BorderBrushProperty, "CardBorder");

            var root = new StackPanel();
            Child = root;

            var header = new Grid { Background = Brushes.Transparent, Cursor = Cursors.Hand };
            header.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            header.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            header.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            var icon = new Border { Width = 30, Height = 30, CornerRadius = new CornerRadius(6), Margin = new Thickness(12, 10, 10, 10) };
            icon.SetResourceReference(Border.BackgroundProperty, "Subtle");
            icon.Child = UI.Icon(c.Dhcp ? UI.Glyph.Refresh : UI.Glyph.Network, 14, "Accent");
            header.Children.Add(icon);

            var texts = new StackPanel { VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 8, 8, 8) };
            texts.Children.Add(UI.Text(c.Name, 13.5, "Fg", FontWeights.SemiBold));
            var sum = UI.Text(c.Dhcp ? "DHCP (automatico)" : c.Address, 12, "Fg2");
            sum.Margin = new Thickness(0, 1, 0, 0);
            texts.Children.Add(sum);
            Grid.SetColumn(texts, 1);
            header.Children.Add(texts);

            chevron = UI.Icon(UI.Glyph.Down, 10, "Fg3");
            chevron.Margin = new Thickness(6, 0, 14, 0);
            Grid.SetColumn(chevron, 2);
            header.Children.Add(chevron);

            header.MouseEnter += (s, e) => SetResourceReference(BackgroundProperty, "CardHover");
            header.MouseLeave += (s, e) => SetResourceReference(BackgroundProperty, "Card");
            header.MouseLeftButtonUp += (s, e) => fly.ToggleConfigExpanded(c, this);
            root.Children.Add(header);

            details = new StackPanel { Margin = new Thickness(12, 0, 12, 12), Visibility = Visibility.Collapsed };
            details.Children.Add(UI.Divider(new Thickness(0, 0, 0, 10)));
            if (!c.Dhcp)
            {
                var g = new Grid();
                g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(78) });
                g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
                AddRow(g, "IP", c.Address.Replace(", ", "\n"));
                AddRow(g, "Gateway", string.IsNullOrWhiteSpace(c.Gateway) ? "-" : c.Gateway);
                AddRow(g, "DNS", c.DnsText.Length == 0 ? "-" : c.DnsText.Replace(", ", "\n"));
                details.Children.Add(g);
            }
            else
            {
                var t = UI.Text("Indirizzo IP e DNS assegnati automaticamente.", 12, "Fg2");
                t.TextWrapping = TextWrapping.Wrap;
                details.Children.Add(t);
            }

            var actions = new DockPanel { Margin = new Thickness(0, 12, 0, 0), LastChildFill = false };
            Button apply = null;
            apply = UI.IconTextButton("AccentBtn", UI.Glyph.Down, "Applica a", true, (s, e) => fly.ShowApplyToMenu(apply, c));
            apply.Margin = new Thickness(0, 0, 6, 0);
            actions.Children.Add(apply);
            var del = UI.IconButton(UI.Glyph.Delete, "Elimina", (s, e) => app.DeleteConfig(c));
            del.SetResourceReference(Control.ForegroundProperty, "Danger");
            var down = UI.IconButton(UI.Glyph.Down, "Sposta giù", (s, e) => app.MoveConfig(c, 1));
            down.IsEnabled = index < count - 1;
            var up = UI.IconButton(UI.Glyph.Up, "Sposta su", (s, e) => app.MoveConfig(c, -1));
            up.IsEnabled = index > 0;
            var dup = UI.IconButton(UI.Glyph.Copy, "Duplica", (s, e) => app.DuplicateConfig(c));
            var edit = UI.IconButton(UI.Glyph.Edit, "Modifica", (s, e) => fly.OpenConfigEditor(c, c));
            foreach (var b in new[] { del, down, up, dup, edit })
            {
                DockPanel.SetDock(b, Dock.Right);
                actions.Children.Add(b);
            }
            details.Children.Add(actions);
            root.Children.Add(details);
            SetExpanded(expanded, false);
        }

        static void AddRow(Grid g, string label, string value)
        {
            int row = g.RowDefinitions.Count;
            g.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            var l = UI.Text(label, 12, "Fg3");
            l.Margin = new Thickness(0, 2, 0, 2);
            Grid.SetRow(l, row);
            g.Children.Add(l);
            var v = UI.Text(value, 12, "Fg");
            v.TextWrapping = TextWrapping.Wrap;
            v.Margin = new Thickness(0, 2, 0, 2);
            Grid.SetRow(v, row);
            Grid.SetColumn(v, 1);
            g.Children.Add(v);
        }

        public void SetExpanded(bool expanded, bool animate)
        {
            bool was = details.Visibility == Visibility.Visible;
            details.Visibility = expanded ? Visibility.Visible : Visibility.Collapsed;
            chevron.Text = expanded ? UI.Glyph.Up : UI.Glyph.Down;
            if (animate && expanded && !was)
                details.BeginAnimation(OpacityProperty, new DoubleAnimation(0, 1, TimeSpan.FromMilliseconds(160)));
        }
    }
}
