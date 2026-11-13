using System;
using System.Drawing;
using System.Drawing.Drawing2D;

namespace NetSwitch
{
    /// <summary>Icone disegnate a runtime (nessun file esterno necessario).</summary>
    public static class AppIcon
    {
        static Icon app;
        static Bitmap green, gray, red;

        public static Icon App
        {
            get
            {
                if (app == null) app = Icon.FromHandle(DrawApp(32).GetHicon());
                return app;
            }
        }

        public static Bitmap DotConnected { get { return green ?? (green = Dot(Color.FromArgb(46, 160, 67))); } }
        public static Bitmap DotDisconnected { get { return gray ?? (gray = Dot(Color.FromArgb(232, 162, 0))); } }
        public static Bitmap DotDisabled { get { return red ?? (red = Ring(Color.FromArgb(142, 142, 142))); } }

        static Bitmap Ring(Color c)
        {
            var bmp = new Bitmap(16, 16);
            using (var g = Graphics.FromImage(bmp))
            {
                g.SmoothingMode = SmoothingMode.AntiAlias;
                g.Clear(Color.Transparent);
                using (var p = new Pen(c, 1.6f)) g.DrawEllipse(p, 3.5f, 3.5f, 9, 9);
            }
            return bmp;
        }

        public static Bitmap DotFor(AdapterInfo a)
        {
            if (!a.AdminEnabled) return DotDisabled;
            return a.IsConnected ? DotConnected : DotDisconnected;
        }

        static Bitmap DrawApp(int size)
        {
            var bmp = new Bitmap(size, size);
            using (var g = Graphics.FromImage(bmp))
            {
                g.SmoothingMode = SmoothingMode.AntiAlias;
                g.Clear(Color.Transparent);
                float s = size / 32f;
                using (var path = RoundRect(new RectangleF(1 * s, 1 * s, 30 * s, 30 * s), 7 * s))
                using (var b = new SolidBrush(Color.FromArgb(0, 137, 123)))
                    g.FillPath(b, path);
                using (var pen = new Pen(Color.White, 2.4f * s))
                {
                    g.DrawLine(pen, 16 * s, 11 * s, 16 * s, 17 * s);
                    g.DrawLine(pen, 9 * s, 17 * s, 23 * s, 17 * s);
                    g.DrawLine(pen, 9 * s, 17 * s, 9 * s, 21 * s);
                    g.DrawLine(pen, 23 * s, 17 * s, 23 * s, 21 * s);
                }
                using (var w = new SolidBrush(Color.White))
                {
                    g.FillRectangle(w, 11 * s, 5 * s, 10 * s, 7 * s);
                    g.FillRectangle(w, 4 * s, 20 * s, 10 * s, 7 * s);
                    g.FillRectangle(w, 18 * s, 20 * s, 10 * s, 7 * s);
                }
            }
            return bmp;
        }

        static Bitmap Dot(Color c)
        {
            var bmp = new Bitmap(16, 16);
            using (var g = Graphics.FromImage(bmp))
            {
                g.SmoothingMode = SmoothingMode.AntiAlias;
                g.Clear(Color.Transparent);
                using (var b = new SolidBrush(c)) g.FillEllipse(b, 3, 3, 10, 10);
                using (var p = new Pen(Color.FromArgb(90, 0, 0, 0), 1f)) g.DrawEllipse(p, 3, 3, 10, 10);
            }
            return bmp;
        }

        static GraphicsPath RoundRect(RectangleF r, float radius)
        {
            float d = radius * 2;
            var p = new GraphicsPath();
            p.AddArc(r.X, r.Y, d, d, 180, 90);
            p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
            p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
            p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
            p.CloseFigure();
            return p;
        }
    }
}
