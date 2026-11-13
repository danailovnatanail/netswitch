using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Media;
using System.Windows.Shapes;

namespace NetSwitch
{
    /// <summary>Piccole factory per costruire l'interfaccia da codice con gli stili del tema.</summary>
    public static class UI
    {
        public static class Glyph
        {
            public const string Network = "";
            public const string Ethernet = "";
            public const string Wifi = "";
            public const string Bluetooth = "";
            public const string Vpn = "";
            public const string Refresh = "";
            public const string More = "";
            public const string Back = "";
            public const string Add = "";
            public const string Edit = "";
            public const string Delete = "";
            public const string Copy = "";
            public const string Save = "";
            public const string Down = "";
            public const string Up = "";
            public const string Check = "";
            public const string Close = "";
            public const string Warning = "";
            public const string Error = "";
            public const string Info = "";
            public const string Sync = "";
        }

        public static T Res<T>(T el, DependencyProperty p, string key) where T : FrameworkElement
        {
            el.SetResourceReference(p, key);
            return el;
        }

        public static TextBlock Text(string text, double size, string fgKey, FontWeight weight)
        {
            var t = new TextBlock();
            t.Text = text;
            t.FontSize = size;
            t.FontWeight = weight;
            t.SetResourceReference(TextBlock.ForegroundProperty, fgKey);
            t.TextTrimming = TextTrimming.CharacterEllipsis;
            return t;
        }

        public static TextBlock Text(string text, double size, string fgKey)
        {
            return Text(text, size, fgKey, FontWeights.Normal);
        }

        /// <summary>Logo dell'app (stesso disegno di AppIcon): tre nodi collegati su fondo sfumato.</summary>
        public static FrameworkElement Logo(double size)
        {
            var c = new Canvas { Width = 32, Height = 32 };
            var bg = new Rectangle { Width = 30, Height = 30, RadiusX = 9, RadiusY = 9 };
            bg.Fill = new LinearGradientBrush(Color.FromRgb(0x2D, 0xD4, 0xBF), Color.FromRgb(0x02, 0x84, 0xC7), new Point(0, 0), new Point(1, 1));
            Canvas.SetLeft(bg, 1); Canvas.SetTop(bg, 1);
            c.Children.Add(bg);
            var links = new Path
            {
                Data = Geometry.Parse("M16,10.5 C16,16 9.5,15.5 9.5,21.5 M16,10.5 C16,16 22.5,15.5 22.5,21.5"),
                Stroke = Brushes.White, StrokeThickness = 2.6, StrokeStartLineCap = PenLineCap.Round, StrokeEndLineCap = PenLineCap.Round
            };
            c.Children.Add(links);
            Action<double, double, double, Brush> dot = (x, y, r, b) =>
            {
                var e = new Ellipse { Width = r * 2, Height = r * 2, Fill = b };
                Canvas.SetLeft(e, x - r); Canvas.SetTop(e, y - r);
                c.Children.Add(e);
            };
            dot(16, 10, 4.2, Brushes.White);
            dot(16, 10, 1.7, new SolidColorBrush(Color.FromRgb(0x0E, 0xA5, 0xE9)));
            dot(9.5, 22, 3.3, Brushes.White);
            dot(22.5, 22, 3.3, Brushes.White);
            return new Viewbox { Width = size, Height = size, Child = c };
        }

        public static TextBlock Icon(string glyph, double size, string fgKey)
        {
            var t = new TextBlock();
            t.Text = glyph;
            t.FontSize = size;
            t.SetResourceReference(TextBlock.FontFamilyProperty, "IconFont");
            if (fgKey != null) t.SetResourceReference(TextBlock.ForegroundProperty, fgKey);
            t.VerticalAlignment = VerticalAlignment.Center;
            t.HorizontalAlignment = HorizontalAlignment.Center;
            return t;
        }

        public static Button Button(string styleKey, object content, RoutedEventHandler click)
        {
            var b = new Button();
            b.SetResourceReference(FrameworkElement.StyleProperty, styleKey);
            b.Content = content;
            if (click != null) b.Click += click;
            return b;
        }

        public static Button IconButton(string glyph, string tooltip, RoutedEventHandler click)
        {
            var b = Button("IconBtn", glyph, click);
            b.ToolTip = tooltip;
            return b;
        }

