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
                // disegnata alla dimensione esatta delle icone piccole (tray), secondo i DPI
                if (app == null) app = Icon.FromHandle(DrawApp(System.Windows.Forms.SystemInformation.SmallIconSize.Width).GetHicon());
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

        /// <summary>
        /// Logo: tre nodi di rete collegati da curve, su fondo arrotondato con sfumatura
        /// verde acqua → blu. Coordinate su griglia 32×32 (uguali a UI.Logo e al logo del sito).
        /// </summary>
        public static Bitmap DrawApp(int size)
        {
            var bmp = new Bitmap(size, size);
            using (var g = Graphics.FromImage(bmp))
            {
                g.SmoothingMode = SmoothingMode.AntiAlias;
                g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                g.Clear(Color.Transparent);
                float s = size / 32f;
                // alle dimensioni piccole (tray) tratti un po' più spessi per restare leggibili
                float boost = size <= 20 ? 1.25f : 1f;
                var rect = new RectangleF(1 * s, 1 * s, 30 * s, 30 * s);
                using (var path = RoundRect(rect, 9 * s))
                using (var b = new LinearGradientBrush(rect, Color.FromArgb(0x2D, 0xD4, 0xBF), Color.FromArgb(0x02, 0x84, 0xC7), 45f))
                    g.FillPath(b, path);
                using (var pen = new Pen(Color.White, 2.6f * s * boost))
                {
                    pen.StartCap = LineCap.Round; pen.EndCap = LineCap.Round;
                    g.DrawBezier(pen, 16 * s, 10.5f * s, 16 * s, 16 * s, 9.5f * s, 15.5f * s, 9.5f * s, 21.5f * s);
                    g.DrawBezier(pen, 16 * s, 10.5f * s, 16 * s, 16 * s, 22.5f * s, 15.5f * s, 22.5f * s, 21.5f * s);
                }
                using (var w = new SolidBrush(Color.White))
                {
                    Circle(g, w, 16 * s, 10 * s, 4.2f * s * boost);
                    Circle(g, w, 9.5f * s, 22 * s, 3.3f * s * boost);
                    Circle(g, w, 22.5f * s, 22 * s, 3.3f * s * boost);
                }
                using (var c = new SolidBrush(Color.FromArgb(0x0E, 0xA5, 0xE9)))
                    Circle(g, c, 16 * s, 10 * s, 1.7f * s * boost);
            }
            return bmp;
        }

        static byte[] Png(Bitmap bmp)
        {
            using (var ms = new System.IO.MemoryStream())
            {
                bmp.Save(ms, System.Drawing.Imaging.ImageFormat.Png);
                return ms.ToArray();
            }
        }

        /// <summary>Immagine di icona in formato DIB: BITMAPINFOHEADER + pixel BGRA dal basso + maschera AND.</summary>
        static byte[] Dib(Bitmap bmp)
        {
            int w = bmp.Width, h = bmp.Height;
            int maskStride = ((w + 31) / 32) * 4;
            using (var ms = new System.IO.MemoryStream())
            using (var bw = new System.IO.BinaryWriter(ms))
            {
                bw.Write(40); bw.Write(w); bw.Write(h * 2); bw.Write((short)1); bw.Write((short)32);
                bw.Write(0); bw.Write(w * h * 4 + maskStride * h); bw.Write(0); bw.Write(0); bw.Write(0); bw.Write(0);
                for (int y = h - 1; y >= 0; y--)
                    for (int x = 0; x < w; x++)
                    {
                        Color c = bmp.GetPixel(x, y);
                        bw.Write(c.B); bw.Write(c.G); bw.Write(c.R); bw.Write(c.A);
                    }
                bw.Write(new byte[maskStride * h]);
                return ms.ToArray();
            }
        }

        static void Circle(Graphics g, Brush b, float cx, float cy, float r)
        {
            g.FillEllipse(b, cx - r, cy - r, r * 2, r * 2);
        }

        /// <summary>Scrive un file .ico multi-risoluzione (PNG incorporati) con il logo.</summary>
        public static void WriteIco(string path)
        {
            int[] sizes = { 16, 20, 24, 32, 40, 48, 64, 256 };
            // 256 px come PNG, le altre come bitmap 32 bit (massima compatibilità)
            var pngs = new byte[sizes.Length][];
            for (int i = 0; i < sizes.Length; i++)
                using (var bmp = DrawApp(sizes[i]))
                    pngs[i] = sizes[i] >= 256 ? Png(bmp) : Dib(bmp);
            using (var fs = System.IO.File.Create(path))
            using (var w = new System.IO.BinaryWriter(fs))
            {
                w.Write((short)0); w.Write((short)1); w.Write((short)sizes.Length);
                int offset = 6 + 16 * sizes.Length;
                for (int i = 0; i < sizes.Length; i++)
                {
                    w.Write((byte)(sizes[i] >= 256 ? 0 : sizes[i]));
                    w.Write((byte)(sizes[i] >= 256 ? 0 : sizes[i]));
                    w.Write((byte)0); w.Write((byte)0);
                    w.Write((short)1); w.Write((short)32);
                    w.Write(pngs[i].Length); w.Write(offset);
                    offset += pngs[i].Length;
                }
                foreach (var p in pngs) w.Write(p);
            }
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
