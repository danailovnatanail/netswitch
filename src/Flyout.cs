using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.Linq;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Media.Effects;
using System.Windows.Threading;
using WF = System.Windows.Forms;

namespace NetSwitch
{
    /// <summary>Finestra compatta "a comparsa" ancorata alla barra delle applicazioni, vicino all'orologio.</summary>
    public class Flyout : Window
    {
        const double PanelWidth = 380;
        const double Shadow = 14;   // margine trasparente per l'ombra
        const double Gap = 12;      // distanza dalla barra e dal bordo dello schermo

        [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr hWnd);

        readonly Controller app;
        readonly Grid container;
        readonly Grid layers;
        readonly ContentControl pageHost;
        readonly Grid mainPage;
        readonly StackPanel ifList, cfgList;
        readonly ScrollViewer ifScroll, cfgScroll;
        readonly RadioButton tabIf, tabCfg;
        readonly TextBlock ifSummary;
        readonly ToggleButton onlyConnected;
        readonly Border snack;
        readonly TextBlock snackIcon, snackText;
        readonly Button snackClose;
        readonly RotateTransform snackSpin = new RotateTransform();
        readonly Grid overlay;
        readonly Dictionary<string, AdapterCard> cards = new Dictionary<string, AdapterCard>();
        readonly TextBlock[] groupHeaders = new TextBlock[3];
        readonly HashSet<string> expandedAdapters = new HashSet<string>();
        readonly HashSet<string> expandedConfigs = new HashSet<string>();
        readonly DispatcherTimer snackTimer, autoRefresh;
        DateTime lastHidden = DateTime.MinValue;
        bool exiting, edgeTop;
        IntPtr hwnd;

        public Flyout(Controller app)
        {
            this.app = app;
            WindowStyle = WindowStyle.None;
            AllowsTransparency = true;
            Background = Brushes.Transparent;
            ResizeMode = ResizeMode.NoResize;
            ShowInTaskbar = false;
            Topmost = true;
            Width = PanelWidth + 2 * Shadow;
            Height = 600;
            Title = "NetSwitch";
            FontFamily = new FontFamily("Segoe UI Variable Text, Segoe UI");
            FontSize = 13;
            UseLayoutRounding = true;
            SetResourceReference(ForegroundProperty, "Fg");

            // ombra + pannello arrotondato
            container = new Grid();
            container.Margin = new Thickness(Shadow);
            var shadow = new Border();
            shadow.CornerRadius = new CornerRadius(8);
            shadow.SetResourceReference(Border.BackgroundProperty, "Bg");
            shadow.Effect = new DropShadowEffect { BlurRadius = 18, ShadowDepth = 4, Direction = 270, Opacity = 0.38, Color = Colors.Black };
            var panel = new Border();
            panel.CornerRadius = new CornerRadius(8);
            panel.BorderThickness = new Thickness(1);
            panel.SetResourceReference(Border.BackgroundProperty, "Bg");
            panel.SetResourceReference(Border.BorderBrushProperty, "CardBorder");
            container.Children.Add(shadow);
            container.Children.Add(panel);

            layers = new Grid();
            layers.ClipToBounds = true;
            panel.Child = layers;

            // ---------------------------------------------------------- pagina principale
            mainPage = new Grid();
            mainPage.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            mainPage.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            mainPage.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });

            var header = new DockPanel();
            header.Margin = new Thickness(16, 12, 8, 8);
            Button more = null;
            more = UI.IconButton(UI.Glyph.More, "Altre opzioni", (s, e) => ShowMoreMenu(more));
            var refresh = UI.IconButton(UI.Glyph.Refresh, "Aggiorna", (s, e) => { var t = app.RefreshAsync(); Toast("Aggiornato"); });
            DockPanel.SetDock(more, Dock.Right);
            DockPanel.SetDock(refresh, Dock.Right);
            header.Children.Add(more);
            header.Children.Add(refresh);
            var logo = new Border();
            logo.Width = 26; logo.Height = 26;
            logo.CornerRadius = new CornerRadius(6);
            logo.Margin = new Thickness(0, 0, 10, 0);
            logo.SetResourceReference(Border.BackgroundProperty, "Accent");
            logo.Child = UI.Icon(UI.Glyph.Ethernet, 14, "AccentFg");
            header.Children.Add(logo);
            var title = UI.Text("NetSwitch", 14, "Fg", FontWeights.SemiBold);
            title.VerticalAlignment = VerticalAlignment.Center;
            header.Children.Add(title);
            mainPage.Children.Add(header);

