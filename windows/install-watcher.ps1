<#
=============================================================================
 install-watcher.ps1  --  Installa il "Resume Watcher" per l'app Claude
=============================================================================
 Copia resume-watcher.ps1 in una cartella stabile, registra un'attivita'
 pianificata che lo avvia AL LOGIN (nella sessione interattiva, nascosto) e
 lo fa partire subito.

 Uso:
   powershell -ExecutionPolicy Bypass -File install-watcher.ps1
   powershell -ExecutionPolicy Bypass -File install-watcher.ps1 -Uninstall

 Made in Italy.
=============================================================================
#>
[CmdletBinding()]
param([switch]$Uninstall)

$ErrorActionPreference = 'Stop'
$TaskName   = 'ClaudeAutoContinueWatcher'
$InstallDir = Join-Path $env:LOCALAPPDATA 'claude-ac'
$Target     = Join-Path $InstallDir 'resume-watcher.ps1'
$Src        = Join-Path $PSScriptRoot 'resume-watcher.ps1'

function Write-Step($m){ Write-Host "  > $m" }

if ($Uninstall) {
    Write-Host "Disinstallazione Resume Watcher..."
    try { Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue } catch {}
    try { Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop; Write-Step "Attivita' pianificata rimossa." } catch { Write-Step "Nessuna attivita' da rimuovere." }
    Get-Process powershell -ErrorAction SilentlyContinue | Where-Object {
        try { $_.CommandLine -like '*resume-watcher.ps1*' } catch { $false }
    } | ForEach-Object { try { Stop-Process -Id $_.Id -Force } catch {} }
    Write-Host "Fatto."
    return
}

Write-Host "Installazione Resume Watcher per l'app Claude..."

# 1) copia in cartella stabile
if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null }
Copy-Item -Path $Src -Destination $Target -Force
Write-Step "Watcher copiato in: $Target"

# 2) registra attivita' pianificata (al login, sessione interattiva, nascosto)
$psExe  = (Get-Command powershell.exe).Source
$arg    = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Target`""
$action = New-ScheduledTaskAction -Execute $psExe -Argument $arg
$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

try { Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue } catch {}
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "Auto-Continue: clicca 'Continua a lavorare' nell'app Claude quando i crediti tornano. Made in Italy." | Out-Null
Write-Step "Attivita' pianificata '$TaskName' registrata (avvio al login)."

# 3) avvia subito
Start-ScheduledTask -TaskName $TaskName
Write-Step "Watcher avviato."

Write-Host ""
Write-Host "Fatto! Il sorvegliante e' attivo e ripartira' a ogni accesso a Windows."
Write-Host "Log: $($env:USERPROFILE)\.cache\claude-ac\resume-watcher.log"
