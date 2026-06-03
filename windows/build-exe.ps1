<#
=============================================================================
 build-exe.ps1  --  Genera i .exe (con icona) dei tasti, partendo dagli script
=============================================================================
 Crea due eseguibili che lanciano gli script .ps1 affiancati:
   - "Continua il lavoro.exe"  -> resume-now.ps1
   - "Scegli sessioni.exe"     -> resume-picker.ps1

 Sono semplici LAUNCHER trasparenti: avviano lo script PowerShell che sta nella
 stessa cartella. Nessun codice nascosto, nessuna rete. L'icona e' incorporata.

 Compila con il C# del .NET Framework (csc.exe), gia' presente su Windows.

 Uso:
   powershell -ExecutionPolicy Bypass -File build-exe.ps1
   powershell -ExecutionPolicy Bypass -File build-exe.ps1 -OutDir "C:\percorso"

 Made in Italy.
=============================================================================
#>
[CmdletBinding()]
param([string]$OutDir = (Join-Path $env:LOCALAPPDATA 'claude-ac'))

$ErrorActionPreference='Stop'
$csc = @(
  "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe",
  "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if(-not $csc){ throw "csc.exe (.NET Framework) non trovato." }

$icon = Join-Path $PSScriptRoot 'claude-ac.ico'
if(-not (Test-Path $icon)){ throw "Icona non trovata: $icon" }
if(-not (Test-Path $OutDir)){ New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

# copia gli script accanto agli exe (i launcher li avviano dalla stessa cartella)
foreach($s in 'resume-now.ps1','resume-picker.ps1'){ Copy-Item (Join-Path $PSScriptRoot $s) (Join-Path $OutDir $s) -Force }
Copy-Item $icon (Join-Path $OutDir 'claude-ac.ico') -Force

$builds = @(
  @{ Script='resume-now.ps1';    Exe='Continua il lavoro.exe' },
  @{ Script='resume-picker.ps1'; Exe='Scegli sessioni.exe' }
)

$template = @'
using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
class Launcher {
    [STAThread]
    static void Main() {
        try {
            string dir = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
            string script = Path.Combine(dir, "__SCRIPT__");
            var psi = new ProcessStartInfo("powershell.exe",
                "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + script + "\"");
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            Process.Start(psi);
        } catch { }
    }
}
'@

foreach($b in $builds){
    $src = Join-Path $env:TEMP ("launcher_" + [IO.Path]::GetFileNameWithoutExtension($b.Script) + ".cs")
    ($template -replace '__SCRIPT__', $b.Script) | Set-Content -Path $src -Encoding UTF8
    $out = Join-Path $OutDir $b.Exe
    & $csc /nologo /target:winexe ("/win32icon:" + $icon) ("/out:" + $out) $src 2>&1 | Out-Null
    if(Test-Path $out){ Write-Host ("Creato: " + $out) } else { Write-Host ("ERRORE nel creare " + $b.Exe) }
    Remove-Item $src -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Fatto. Gli .exe sono in: $OutDir"
