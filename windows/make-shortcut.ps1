<#
=============================================================================
 make-shortcut.ps1  --  Crea l'icona "Continua il lavoro - Claude" sul desktop
=============================================================================
 L'icona, quando premuta, esegue resume-now.ps1: trova l'app Claude e clicca il
 pulsante di ripresa ("Continua a lavorare" / "Riprova") al posto tuo.

 Uso:
   powershell -ExecutionPolicy Bypass -File make-shortcut.ps1
   powershell -ExecutionPolicy Bypass -File make-shortcut.ps1 -Uninstall

 Made in Italy.
=============================================================================
#>
[CmdletBinding()]
param([switch]$Uninstall)

$ErrorActionPreference = 'Stop'
$InstallDir = Join-Path $env:LOCALAPPDATA 'claude-ac'
$Desktop    = [Environment]::GetFolderPath('Desktop')

# Due icone: il tasto "riprendi tutto" e il check-up con lista a spunta.
$Shortcuts = @(
    @{ Script = 'resume-now.ps1';    Lnk = 'Continua il lavoro - Claude.lnk'; Desc = 'Premi quando i crediti tornano: riprende tutte le sessioni Claude. Made in Italy.' },
    @{ Script = 'resume-picker.ps1'; Lnk = 'Scegli sessioni - Claude.lnk';    Desc = 'Check-up: scegli quali sessioni Claude riprendere. Made in Italy.' }
)

if ($Uninstall) {
    foreach ($s in $Shortcuts) {
        $p = Join-Path $Desktop $s.Lnk
        if (Test-Path $p) { Remove-Item $p -Force; Write-Host "Rimossa: $($s.Lnk)" }
    }
    return
}

if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null }

# icona dell'app Claude, se disponibile
$claudeExe = (Get-Process claude -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -like '*WindowsApps*' } | Select-Object -First 1).Path
$icon = if ($claudeExe) { "$claudeExe,0" } else { "powershell.exe,0" }

$ws = New-Object -ComObject WScript.Shell
foreach ($s in $Shortcuts) {
    $target = Join-Path $InstallDir $s.Script
    Copy-Item -Path (Join-Path $PSScriptRoot $s.Script) -Destination $target -Force
    $lnkPath = Join-Path $Desktop $s.Lnk
    $sc = $ws.CreateShortcut($lnkPath)
    $sc.TargetPath       = (Get-Command powershell.exe).Source
    $sc.Arguments        = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$target`""
    $sc.WorkingDirectory = $InstallDir
    $sc.IconLocation     = $icon
    $sc.Description       = $s.Desc
    $sc.Save()
    Write-Host "Icona creata: $lnkPath"
}

Write-Host ""
Write-Host "Fatto! Sul desktop trovi due icone:"
Write-Host "  - 'Continua il lavoro - Claude' : riprende tutte le sessioni"
Write-Host "  - 'Scegli sessioni - Claude'    : check-up con lista a spunta"
