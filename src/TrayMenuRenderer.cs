using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace NetSwitch
{
    /// <summary>Renderer "piatto" in stile Windows 11 per il menu del tasto destro sull'icona.</summary>
    public class TrayMenuRenderer : ToolStripProfessionalRenderer
    {
        readonly bool dark;

        public TrayMenuRenderer(bool dark) : base(new Colors(dark))
        {
            this.dark = dark;
            RoundedEdges = false;
        }

        Color Fg { get { return dark ? Color.White : Color.FromArgb(27, 27, 27); } }
        Color FgDisabled { get { return dark ? Color.FromArgb(120, 120, 120) : Color.FromArgb(160, 160, 160); } }
        Color Hover { get { return dark ? Color.FromArgb(61, 61, 61) : Color.FromArgb(232, 232, 232); } }
        Color Line { get { return dark ? Color.FromArgb(64, 64, 64) : Color.FromArgb(222, 222, 222); } }

        public static void Pad(ToolStripItemCollection items)
        {
            foreach (ToolStripItem it in items)
            {
                var mi = it as ToolStripMenuItem;
                if (mi == null) continue;
                mi.Padding = new Padding(2, 5, 2, 5);
                if (mi.HasDropDownItems) Pad(mi.DropDownItems);
            }
        }

        protected override void OnRenderItemText(ToolStripItemTextRenderEventArgs e)
        {
            e.TextColor = e.Item.Enabled ? Fg : FgDisabled;
            base.OnRenderItemText(e);
        }

        protected override void OnRenderMenuItemBackground(ToolStripItemRenderEventArgs e)
        {
            if (!e.Item.Selected || !e.Item.Enabled) return;
            var r = new Rectangle(4, 1, e.Item.Width - 8, e.Item.Height - 2);
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            using (var b = new SolidBrush(Hover))
            using (var p = Round(r, 4)) e.Graphics.FillPath(b, p);
        }

        protected override void OnRenderArrow(ToolStripArrowRenderEventArgs e)
        {
            e.ArrowColor = e.Item.Enabled ? Fg : FgDisabled;
            base.OnRenderArrow(e);
        }

        protected override void OnRenderSeparator(ToolStripSeparatorRenderEventArgs e)
        {
            int y = e.Item.Height / 2;
            using (var p = new Pen(Line)) e.Graphics.DrawLine(p, 10, y, e.Item.Width - 10, y);
        }

        protected override void OnRenderImageMargin(ToolStripRenderEventArgs e) { }

        protected override void OnRenderItemCheck(ToolStripItemImageRenderEventArgs e)
        {
            var r = e.ImageRectangle;
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            using (var p = new Pen(Fg, 1.6f))
            {
                p.StartCap = LineCap.Round; p.EndCap = LineCap.Round;
                float cx = r.Left + r.Width / 2f, cy = r.Top + r.Height / 2f;
                e.Graphics.DrawLines(p, new[] { new PointF(cx - 5, cy), new PointF(cx - 1.5f, cy + 3.5f), new PointF(cx + 5, cy - 4) });
            }
        }

        protected override void OnRenderToolStripBorder(ToolStripRenderEventArgs e)
        {
            var r = new Rectangle(0, 0, e.ToolStrip.Width - 1, e.ToolStrip.Height - 1);
            using (var p = new Pen(Line)) e.Graphics.DrawRectangle(p, r);
        }

        static GraphicsPath Round(Rectangle r, int rad)
        {
            int d = rad * 2;
            var p = new GraphicsPath();
            p.AddArc(r.X, r.Y, d, d, 180, 90);
            p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
            p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
            p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
            p.CloseFigure();
            return p;
        }

        class Colors : ProfessionalColorTable
        {
            readonly Color bg;
            public Colors(bool dark)
            {
                bg = dark ? Color.FromArgb(44, 44, 44) : Color.FromArgb(249, 249, 249);
                UseSystemColors = false;
            }
            public override Color ToolStripDropDownBackground { get { return bg; } }
            public override Color ImageMarginGradientBegin { get { return bg; } }
            public override Color ImageMarginGradientMiddle { get { return bg; } }
            public override Color ImageMarginGradientEnd { get { return bg; } }
            public override Color MenuBorder { get { return bg; } }
            public override Color MenuItemBorder { get { return Color.Transparent; } }
            public override Color MenuItemSelected { get { return bg; } }
            public override Color CheckBackground { get { return bg; } }
            public override Color CheckSelectedBackground { get { return bg; } }
            public override Color CheckPressedBackground { get { return bg; } }
        }
    }
}
