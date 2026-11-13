using System;
using System.Windows;
using System.Windows.Markup;
using System.Windows.Media;
using Microsoft.Win32;

namespace NetSwitch
{
    /// <summary>Tema in stile Windows 11: segue chiaro/scuro di sistema e colore d'accento.</summary>
    public static class Theme
    {
        public static bool IsDark { get; private set; }
        static bool stylesLoaded;

        public static void Apply(Application app)
        {
            IsDark = ReadIsDark();
            // diagnostica: tema forzato e accento fisso per gli screenshot della documentazione
            string forced = Program.DebugOn ? Environment.GetEnvironmentVariable("NETSWITCH_THEME") : null;
            if (forced == "dark" || forced == "light") IsDark = forced == "dark";
            var r = app.Resources;
            Color accent = ReadAccent(IsDark);
            if (Program.Fake) accent = IsDark ? Color.FromRgb(0x2D, 0xD4, 0xBF) : Color.FromRgb(0x0D, 0x94, 0x88);

            if (IsDark)
            {
                Set(r, "Bg", "#202020");
                Set(r, "Card", "#2B2B2B");
                Set(r, "CardHover", "#323232");
                Set(r, "CardBorder", "#3A3A3A");
                Set(r, "MenuBg", "#2C2C2C");
                Set(r, "Fg", "#FFFFFF");
                Set(r, "Fg2", "#C5C5C5");
                Set(r, "Fg3", "#8B8B8B");
                Set(r, "Subtle", "#0FFFFFFF");
                Set(r, "SubtleHover", "#1AFFFFFF");
                Set(r, "HoverOverlay", "#14FFFFFF");
                Set(r, "InputBg", "#2D2D2D");
                Set(r, "InputBorder", "#454545");
                Set(r, "Divider", "#383838");
                Set(r, "Overlay", "#99000000");
                Set(r, "Danger", "#FF99A4");
                Set(r, "DangerFill", "#C42B1C");
                Set(r, "Success", "#6CCB5F");
                Set(r, "Warning", "#FCE100");
                Set(r, "Amber", "#FFB900");
                Set(r, "CardOff", "#0AFFFFFF");
                Set(r, "AccentFg", "#000000");
            }
            else
            {
                Set(r, "Bg", "#F3F3F3");
                Set(r, "Card", "#FBFBFB");
                Set(r, "CardHover", "#F5F5F5");
                Set(r, "CardBorder", "#E3E3E3");
                Set(r, "MenuBg", "#F9F9F9");
                Set(r, "Fg", "#1B1B1B");
                Set(r, "Fg2", "#5D5D5D");
                Set(r, "Fg3", "#8E8E8E");
                Set(r, "Subtle", "#0A000000");
                Set(r, "SubtleHover", "#14000000");
                Set(r, "HoverOverlay", "#0D000000");
                Set(r, "InputBg", "#FFFFFF");
                Set(r, "InputBorder", "#D1D1D1");
                Set(r, "Divider", "#E5E5E5");
                Set(r, "Overlay", "#66000000");
                Set(r, "Danger", "#C42B1C");
                Set(r, "DangerFill", "#C42B1C");
                Set(r, "Success", "#0F7B0F");
                Set(r, "Warning", "#9D5D00");
                Set(r, "Amber", "#E8A200");
                Set(r, "CardOff", "#05000000");
                Set(r, "AccentFg", "#FFFFFF");
            }
            var ab = new SolidColorBrush(accent);
            ab.Freeze();
            r["Accent"] = ab;

            if (!stylesLoaded)
            {
                r.MergedDictionaries.Add((ResourceDictionary)XamlReader.Parse(StylesXaml));
                stylesLoaded = true;
            }
        }

        static void Set(ResourceDictionary r, string key, string hex)
        {
            var b = new SolidColorBrush((Color)ColorConverter.ConvertFromString(hex));
            b.Freeze();
            r[key] = b;
        }

