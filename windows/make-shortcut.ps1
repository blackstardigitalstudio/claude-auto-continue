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
$Target     = Join-Path $InstallDir 'resume-now.ps1'
$Desktop    = [Environment]::GetFolderPath('Desktop')
$LnkPath    = Join-Path $Desktop 'Continua il lavoro - Claude.lnk'

if ($Uninstall) {
    if (Test-Path $LnkPath) { Remove-Item $LnkPath -Force; Write-Host "Icona rimossa." }
    else { Write-Host "Nessuna icona da rimuovere." }
    return
}

# copia resume-now.ps1 in cartella stabile
if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null }
Copy-Item -Path (Join-Path $PSScriptRoot 'resume-now.ps1') -Destination $Target -Force

# icona dell'app Claude, se disponibile
$claudeExe = (Get-Process claude -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -like '*WindowsApps*' } | Select-Object -First 1).Path
$icon = if ($claudeExe) { "$claudeExe,0" } else { "powershell.exe,0" }

$ws = New-Object -ComObject WScript.Shell
$sc = $ws.CreateShortcut($LnkPath)
$sc.TargetPath       = (Get-Command powershell.exe).Source
$sc.Arguments        = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Target`""
$sc.WorkingDirectory = $InstallDir
$sc.IconLocation     = $icon
$sc.Description       = "Premi quando i crediti tornano: riprende la sessione Claude. Made in Italy."
$sc.Save()

Write-Host "Fatto! Icona creata sul desktop:"
Write-Host "  $LnkPath"
Write-Host ""
Write-Host "Quando i crediti tornano, fai doppio clic sull'icona e Claude riprende."