            tabIf = UI.Seg("Interfacce");
            tabCfg = UI.Seg("Configurazioni");
            var seg = UI.Segmented("maintabs", tabIf, tabCfg);
            seg.Margin = new Thickness(16, 0, 16, 10);
            Grid.SetRow(seg, 1);
            mainPage.Children.Add(seg);

            // scheda interfacce
            var ifPanel = new StackPanel();
            ifPanel.Margin = new Thickness(16, 2, 12, 16);
            var ifTop = new DockPanel();
            ifTop.Margin = new Thickness(2, 0, 0, 8);
            onlyConnected = UI.Switch(UI.Text("Solo connesse", 12, "Fg2"));
            onlyConnected.Click += (s, e) => UpdateAdapters();
            DockPanel.SetDock(onlyConnected, Dock.Right);
            ifTop.Children.Add(onlyConnected);
            ifSummary = UI.Text("", 12, "Fg2");
            ifSummary.VerticalAlignment = VerticalAlignment.Center;
            ifTop.Children.Add(ifSummary);
            ifPanel.Children.Add(ifTop);
            ifList = new StackPanel();
            ifPanel.Children.Add(ifList);
            ifScroll = UI.Scroll(ifPanel);

            // scheda configurazioni
            var cfgPanel = new StackPanel();
            cfgPanel.Margin = new Thickness(16, 2, 12, 16);
            var newBtn = UI.IconTextButton("Btn", UI.Glyph.Add, "Nuova configurazione", false, (s, e) => OpenConfigEditor(null, null));
            newBtn.HorizontalAlignment = HorizontalAlignment.Stretch;
            newBtn.Padding = new Thickness(12, 8, 12, 9);
            newBtn.Margin = new Thickness(0, 0, 0, 8);
            cfgPanel.Children.Add(newBtn);
            cfgList = new StackPanel();
            cfgPanel.Children.Add(cfgList);
            cfgScroll = UI.Scroll(cfgPanel);
            cfgScroll.Visibility = Visibility.Collapsed;

            Grid.SetRow(ifScroll, 2);
            Grid.SetRow(cfgScroll, 2);
            mainPage.Children.Add(ifScroll);
            mainPage.Children.Add(cfgScroll);
            tabIf.IsChecked = true;
            tabIf.Checked += (s, e) => { ifScroll.Visibility = Visibility.Visible; cfgScroll.Visibility = Visibility.Collapsed; };
            tabCfg.Checked += (s, e) => { cfgScroll.Visibility = Visibility.Visible; ifScroll.Visibility = Visibility.Collapsed; };

            pageHost = new ContentControl();
            pageHost.Focusable = false;
            pageHost.Content = mainPage;
            layers.Children.Add(pageHost);