        static bool ReadIsDark()
        {
            try
            {
                using (var k = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"))
                {
                    // i flyout della barra delle applicazioni seguono il tema "di sistema"
                    object v = k == null ? null : k.GetValue("SystemUsesLightTheme");
                    return v != null && Convert.ToInt32(v) == 0;
                }
            }
            catch { return false; }
        }

        static Color ReadAccent(bool dark)
        {
            try
            {
                using (var k = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Explorer\Accent"))
                {
                    var b = k == null ? null : k.GetValue("AccentPalette") as byte[];
                    if (b != null && b.Length >= 32)
                    {
                        // palette: 0 Light3, 1 Light2, 2 Light1, 3 Base, 4 Dark1, 5 Dark2, 6 Dark3
                        int i = dark ? 1 : 4;
                        return Color.FromRgb(b[i * 4], b[i * 4 + 1], b[i * 4 + 2]);
                    }
                }
            }
            catch { }
            return dark ? Color.FromRgb(0x60, 0xCD, 0xFF) : Color.FromRgb(0x00, 0x5F, 0xB8);
        }

        // Stili e template (attributi con apici singoli per comodità nella stringa C#)
        const string StylesXaml = @"
<ResourceDictionary xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
                    xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'>
  <FontFamily x:Key='IconFont'>Segoe Fluent Icons, Segoe MDL2 Assets</FontFamily>

  <ControlTemplate x:Key='BtnTemplate' TargetType='Button'>
    <Grid>
      <Border Background='{TemplateBinding Background}' BorderBrush='{TemplateBinding BorderBrush}'
              BorderThickness='{TemplateBinding BorderThickness}' CornerRadius='4'/>
      <Border x:Name='hover' Background='{DynamicResource HoverOverlay}' CornerRadius='4' Opacity='0'/>
      <ContentPresenter Margin='{TemplateBinding Padding}' HorizontalAlignment='{TemplateBinding HorizontalContentAlignment}'
                        VerticalAlignment='Center' RecognizesAccessKey='False'/>
    </Grid>
    <ControlTemplate.Triggers>
      <Trigger Property='IsMouseOver' Value='True'><Setter TargetName='hover' Property='Opacity' Value='1'/></Trigger>
      <Trigger Property='IsPressed' Value='True'><Setter Property='Opacity' Value='0.75'/></Trigger>
      <Trigger Property='IsEnabled' Value='False'><Setter Property='Opacity' Value='0.4'/></Trigger>
    </ControlTemplate.Triggers>
  </ControlTemplate>

  <Style x:Key='Btn' TargetType='Button'>
    <Setter Property='Foreground' Value='{DynamicResource Fg}'/>
    <Setter Property='Background' Value='{DynamicResource Subtle}'/>
    <Setter Property='BorderBrush' Value='{DynamicResource CardBorder}'/>
    <Setter Property='BorderThickness' Value='1'/>
    <Setter Property='Padding' Value='12,5,12,6'/>
    <Setter Property='FontSize' Value='12.5'/>
    <Setter Property='HorizontalContentAlignment' Value='Center'/>
    <Setter Property='Cursor' Value='Hand'/>
    <Setter Property='FocusVisualStyle' Value='{x:Null}'/>
    <Setter Property='Template' Value='{StaticResource BtnTemplate}'/>
  </Style>
  <Style x:Key='AccentBtn' TargetType='Button' BasedOn='{StaticResource Btn}'>
    <Setter Property='Foreground' Value='{DynamicResource AccentFg}'/>
    <Setter Property='Background' Value='{DynamicResource Accent}'/>
    <Setter Property='BorderThickness' Value='0'/>
    <Setter Property='FontWeight' Value='SemiBold'/>
  </Style>
  <Style x:Key='DangerBtn' TargetType='Button' BasedOn='{StaticResource Btn}'>
    <Setter Property='Foreground' Value='White'/>
    <Setter Property='Background' Value='{DynamicResource DangerFill}'/>
    <Setter Property='BorderThickness' Value='0'/>
    <Setter Property='FontWeight' Value='SemiBold'/>
  </Style>
  <Style x:Key='GhostBtn' TargetType='Button' BasedOn='{StaticResource Btn}'>
    <Setter Property='Background' Value='Transparent'/>
    <Setter Property='BorderThickness' Value='0'/>
  </Style>
  <Style x:Key='IconBtn' TargetType='Button' BasedOn='{StaticResource GhostBtn}'>
    <Setter Property='FontFamily' Value='{StaticResource IconFont}'/>
    <Setter Property='FontSize' Value='14'/>
    <Setter Property='Padding' Value='0'/>
    <Setter Property='Width' Value='32'/>
    <Setter Property='Height' Value='32'/>
  </Style>

  <Style x:Key='Switch' TargetType='ToggleButton'>
    <Setter Property='Cursor' Value='Hand'/>
    <Setter Property='FocusVisualStyle' Value='{x:Null}'/>
    <Setter Property='Foreground' Value='{DynamicResource Fg}'/>
    <Setter Property='Template'>
      <Setter.Value>
        <ControlTemplate TargetType='ToggleButton'>
          <Grid Background='Transparent'>
            <Grid.ColumnDefinitions><ColumnDefinition Width='Auto'/><ColumnDefinition Width='*'/></Grid.ColumnDefinitions>
            <Border x:Name='track' Width='40' Height='20' CornerRadius='10' BorderThickness='1'
                    BorderBrush='{DynamicResource Fg2}' Background='Transparent' VerticalAlignment='Center'>
              <Ellipse x:Name='thumb' Width='12' Height='12' Fill='{DynamicResource Fg2}'
                       HorizontalAlignment='Left' VerticalAlignment='Center' Margin='4,0,0,0'/>
            </Border>
            <ContentPresenter Grid.Column='1' Margin='10,0,0,0' VerticalAlignment='Center'/>
          </Grid>
          <ControlTemplate.Triggers>
            <Trigger Property='IsChecked' Value='True'>
              <Setter TargetName='track' Property='Background' Value='{DynamicResource Accent}'/>
              <Setter TargetName='track' Property='BorderBrush' Value='{DynamicResource Accent}'/>
              <Setter TargetName='thumb' Property='Fill' Value='{DynamicResource AccentFg}'/>
              <Setter TargetName='thumb' Property='HorizontalAlignment' Value='Right'/>
              <Setter TargetName='thumb' Property='Margin' Value='0,0,4,0'/>
            </Trigger>
            <Trigger Property='IsMouseOver' Value='True'>
              <Setter TargetName='thumb' Property='Width' Value='14'/>
              <Setter TargetName='thumb' Property='Height' Value='14'/>
            </Trigger>
            <Trigger Property='IsEnabled' Value='False'><Setter Property='Opacity' Value='0.4'/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style x:Key='Seg' TargetType='RadioButton'>
    <Setter Property='Foreground' Value='{DynamicResource Fg2}'/>
    <Setter Property='Cursor' Value='Hand'/>
    <Setter Property='FocusVisualStyle' Value='{x:Null}'/>
    <Setter Property='FontSize' Value='12.5'/>
    <Setter Property='Template'>
      <Setter.Value>
        <ControlTemplate TargetType='RadioButton'>
          <Border x:Name='b' CornerRadius='4' Padding='10,5,10,6' Background='Transparent'>
            <ContentPresenter HorizontalAlignment='Center' VerticalAlignment='Center'/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property='IsMouseOver' Value='True'><Setter Property='Foreground' Value='{DynamicResource Fg}'/></Trigger>
            <Trigger Property='IsChecked' Value='True'>
              <Setter TargetName='b' Property='Background' Value='{DynamicResource Card}'/>
              <Setter Property='Foreground' Value='{DynamicResource Fg}'/>
              <Setter Property='FontWeight' Value='SemiBold'/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style x:Key='Input' TargetType='TextBox'>
    <Setter Property='Foreground' Value='{DynamicResource Fg}'/>
    <Setter Property='CaretBrush' Value='{DynamicResource Fg}'/>
    <Setter Property='SelectionBrush' Value='{DynamicResource Accent}'/>
    <Setter Property='Background' Value='{DynamicResource InputBg}'/>
    <Setter Property='BorderBrush' Value='{DynamicResource InputBorder}'/>
    <Setter Property='BorderThickness' Value='1'/>
    <Setter Property='Padding' Value='8,6,8,6'/>
    <Setter Property='FontSize' Value='13'/>
    <Setter Property='Template'>
      <Setter.Value>
        <ControlTemplate TargetType='TextBox'>
          <Grid>
            <Border x:Name='b' CornerRadius='4' Background='{TemplateBinding Background}'
                    BorderBrush='{TemplateBinding BorderBrush}' BorderThickness='{TemplateBinding BorderThickness}'/>
            <Border x:Name='line' CornerRadius='0,0,4,4' Height='2' VerticalAlignment='Bottom' Margin='1,0,1,0'
                    Background='{DynamicResource Accent}' Visibility='Collapsed'/>
            <ScrollViewer x:Name='PART_ContentHost' Margin='{TemplateBinding Padding}' VerticalAlignment='Center'/>
            <TextBlock x:Name='ph' Text='{Binding Tag, RelativeSource={RelativeSource TemplatedParent}}'
                       Foreground='{DynamicResource Fg3}' Margin='10,0,10,0' VerticalAlignment='Center'
                       IsHitTestVisible='False' Visibility='Collapsed'/>
          </Grid>
          <ControlTemplate.Triggers>
            <Trigger Property='Text' Value=''><Setter TargetName='ph' Property='Visibility' Value='Visible'/></Trigger>
            <Trigger Property='IsKeyboardFocused' Value='True'><Setter TargetName='line' Property='Visibility' Value='Visible'/></Trigger>
            <Trigger Property='IsEnabled' Value='False'><Setter Property='Opacity' Value='0.45'/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style TargetType='ScrollBar'>
    <Setter Property='Width' Value='6'/>
    <Setter Property='MinWidth' Value='6'/>
    <Setter Property='Template'>
      <Setter.Value>
        <ControlTemplate TargetType='ScrollBar'>
          <Track x:Name='PART_Track' IsDirectionReversed='True'>
            <Track.Thumb>
              <Thumb>
                <Thumb.Template>
                  <ControlTemplate TargetType='Thumb'>
                    <Border CornerRadius='3' Background='{DynamicResource Fg3}' Opacity='0.55'/>
                  </ControlTemplate>
                </Thumb.Template>
              </Thumb>
            </Track.Thumb>
          </Track>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style TargetType='ContextMenu'>
    <Setter Property='OverridesDefaultStyle' Value='True'/>
    <Setter Property='FontFamily' Value='Segoe UI Variable Text, Segoe UI'/>
    <Setter Property='FontSize' Value='13'/>
    <Setter Property='SnapsToDevicePixels' Value='True'/>
    <Setter Property='HasDropShadow' Value='True'/>
    <Setter Property='Template'>
      <Setter.Value>
        <ControlTemplate TargetType='ContextMenu'>
          <Border Margin='0,0,10,10'>
            <Border Background='{DynamicResource MenuBg}' BorderBrush='{DynamicResource CardBorder}'
                    BorderThickness='1' CornerRadius='8' Padding='4'>
              <Border.Effect><DropShadowEffect BlurRadius='10' ShadowDepth='2' Direction='270' Opacity='0.28'/></Border.Effect>
              <StackPanel IsItemsHost='True' KeyboardNavigation.DirectionalNavigation='Cycle'/>
            </Border>
          </Border>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style TargetType='MenuItem'>
    <Setter Property='OverridesDefaultStyle' Value='True'/>
    <Setter Property='Foreground' Value='{DynamicResource Fg}'/>
    <Setter Property='FontSize' Value='13'/>
    <Setter Property='Template'>
      <Setter.Value>
        <ControlTemplate TargetType='MenuItem'>
          <Border x:Name='b' CornerRadius='4' Padding='8,6,14,7' Background='Transparent' MinWidth='170'>
            <Grid>
              <Grid.ColumnDefinitions><ColumnDefinition Width='24'/><ColumnDefinition Width='*'/></Grid.ColumnDefinitions>
              <TextBlock x:Name='chk' Text='&#xE73E;' FontFamily='{StaticResource IconFont}' FontSize='12'
                         VerticalAlignment='Center' Visibility='Hidden'/>
              <ContentPresenter x:Name='ico' ContentSource='Icon' VerticalAlignment='Center' HorizontalAlignment='Left'/>
              <ContentPresenter Grid.Column='1' ContentSource='Header' RecognizesAccessKey='False' VerticalAlignment='Center'/>
            </Grid>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property='IsHighlighted' Value='True'><Setter TargetName='b' Property='Background' Value='{DynamicResource SubtleHover}'/></Trigger>
            <Trigger Property='IsChecked' Value='True'><Setter TargetName='chk' Property='Visibility' Value='Visible'/></Trigger>
            <Trigger Property='IsEnabled' Value='False'><Setter Property='Foreground' Value='{DynamicResource Fg3}'/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style x:Key='MenuSep' TargetType='Separator'>
    <Setter Property='Template'>
      <Setter.Value>
        <ControlTemplate TargetType='Separator'>
          <Border Height='1' Margin='6,4,6,4' Background='{DynamicResource Divider}'/>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style TargetType='ToolTip'>
    <Setter Property='OverridesDefaultStyle' Value='True'/>
    <Setter Property='FontFamily' Value='Segoe UI Variable Text, Segoe UI'/>
    <Setter Property='HasDropShadow' Value='False'/>
    <Setter Property='Template'>
      <Setter.Value>
        <ControlTemplate TargetType='ToolTip'>
          <Border Background='{DynamicResource MenuBg}' BorderBrush='{DynamicResource CardBorder}' BorderThickness='1'
                  CornerRadius='4' Padding='8,4,8,5'>
            <ContentPresenter TextElement.Foreground='{DynamicResource Fg}' TextElement.FontSize='12'/>
          </Border>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
</ResourceDictionary>";
    }
}