        /// <summary>Pulsante con icona + testo.</summary>
        public static Button IconTextButton(string styleKey, string glyph, string text, bool glyphAfter, RoutedEventHandler click)
        {
            var sp = new StackPanel();
            sp.Orientation = Orientation.Horizontal;
            var ic = Icon(glyph, 11, null);
            ic.Foreground = null;
            var tb = new TextBlock();
            tb.Text = text;
            tb.VerticalAlignment = VerticalAlignment.Center;
            if (glyphAfter)
            {
                ic.Margin = new Thickness(8, 1, 0, 0);
                sp.Children.Add(tb);
                sp.Children.Add(ic);
            }
            else
            {
                ic.Margin = new Thickness(0, 1, 8, 0);
                sp.Children.Add(ic);
                sp.Children.Add(tb);
            }
            // l'icona eredita il colore dal pulsante
            ic.ClearValue(TextBlock.ForegroundProperty);
            return Button(styleKey, sp, click);
        }

        public static ToggleButton Switch(object content)
        {
            var t = new ToggleButton();
            t.SetResourceReference(FrameworkElement.StyleProperty, "Switch");
            t.Content = content;
            return t;
        }

        public static TextBox Input(string placeholder)
        {
            var t = new TextBox();
            t.SetResourceReference(FrameworkElement.StyleProperty, "Input");
            t.Tag = placeholder;
            return t;
        }

        public static Border Card()
        {
            var b = new Border();
            b.CornerRadius = new CornerRadius(6);
            b.BorderThickness = new Thickness(1);
            b.SetResourceReference(Border.BackgroundProperty, "Card");
            b.SetResourceReference(Border.BorderBrushProperty, "CardBorder");
            return b;
        }

        public static Rectangle Divider(Thickness margin)
        {
            var r = new Rectangle();
            r.Height = 1;
            r.Margin = margin;
            r.SetResourceReference(Shape.FillProperty, "Divider");
            return r;
        }

        /// <summary>Controllo segmentato (es. schede o Statico/DHCP).</summary>
        public static Border Segmented(string group, params RadioButton[] items)
        {
            var host = new Border();
            host.CornerRadius = new CornerRadius(6);
            host.Padding = new Thickness(3);
            host.SetResourceReference(Border.BackgroundProperty, "Subtle");
            var grid = new UniformGrid();
            grid.Rows = 1;
            foreach (var rb in items)
            {
                rb.GroupName = group;
                rb.SetResourceReference(FrameworkElement.StyleProperty, "Seg");
                grid.Children.Add(rb);
            }
            host.Child = grid;
            return host;
        }

        public static RadioButton Seg(string text)
        {
            var rb = new RadioButton();
            rb.Content = text;
            return rb;
        }

        public static ScrollViewer Scroll(UIElement content)
        {
            var sv = new ScrollViewer();
            sv.VerticalScrollBarVisibility = ScrollBarVisibility.Auto;
            sv.HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled;
            sv.Content = content;
            sv.Focusable = false;
            return sv;
        }

        public static MenuItem MenuItem(string header, RoutedEventHandler click)
        {
            var mi = new MenuItem();
            mi.Header = header;
            if (click != null) mi.Click += click;
            return mi;
        }

        public static Separator MenuSeparator()
        {
            var s = new Separator();
            s.SetResourceReference(FrameworkElement.StyleProperty, "MenuSep");
            return s;
        }

        public static void ShowMenu(ContextMenu cm, FrameworkElement target)
        {
            cm.PlacementTarget = target;
            cm.Placement = PlacementMode.Bottom;
            cm.IsOpen = true;
        }

        public static string GlyphFor(AdapterInfo a)
        {
            string d = (a.Description + " " + a.Name).ToLowerInvariant();
            if (d.Contains("bluetooth")) return Glyph.Bluetooth;
            if (d.Contains("wi-fi") || d.Contains("wifi") || d.Contains("wireless") || d.Contains("wlan") || d.Contains("802.11")) return Glyph.Wifi;
            if (d.Contains("vpn") || d.Contains("virtual") || d.Contains("tap-") || d.Contains("wireguard") || d.Contains("fortinet") || d.Contains("hyper-v"))
                return Glyph.Vpn;
            return Glyph.Ethernet;
        }
    }
}