            // ---------------------------------------------------------- notifica in basso
            snack = new Border();
            snack.VerticalAlignment = VerticalAlignment.Bottom;
            snack.Margin = new Thickness(12);
            snack.Padding = new Thickness(12, 9, 6, 9);
            snack.CornerRadius = new CornerRadius(6);
            snack.BorderThickness = new Thickness(1);
            snack.SetResourceReference(Border.BackgroundProperty, "MenuBg");
            snack.SetResourceReference(Border.BorderBrushProperty, "CardBorder");
            snack.Effect = new DropShadowEffect { BlurRadius = 12, ShadowDepth = 2, Direction = 270, Opacity = 0.25 };
            snack.Visibility = Visibility.Collapsed;
            var sg = new Grid();
            sg.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            sg.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            sg.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            snackIcon = UI.Icon(UI.Glyph.Check, 14, "Success");
            snackIcon.VerticalAlignment = VerticalAlignment.Top;
            snackIcon.Margin = new Thickness(0, 2, 10, 0);
            snackIcon.RenderTransformOrigin = new Point(0.5, 0.5);
            snackIcon.RenderTransform = snackSpin;
            snackText = UI.Text("", 12.5, "Fg");
            snackText.TextWrapping = TextWrapping.Wrap;
            snackText.TextTrimming = TextTrimming.None;
            var snackScroll = UI.Scroll(snackText);
            snackScroll.MaxHeight = 150;
            snackScroll.VerticalAlignment = VerticalAlignment.Center;
            snackClose = UI.IconButton(UI.Glyph.Close, "Chiudi", (s, e) => HideSnack());
            snackClose.Width = 24; snackClose.Height = 24; snackClose.FontSize = 10;
            snackClose.VerticalAlignment = VerticalAlignment.Top;
            snackClose.Margin = new Thickness(6, -2, 0, 0);
            Grid.SetColumn(snackScroll, 1);
            Grid.SetColumn(snackClose, 2);
            sg.Children.Add(snackIcon);
            sg.Children.Add(snackScroll);
            sg.Children.Add(snackClose);
            snack.Child = sg;
            layers.Children.Add(snack);
            snackTimer = new DispatcherTimer();
            snackTimer.Tick += (s, e) => { snackTimer.Stop(); HideSnack(); };

            // ---------------------------------------------------------- overlay conferme
            overlay = new Grid();
            overlay.Visibility = Visibility.Collapsed;
            layers.Children.Add(overlay);

            Content = container;

            autoRefresh = new DispatcherTimer();
            autoRefresh.Interval = Program.Fake ? TimeSpan.FromDays(1) : TimeSpan.FromSeconds(5);
            autoRefresh.Tick += (s, e) => { if (!app.Busy) { var t = app.RefreshAsync(); } };

            Deactivated += (s, e) => HideFlyout();
            PreviewKeyDown += OnPreviewKey;
            app.AdaptersChanged += (s, e) => UpdateAdapters();
            app.ConfigsChanged += (s, e) => BuildConfigs();

