# Compila NetSwitch.exe con il compilatore C# incluso in Windows (.NET Framework 4.x).
# Uso:  powershell -ExecutionPolicy Bypass -File build.ps1
param(
    [string]$OutFile,
    [switch]$NoElevation   # solo per test: build senza richiesta di privilegi amministrativi
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $OutFile) { $OutFile = Join-Path $root 'NetSwitch.exe' }

$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
if (-not (Test-Path $csc)) { throw 'csc.exe (.NET Framework 4.x) non trovato.' }

$manifest = Join-Path $root 'app.manifest'
if ($NoElevation) {
    $tmp = Join-Path $env:TEMP 'netswitch_asinvoker.manifest'
    (Get-Content $manifest -Raw) -replace 'requireAdministrator', 'asInvoker' | Set-Content $tmp -Encoding utf8
    $manifest = $tmp
}

$wpf = Join-Path (Split-Path $csc) 'WPF'
$src = Get-ChildItem (Join-Path $root 'src') -Filter *.cs | ForEach-Object { $_.FullName }
# icona dell'eseguibile (rigenerabile con: NetSwitch.exe --make-icon app.ico)
$ico = Join-Path $root 'app.ico'
$icoArg = @(); if (Test-Path $ico) { $icoArg = @("/win32icon:$ico") }
& $csc /nologo /target:winexe /optimize+ /codepage:65001 /platform:anycpu "/out:$OutFile" "/win32manifest:$manifest" "/lib:$wpf" @icoArg `
    /r:System.dll /r:System.Core.dll /r:System.Drawing.dll /r:System.Windows.Forms.dll /r:System.Management.dll /r:System.Xml.dll `
    /r:PresentationFramework.dll /r:PresentationCore.dll /r:WindowsBase.dll /r:System.Xaml.dll `
    $src
if ($LASTEXITCODE -ne 0) { throw 'Compilazione fallita.' }
Write-Host "OK -> $OutFile"
