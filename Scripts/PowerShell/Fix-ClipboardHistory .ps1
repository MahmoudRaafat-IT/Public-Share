<#
.SYNOPSIS
  Fix Windows Clipboard History (Win+V) by deleting Clipboard cache folders directly,
  ensuring Clipboard History is enabled in Registry, and restarting clipboard processes.

.DESCRIPTION
  - Elevates to Administrator if needed.
  - Stops clipboard-related processes (rdpclip.exe, TextInputHost.exe) if running.
  - Deletes HistoryData and Pinned folders from the user's clipboard directory.
  - Ensures HKCU:\Software\Microsoft\Clipboard\EnableClipboardHistory is set to 1 (DWORD).
  - Restarts clipboard processes where possible.
  - Prompts user to press Win+V and suggests reboot if issue persists.

.NOTES
  Run as: .\Fix-ClipboardHistory_NoBackup.ps1
  The script will re-launch itself with elevated privileges if required.
#>

function Test-IsAdmin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Write-Output "Not running as administrator. Relaunching script with elevated privileges..."
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs
    exit
}

$clipboardPath = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Clipboard"
$foldersToDelete = @("HistoryData", "Pinned")

Write-Output "Stopping clipboard-related processes..."

$processesToStop = @("rdpclip","TextInputHost")
foreach ($p in $processesToStop) {
    $proc = Get-Process -Name $p -ErrorAction SilentlyContinue
    if ($proc) {
        try {
            Stop-Process -Id $proc.Id -Force -ErrorAction Stop
            Write-Output "Stopped process: $p (Id: $($proc.Id))"
        } catch {
            Write-Output "Failed to stop process $p. Error: $_"
        }
    } else {
        Write-Output "Process not running: $p"
    }
}

if (-not (Test-Path $clipboardPath)) {
    Write-Output "Clipboard folder does not exist: $clipboardPath. Exiting."
    exit
}

foreach ($folder in $foldersToDelete) {
    $fullFolder = Join-Path $clipboardPath $folder
    if (Test-Path $fullFolder) {
        try {
            Remove-Item -Path $fullFolder -Recurse -Force -ErrorAction Stop
            Write-Output "Deleted folder: $fullFolder"
        } catch {
            Write-Output "Error: Failed to delete folder '$fullFolder'. Error: $_"
        }
    } else {
        Write-Output "Folder not found (skipping): $fullFolder"
    }
}

# Ensure Clipboard History enabled in registry
$regPath = "HKCU:\Software\Microsoft\Clipboard"
$regName = "EnableClipboardHistory"
$desiredValue = 1

try {
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
        Write-Output "Created registry key: $regPath"
    }

    $current = Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue
    if (($current -eq $null) -or ($current.$regName -ne $desiredValue)) {
        Set-ItemProperty -Path $regPath -Name $regName -Value $desiredValue -Type DWord -Force
        Write-Output "Set registry $regPath\$regName = $desiredValue"
    } else {
        Write-Output "Registry already set: $regPath\$regName = $($current.$regName)"
    }
} catch {
    Write-Output "Error while updating registry: $_"
}

# Restart clipboard processes
try {
    $rdpclipPath = (Get-Command rdpclip.exe -ErrorAction SilentlyContinue).Source
    if ($rdpclipPath) {
        Start-Process -FilePath $rdpclipPath -ErrorAction Stop
        Write-Output "Started rdpclip.exe from $rdpclipPath"
    } else {
        Write-Output "rdpclip.exe not found in PATH - skipping start"
    }
} catch {
    Write-Output "Failed to start rdpclip.exe. Error: $_"
}

try {
    $textInputPath = Join-Path $env:WINDIR "System32\TextInputHost.exe"
    if (Test-Path $textInputPath) {
        Start-Process -FilePath $textInputPath -ErrorAction Stop
        Write-Output "Started TextInputHost.exe from $textInputPath"
    } else {
        Write-Output "TextInputHost.exe not found at $textInputPath - skipping start"
    }
} catch {
    Write-Output "Failed to start TextInputHost.exe. Error: $_"
}

Write-Output "Done! Please press Win + V to check Clipboard History."
Write-Output "If the issue persists, please restart your computer."
