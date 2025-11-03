# ============================================================
# 🔊 Windows 11 - Full Audio Driver Repair & Reset Tool
# ------------------------------------------------------------
# This PowerShell script completely resets and reinstalls
# the entire Windows Audio subsystem.
#
# 🧰 Features:
#   • Stops all audio services
#   • Removes every installed audio driver
#   • Cleans old driver packages from DriverStore
#   • Rescans hardware and reinstalls fresh drivers
#   • Restarts services and performs sound test
#
# ------------------------------------------------------------
# 👨‍💻 Author : Mahmoud Raafat
# 🔗 LinkedIn: https://www.linkedin.com/in/mahmoudraafatghazi/
# 💻 GitHub  : https://github.com/MahmoudRaafat-IT
# 
# ============================================================
Write-Host "=== Windows 11 Audio Driver Reset (Auto, No Prompts) ===" -ForegroundColor Cyan

# Temporarily suppress confirmation prompts
$oldConfirm = $ConfirmPreference
$ConfirmPreference = 'None'
$oldProgress = $ProgressPreference
$ProgressPreference = 'SilentlyContinue'

try {
    # Step 0: Confirm admin rights
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "❌ Please run this script as Administrator!" -ForegroundColor Red
        exit 1
    }

    # Step 1: Stop Audio Services
    Write-Host "`nStopping Windows Audio services..." -ForegroundColor Yellow
    $audioServices = @("Audiosrv", "AudioEndpointBuilder")
    foreach ($srv in $audioServices) {
        try {
            if (Get-Service -Name $srv -ErrorAction SilentlyContinue) {
                Stop-Service -Name $srv -Force -ErrorAction SilentlyContinue
                Write-Host "✔ Stopped: $srv" -ForegroundColor Green
            } else {
                Write-Host "→ Service not found or already stopped: $srv" -ForegroundColor DarkGray
            }
        } catch {
            Write-Host "⚠ Failed to stop: $srv ($($_.Exception.Message))" -ForegroundColor Red
        }
    }

    # Step 2: Detect all installed audio devices via WMI (Get-WmiObject)
    Write-Host "`nDetecting installed audio devices (via WMI)..." -ForegroundColor Yellow
    $audioDevices = Get-WmiObject Win32_SoundDevice -ErrorAction SilentlyContinue | Select-Object Name, Manufacturer, Status, DeviceID

    if (-not $audioDevices -or $audioDevices.Count -eq 0) {
        Write-Host "❌ No audio devices detected via WMI." -ForegroundColor Red
    } else {
        $audioDevices | Format-Table Name, Manufacturer, Status

        # Backup list to CSV (optional, safe)
        try {
            $backupPath = Join-Path -Path $env:SystemDrive -ChildPath "AudioDriversBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
            $audioDevices | Export-Csv -Path $backupPath -NoTypeInformation -Force
            Write-Host "✔ Backup exported to: $backupPath" -ForegroundColor Green
        } catch {
            Write-Host "⚠ Could not export backup CSV: $($_.Exception.Message)" -ForegroundColor DarkGray
        }

        # Step 3: Uninstall each device using DeviceID with pnputil (force)
        Write-Host "`nRemoving all detected audio devices..." -ForegroundColor Yellow
        foreach ($dev in $audioDevices) {
            try {
                $deviceId = $dev.DeviceID
                if ($deviceId) {
                    Write-Host "→ Removing: $($dev.Name) ($($dev.Manufacturer))" -ForegroundColor Cyan
                    # Use pnputil remove-device (no prompt)
                    pnputil /remove-device "$deviceId" 2>&1 | Out-Null
                    Start-Sleep -Seconds 1
                } else {
                    Write-Host "⚠ Device has no DeviceID: $($dev.Name)" -ForegroundColor Red
                }
            } catch {
                Write-Host "⚠ Failed to remove: $($dev.Name) — $($_.Exception.Message)" -ForegroundColor Red
            }
        }

        # Optional cleanup: remove old audio driver packages from driver store
        Write-Host "`nCleaning up old audio driver packages (DriverStore)..." -ForegroundColor Yellow
        try {
            $driverEnum = pnputil /enum-drivers 2>&1
            # find published names related to Audio (case-insensitive)
            $lines = $driverEnum -split "`r?`n"
            for ($i=0; $i -lt $lines.Length; $i++) {
                if ($lines[$i] -match 'Class Name\s*:\s*(.+)') {
                    $className = $matches[1]
                    if ($className -match '(?i)audio|sound|hd-audio|realtek|intel' ) {
                        # find Published Name in previous/following lines
                        $pubLine = ($lines[($i-1)..($i+1)] | Where-Object { $_ -match 'Published Name' })[0]
                        if ($pubLine -and $pubLine -match 'Published Name\s*:\s*(.+)') {
                            $driverName = $matches[1].Trim()
                            Write-Host "→ Deleting package: $driverName" -ForegroundColor DarkGray
                            pnputil /delete-driver $driverName /uninstall /force 2>&1 | Out-Null
                        }
                    }
                }
            }
        } catch {
            Write-Host "⚠ Error while cleaning driver store: $($_.Exception.Message)" -ForegroundColor DarkGray
        }
    }

    # Step 4: Rescan hardware (detect audio chip again)
    Write-Host "`nRescanning hardware for audio devices..." -ForegroundColor Yellow
    try {
        Start-Process -FilePath "pnputil.exe" -ArgumentList "/scan-devices" -Wait -NoNewWindow
        Write-Host "✔ Rescan requested." -ForegroundColor Green
    } catch {
        Write-Host "⚠ Failed to request rescan: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Step 5: Attempt driver installation via Windows Update with timeout fallback
    Write-Host "`nPreparing PSWindowsUpdate module (auto-install if missing)..." -ForegroundColor Yellow
    try {
        if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
            # Trust repository and install silently
            Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted -ErrorAction SilentlyContinue
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction SilentlyContinue | Out-Null
            Install-Module -Name PSWindowsUpdate -Force -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        }
        Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue
    } catch {
        Write-Host "⚠ Could not install/import PSWindowsUpdate: $($_.Exception.Message)" -ForegroundColor DarkGray
    }

    # Ensure Microsoft Update source is added without prompt
    try {
        Add-WUServiceManager -MicrosoftUpdate -ErrorAction SilentlyContinue -Confirm:$false | Out-Null
        Write-Host "✔ Microsoft Update source registered (or already present)." -ForegroundColor Green
    } catch {
        Write-Host "⚠ Add-WUServiceManager failed or required extra time: $($_.Exception.Message)" -ForegroundColor DarkGray
    }

    # Try to get driver updates but do it inside a job with timeout
    $timeoutSeconds = 60
    Write-Host "`nSearching Windows Update for driver updates (timeout ${timeoutSeconds}s)..." -ForegroundColor Yellow

    $updates = @()
    try {
        $job = Start-Job -ScriptBlock {
            param($ms)
            Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue
            # prefer drivers category and return list
            Get-WindowsUpdate -MicrosoftUpdate -Category Drivers -ErrorAction SilentlyContinue | Select-Object -Property Title, KB, MsrcSeverity
        } -ArgumentList $true

        $finished = Wait-Job -Job $job -Timeout $timeoutSeconds
        if ($finished) {
            $updates = Receive-Job -Job $job -ErrorAction SilentlyContinue
            Write-Host "✔ Windows Update query finished; updates found: $($updates.Count)" -ForegroundColor Green
        } else {
            Write-Host "⚠ Windows Update query timed out after ${timeoutSeconds}s — will fall back to generic driver installation." -ForegroundColor Yellow
            Stop-Job -Job $job -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Host "⚠ Error while querying Windows Update: $($_.Exception.Message)" -ForegroundColor DarkGray
    } finally {
        # cleanup jobs
        if ($job) { Remove-Job -Job $job -Force -ErrorAction SilentlyContinue }
    }

    # Filter for audio-related updates if any
    $audioUpdates = @()
    if ($updates -and $updates.Count -gt 0) {
        $audioUpdates = $updates | Where-Object { $_.Title -match '(?i)audio|realtek|intel|amd|nvidia|sound|hd-audio' }
    }

    if ($audioUpdates -and $audioUpdates.Count -gt 0) {
        Write-Host "`n🎧 Installing audio driver(s) from Windows Update (non-interactive)..." -ForegroundColor Yellow
        try {
            # Install-WindowsUpdate can accept -AcceptAll and -IgnoreReboot
            Install-WindowsUpdate -Updates $audioUpdates -AcceptAll -IgnoreReboot -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
            Write-Host "✔ Audio driver(s) installed from Windows Update." -ForegroundColor Green
        } catch {
            Write-Host "⚠ Failed to install audio updates from Windows Update: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "`n⚠ No audio-specific Windows Update found or timed out. Installing generic HD Audio driver..." -ForegroundColor Yellow
        try {
            # Install generic Microsoft HD Audio driver from INF (no prompt)
            $hdaInf = Join-Path -Path $env:SystemRoot -ChildPath "INF\hdaudio.inf"
            if (Test-Path $hdaInf) {
                Start-Process -FilePath "pnputil.exe" -ArgumentList "/add-driver `"$hdaInf`" /install /subdirs" -Wait -NoNewWindow
                Write-Host "✔ Attempted to add/install generic HD Audio driver." -ForegroundColor Green
            } else {
                Write-Host "⚠ Generic hdaudio.inf not found at $hdaInf. Skipping." -ForegroundColor Red
            }
        } catch {
            Write-Host "⚠ Error installing generic driver: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    # Step 6: Restart audio services
    Write-Host "`nRestarting audio services..." -ForegroundColor Yellow
    foreach ($srv in $audioServices) {
        try {
            Start-Service -Name $srv -ErrorAction SilentlyContinue
            Write-Host "✔ Started: $srv" -ForegroundColor Green
        } catch {
            Write-Host "⚠ Could not start: $srv — $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    # Step 7: Play test sound 3 times
    Write-Host "`n🔊 Playing test sound..." -ForegroundColor Cyan
    try {
        Add-Type -AssemblyName presentationCore
        for ($i = 1; $i -le 3; $i++) {
            [System.Media.SystemSounds]::Asterisk.Play()
            Write-Host "   ▶ Sound test $i of 3" -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
        Write-Host "🔈 Test sound played 3 times!" -ForegroundColor Green
    } catch {
        Write-Host "⚠ Could not play system sound: $($_.Exception.Message)" -ForegroundColor DarkGray
    }

    Write-Host "`n✅ All done! Recommended: restart your PC to complete driver installation." -ForegroundColor Cyan

} finally {
    # restore preferences
    $ConfirmPreference = $oldConfirm
    $ProgressPreference = $oldProgress
}