            hwnd = new WindowInteropHelper(this).EnsureHandle();
            UpdateAdapters();
            BuildConfigs();
        }

        // ================================================================== visibilità e posizione

        public void Toggle()
        {
            if (IsVisible) HideFlyout();
            // il clic sull'icona chiude prima il flyout (perdita del focus): non riaprirlo subito
            else if ((DateTime.Now - lastHidden).TotalMilliseconds > 350) ShowFlyout();
        }

        public void ShowFlyout() { ShowFlyout(-1); }

        public void ShowFlyout(int tab)
        {
            if (tab == 0) tabIf.IsChecked = true;
            if (tab == 1) tabCfg.IsChecked = true;
            bool wasVisible = IsVisible;
            Program.Debug("ShowFlyout visible=" + wasVisible);
            PositionNearTray();
            if (!wasVisible)
            {
                Show();
                AnimateIn();
            }
            Activate();
            SetForegroundWindow(hwnd);
            autoRefresh.Start();
            var t = app.RefreshAsync();
        }

        public void HideFlyout()
        {
            if (!IsVisible) return;
            Program.Debug("HideFlyout\n" + Environment.StackTrace);
            if (Program.NoAutoHide) return;
            foreach (var c in FindMenus()) c.IsOpen = false;
            lastHidden = DateTime.Now;
            autoRefresh.Stop();
            Hide();
        }

        IEnumerable<ContextMenu> FindMenus() { return openMenus.ToList(); }
        readonly List<ContextMenu> openMenus = new List<ContextMenu>();

        void PositionNearTray()
        {
            var scr = WF.Screen.FromPoint(WF.Cursor.Position);
            var wa = scr.WorkingArea;
            var b = scr.Bounds;
            Matrix m = Matrix.Identity;
            var src = PresentationSource.FromVisual(this);
            if (src != null && src.CompositionTarget != null) m = src.CompositionTarget.TransformFromDevice;
            Point tl = m.Transform(new Point(wa.Left, wa.Top));
            Point br = m.Transform(new Point(wa.Right, wa.Bottom));

            double panelH = Math.Min(620, (br.Y - tl.Y) - 2 * Gap);
            Height = panelH + 2 * Shadow;

            bool top = wa.Top > b.Top;
            bool left = !top && wa.Left > b.Left;
            edgeTop = top;

            Left = left ? tl.X + Gap - Shadow : br.X - Gap + Shadow - Width;
            Top = top ? tl.Y + Gap - Shadow : br.Y - Gap + Shadow - Height;
        }

        void AnimateIn()
        {
            var tt = new TranslateTransform(0, edgeTop ? -18 : 18);
            container.RenderTransform = tt;
            var ease = new CubicEase { EasingMode = EasingMode.EaseOut };
            tt.BeginAnimation(TranslateTransform.YProperty, new DoubleAnimation(0, TimeSpan.FromMilliseconds(240)) { EasingFunction = ease });
            container.BeginAnimation(OpacityProperty, new DoubleAnimation(0, 1, TimeSpan.FromMilliseconds(160)));
        }

        protected override void OnClosing(CancelEventArgs e)
        {
            if (!exiting) { e.Cancel = true; HideFlyout(); }
            base.OnClosing(e);
        }

        /// <summary>Solo diagnostica: salva il pannello (con ombra e trasparenza) come PNG a doppia risoluzione.</summary>
        public void SnapTo(string path)
        {
            var fe = (FrameworkElement)Content;
            const double scale = 2;
            var rtb = new System.Windows.Media.Imaging.RenderTargetBitmap(
                // il contenitore ha un margine (spazio per l'ombra) che RenderTargetBitmap mantiene
                (int)Math.Ceiling((fe.ActualWidth + fe.Margin.Left + fe.Margin.Right) * scale),
                (int)Math.Ceiling((fe.ActualHeight + fe.Margin.Top + fe.Margin.Bottom) * scale),
                96 * scale, 96 * scale, PixelFormats.Pbgra32);
            rtb.Render(fe);
            var enc = new System.Windows.Media.Imaging.PngBitmapEncoder();
            enc.Frames.Add(System.Windows.Media.Imaging.BitmapFrame.Create(rtb));
            using (var fs = System.IO.File.Create(path)) enc.Save(fs);
        }

        public void ForceClose()
        {
            exiting = true;
            Close();
        }

        void OnPreviewKey(object sender, KeyEventArgs e)
        {
            if (e.Key != Key.Escape) return;
            e.Handled = true;
            if (overlay.Visibility == Visibility.Visible) CloseOverlay();
            else if (pageHost.Content != mainPage) ShowMain(-1);
            else HideFlyout();
        }

        // ================================================================== navigazione

        void Navigate(UIElement page, bool forward)
        {
            pageHost.Content = page;
            var tt = new TranslateTransform(forward ? 24 : -24, 0);
            var fe = (FrameworkElement)page;
            fe.RenderTransform = tt;
            var ease = new CubicEase { EasingMode = EasingMode.EaseOut };
            tt.BeginAnimation(TranslateTransform.XProperty, new DoubleAnimation(0, TimeSpan.FromMilliseconds(200)) { EasingFunction = ease });
            fe.BeginAnimation(OpacityProperty, new DoubleAnimation(0, 1, TimeSpan.FromMilliseconds(150)));
        }

        public void ShowMain(int tab)
        {
            if (tab == 0) tabIf.IsChecked = true;
            if (tab == 1) tabCfg.IsChecked = true;
            if (pageHost.Content != mainPage) Navigate(mainPage, false);
        }

        public void OpenApplyEditor(AdapterInfo a)
        {
            ShowFlyout();
            Navigate(new EditorPage(this, app, EditorPage.Kind.Apply, a, null, null), true);
        }

        public void OpenConfigEditor(SavedConfig editing, SavedConfig init)
        {
            ShowFlyout();
            Navigate(new EditorPage(this, app, EditorPage.Kind.Config, null, editing, init ?? editing), true);
        }

        // ================================================================== interfacce

        static string KeyOf(AdapterInfo a) { return a.Guid.Length > 0 ? a.Guid : a.Name; }

        void UpdateAdapters()
        {
            bool only = onlyConnected.IsChecked == true;
            var list = app.Adapters.Where(a => !only || a.IsConnected).ToList();
            var ordered = new List<UIElement>();
            var seen = new HashSet<string>();
            string[] groupNames = { "Connesse", "Non connesse", "Disattivate" };
            int lastGroup = -1;
            foreach (var a in list)
            {
                // intestazione di gruppo: connesse / non connesse (attive) / disattivate
                int g = a.IsConnected ? 0 : a.AdminEnabled ? 1 : 2;
                if (g != lastGroup)
                {
                    lastGroup = g;
                    int n = list.Count(x => (x.IsConnected ? 0 : x.AdminEnabled ? 1 : 2) == g);
                    if (groupHeaders[g] == null)
                    {
                        groupHeaders[g] = UI.Text("", 11.5, "Fg3", FontWeights.SemiBold);
                        groupHeaders[g].Margin = new Thickness(2, 6, 0, 6);
                    }
                    groupHeaders[g].Text = groupNames[g] + "  ·  " + n;
                    groupHeaders[g].Margin = new Thickness(2, ordered.Count == 0 ? 0 : 8, 0, 6);
                    ordered.Add(groupHeaders[g]);
                }
                string k = KeyOf(a);
                AdapterCard c;
                if (!cards.TryGetValue(k, out c))
                {
                    c = new AdapterCard(this, app);
                    cards[k] = c;
                }
                c.Update(a, expandedAdapters.Contains(k));
                ordered.Add(c);
                seen.Add(k);
            }
            foreach (var k in cards.Keys.Where(x => !seen.Contains(x)).ToList()) cards.Remove(k);

            bool same = ifList.Children.Count == ordered.Count;
            for (int i = 0; same && i < ordered.Count; i++) same = ifList.Children[i] == ordered[i];
            if (!same)
            {
                ifList.Children.Clear();
                foreach (var c in ordered) ifList.Children.Add(c);
                if (ordered.Count == 0)
                {
                    var empty = UI.Text(only ? "Nessuna interfaccia connessa." : "Nessuna interfaccia trovata.", 12.5, "Fg2");
                    empty.Margin = new Thickness(2, 12, 0, 0);
                    ifList.Children.Add(empty);
                }
            }
            int conn = app.Adapters.Count(x => x.IsConnected);
            ifSummary.Text = conn + (conn == 1 ? " connessa" : " connesse") + " su " + app.Adapters.Count;
        }

        public void ToggleAdapterExpanded(AdapterInfo a, AdapterCard card)
        {
            string k = KeyOf(a);
            bool exp = !expandedAdapters.Contains(k);
            if (exp) expandedAdapters.Add(k); else expandedAdapters.Remove(k);
            card.SetExpanded(exp, true);
        }

        public void DemoExpand(AdapterInfo a)
        {
            AdapterCard c;
            if (cards.TryGetValue(KeyOf(a), out c)) ToggleAdapterExpanded(a, c);
        }

        public void ShowApplyConfigMenu(FrameworkElement target, AdapterInfo a)
        {
            var cm = NewMenu();
            if (app.Configs.Count == 0)
            {
                var none = UI.MenuItem("Nessuna configurazione salvata", null);
                none.IsEnabled = false;
                cm.Items.Add(none);
                cm.Items.Add(UI.MenuSeparator());
                cm.Items.Add(UI.MenuItem("Nuova configurazione...", (s, e) => OpenConfigEditor(null, null)));
            }
            foreach (var c in app.Configs)
            {
                var cc = c;
                cm.Items.Add(MenuItem2(c.Name, c.Summary, (s, e) => app.ApplyConfig(a, cc)));
            }
            UI.ShowMenu(cm, target);
        }

        public void ShowApplyToMenu(FrameworkElement target, SavedConfig c)
        {
            var cm = NewMenu();
            var enabled = app.Adapters.Where(x => x.AdminEnabled).ToList();
            if (enabled.Count == 0)
            {
                var none = UI.MenuItem("Nessuna interfaccia attiva", null);
                none.IsEnabled = false;
                cm.Items.Add(none);
            }
            foreach (var a in enabled)
            {
                var ad = a;
                var mi = MenuItem2(a.Name, a.Addresses.Count > 0 ? a.Addresses[0] : a.StatusText, (s, e) => app.ApplyConfig(ad, c));
                var dot = new System.Windows.Shapes.Ellipse { Width = 8, Height = 8 };
                dot.SetResourceReference(System.Windows.Shapes.Shape.FillProperty, a.IsConnected ? "Success" : "Amber");
                mi.Icon = dot;
                cm.Items.Add(mi);
            }
            UI.ShowMenu(cm, target);
        }

        ContextMenu NewMenu()
        {
            var cm = new ContextMenu();
            cm.Opened += (s, e) => openMenus.Add(cm);
            cm.Closed += (s, e) => openMenus.Remove(cm);
            return cm;
        }

        static MenuItem MenuItem2(string title, string subtitle, RoutedEventHandler click)
        {
            var sp = new StackPanel();
            sp.Children.Add(UI.Text(title, 13, "Fg"));
            if (!string.IsNullOrEmpty(subtitle))
            {
                var st = UI.Text(subtitle, 11.5, "Fg2");
                st.MaxWidth = 280;
                sp.Children.Add(st);
            }
            var mi = new MenuItem();
            mi.Header = sp;
            mi.Click += click;
            return mi;
        }

        void ShowMoreMenu(FrameworkElement target)
        {
            var cm = NewMenu();
            var st = UI.MenuItem("Avvia con Windows", (s, e) => app.ToggleStartup());
            st.IsChecked = app.StartupEnabled;
            cm.Items.Add(st);
            cm.Items.Add(UI.MenuItem("Apri cartella configurazioni", (s, e) =>
            {
                try
                {
                    System.IO.Directory.CreateDirectory(ConfigStore.Folder);
                    Process.Start("explorer.exe", "\"" + ConfigStore.Folder + "\"");
                }
                catch { }
            }));
            cm.Items.Add(UI.MenuSeparator());
            cm.Items.Add(UI.MenuItem("Esci da NetSwitch", (s, e) => app.ExitApp()));
            UI.ShowMenu(cm, target);
        }

        // ================================================================== configurazioni

        void BuildConfigs()
        {
            cfgList.Children.Clear();
            if (app.Configs.Count == 0)
            {
                var empty = UI.Text("Nessuna configurazione salvata.\nCreane una qui oppure da una interfaccia con «Salva».", 12.5, "Fg2");
                empty.TextWrapping = TextWrapping.Wrap;
                empty.Margin = new Thickness(2, 8, 0, 0);
                cfgList.Children.Add(empty);
            }
            for (int i = 0; i < app.Configs.Count; i++)
            {
                var c = app.Configs[i];
                cfgList.Children.Add(new ConfigCard(this, app, c, i, app.Configs.Count, expandedConfigs.Contains(c.Name)));
            }
        }

        public void ToggleConfigExpanded(SavedConfig c, ConfigCard card)
        {
            bool exp = !expandedConfigs.Contains(c.Name);
            if (exp) expandedConfigs.Add(c.Name); else expandedConfigs.Remove(c.Name);
            card.SetExpanded(exp, true);
        }

        // ================================================================== conferme

        public void Confirm(string title, string message, string okText, bool danger, Action onOk)
        {
            if (!IsVisible) ShowFlyout();
            overlay.Children.Clear();
            var dim = new Border();
            dim.SetResourceReference(Border.BackgroundProperty, "Overlay");
            dim.MouseLeftButtonUp += (s, e) => CloseOverlay();
            overlay.Children.Add(dim);

            var card = new Border();
            card.VerticalAlignment = VerticalAlignment.Center;
            card.Margin = new Thickness(20);
            card.Padding = new Thickness(20, 18, 20, 18);
            card.CornerRadius = new CornerRadius(8);
            card.BorderThickness = new Thickness(1);
            card.SetResourceReference(Border.BackgroundProperty, "MenuBg");
            card.SetResourceReference(Border.BorderBrushProperty, "CardBorder");
            card.Effect = new DropShadowEffect { BlurRadius = 20, ShadowDepth = 4, Direction = 270, Opacity = 0.35 };
            var sp = new StackPanel();
            var t = UI.Text(title, 15, "Fg", FontWeights.SemiBold);
            t.TextWrapping = TextWrapping.Wrap;
            sp.Children.Add(t);
            var msg = UI.Text(message, 12.5, "Fg2");
            msg.TextWrapping = TextWrapping.Wrap;
            msg.TextTrimming = TextTrimming.None;
            msg.Margin = new Thickness(0, 8, 0, 0);
            sp.Children.Add(msg);
            var btns = new UniformGrid { Rows = 1, Margin = new Thickness(0, 20, 0, 0) };
            var cancel = UI.Button("Btn", "Annulla", (s, e) => CloseOverlay());
            cancel.Margin = new Thickness(0, 0, 4, 0);
            var ok = UI.Button(danger ? "DangerBtn" : "AccentBtn", okText, (s, e) => { CloseOverlay(); onOk(); });
            ok.Margin = new Thickness(4, 0, 0, 0);
            btns.Children.Add(cancel);
            btns.Children.Add(ok);
            sp.Children.Add(btns);
            card.Child = sp;
            overlay.Children.Add(card);
            overlay.Visibility = Visibility.Visible;
            overlay.BeginAnimation(OpacityProperty, new DoubleAnimation(0, 1, TimeSpan.FromMilliseconds(120)));
            ok.Focus();
        }

        void CloseOverlay()
        {
            overlay.Visibility = Visibility.Collapsed;
            overlay.Children.Clear();
        }

        // ================================================================== notifiche

        public void ShowBusy(string text) { SetSnack(UI.Glyph.Sync, "Accent", text + "…", 0, false, true); }

        public void ShowResult(bool ok, string text)
        {
            if (ok) SetSnack(UI.Glyph.Check, "Success", text, 6, true, false);
            else SetSnack(UI.Glyph.Error, "Danger", text, 0, true, false);
        }

        public void Toast(string text) { SetSnack(UI.Glyph.Info, "Accent", text, 2.5, true, false); }

        public void Warn(string text) { SetSnack(UI.Glyph.Warning, "Warning", text, 5, true, false); }

        void SetSnack(string glyph, string colorKey, string text, double autoHide, bool closable, bool spin)
        {
            snackTimer.Stop();
            snackIcon.Text = glyph;
            snackIcon.SetResourceReference(TextBlock.ForegroundProperty, colorKey);
            snackText.Text = text;
            snackClose.Visibility = closable ? Visibility.Visible : Visibility.Collapsed;
            if (spin)
                snackSpin.BeginAnimation(RotateTransform.AngleProperty,
                    new DoubleAnimation(0, 360, TimeSpan.FromSeconds(1)) { RepeatBehavior = RepeatBehavior.Forever });
            else
            {
                snackSpin.BeginAnimation(RotateTransform.AngleProperty, null);
                snackSpin.Angle = 0;
            }
            if (snack.Visibility != Visibility.Visible)
            {
                snack.Visibility = Visibility.Visible;
                var tt = new TranslateTransform(0, 12);
                snack.RenderTransform = tt;
                tt.BeginAnimation(TranslateTransform.YProperty, new DoubleAnimation(0, TimeSpan.FromMilliseconds(180)) { EasingFunction = new CubicEase { EasingMode = EasingMode.EaseOut } });
                snack.BeginAnimation(OpacityProperty, new DoubleAnimation(0, 1, TimeSpan.FromMilliseconds(150)));
            }
            if (autoHide > 0)
            {
                snackTimer.Interval = TimeSpan.FromSeconds(autoHide);
                snackTimer.Start();
            }
        }

        void HideSnack()
        {
            snackTimer.Stop();
            snackSpin.BeginAnimation(RotateTransform.AngleProperty, null);
            snack.Visibility = Visibility.Collapsed;
        }

        public void CopyToClipboard(string value)
        {
            try
            {
                Clipboard.SetText(value);
                Toast("Copiato: " + value);
            }
            catch { }
        }
    }
}
