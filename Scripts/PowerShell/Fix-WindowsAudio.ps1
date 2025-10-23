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

Write-Host "=== Windows 11 Audio Driver Reset ===" -ForegroundColor Cyan

# Step 0: Confirm admin rights
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "❌ Please run this script as Administrator!" -ForegroundColor Red
    exit
}

# Step 1: Stop Audio Services
Write-Host "`nStopping Windows Audio services..." -ForegroundColor Yellow
$audioServices = @("Audiosrv", "AudioEndpointBuilder")
foreach ($srv in $audioServices) {
    try {
        Stop-Service -Name $srv -Force -ErrorAction SilentlyContinue
        Write-Host "✔ Stopped: $srv" -ForegroundColor Green
    } catch {
        Write-Host "⚠ Failed to stop: $srv" -ForegroundColor Red
    }
}

# Step 2: Enumerate all audio-related devices
Write-Host "`nDetecting installed audio devices..." -ForegroundColor Yellow
$audioDevices = Get-PnpDevice -Class "Sound,VideoAndGameController"

if (-not $audioDevices) {
    Write-Host "❌ No audio devices detected. Skipping uninstall." -ForegroundColor Red
} else {
    $audioDevices | Format-Table FriendlyName, InstanceId

    # Step 3: Uninstall all detected audio drivers
    Write-Host "`nRemoving all existing audio drivers..." -ForegroundColor Yellow
    foreach ($dev in $audioDevices) {
        try {
            Write-Host "→ Removing: $($dev.FriendlyName)" -ForegroundColor Cyan
            pnputil /remove-device "$($dev.InstanceId)" | Out-Null
            Start-Sleep -Seconds 1
        } catch {
            Write-Host "⚠ Failed to remove $($dev.FriendlyName)" -ForegroundColor Red
        }
    }

    # Optional: Also remove unused driver packages from DriverStore
    Write-Host "`nCleaning up old audio driver packages..." -ForegroundColor Yellow
    $audioDrivers = pnputil /enum-drivers | Select-String -Pattern "Published Name|Class Name" -Context 0,1 | 
        Where-Object { $_.Context.PostContext -match "Audio" }

    foreach ($entry in $audioDrivers) {
        $driverName = ($entry.ToString() -split ':')[1].Trim()
        Write-Host "→ Deleting package: $driverName" -ForegroundColor DarkGray
        pnputil /delete-driver $driverName /uninstall /force | Out-Null
    }
}

# Step 4: Rescan hardware (detect audio chip again)
Write-Host "`nRescanning hardware for audio devices..." -ForegroundColor Yellow
Start-Process -FilePath "pnputil.exe" -ArgumentList "/scan-devices" -Wait

# Step 5: Attempt driver installation via Windows Update
Write-Host "`nChecking Windows Update for fresh audio drivers..." -ForegroundColor Yellow
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
    Install-Module -Name PSWindowsUpdate -Force -Confirm:$false
}
Import-Module PSWindowsUpdate
Add-WUServiceManager -MicrosoftUpdate -ErrorAction SilentlyContinue | Out-Null

$updates = Get-WindowsUpdate -MicrosoftUpdate -Category Drivers -IgnoreUserInput -ErrorAction SilentlyContinue
$audioUpdates = $updates | Where-Object { $_.Title -match "audio|realtek|intel|amd|nvidia" }

if ($audioUpdates) {
    Write-Host "`n🎧 Installing new audio drivers from Windows Update..." -ForegroundColor Yellow
    Install-WindowsUpdate -Updates $audioUpdates -AcceptAll -IgnoreReboot
    Write-Host "✔ Audio driver(s) installed successfully." -ForegroundColor Green
} else {
    Write-Host "`n⚠ No specific audio driver found. Installing generic HD Audio driver..." -ForegroundColor Yellow
    Start-Process -FilePath "pnputil.exe" -ArgumentList "/add-driver %SystemRoot%\INF\hdaudio.inf /install" -Wait
}

# Step 6: Restart audio services
Write-Host "`nRestarting audio services..." -ForegroundColor Yellow
foreach ($srv in $audioServices) {
    try {
        Start-Service -Name $srv -ErrorAction SilentlyContinue
        Write-Host "✔ Started: $srv" -ForegroundColor Green
    } catch {
        Write-Host "⚠ Could not start: $srv" -ForegroundColor Red
    }
}

# Step 8: Play test sound 3 times to confirm audio output
Write-Host "`n🔊 Playing test sound..." -ForegroundColor Cyan
Add-Type -AssemblyName presentationCore

for ($i = 1; $i -le 3; $i++) {
    [System.Media.SystemSounds]::Asterisk.Play()
    Write-Host "   ▶ Sound test $i of 3" -ForegroundColor Yellow
    Start-Sleep -Seconds 1
}

Write-Host "🔈 Test sound played 3 times! If you heard tones, the driver installation succeeded!" -ForegroundColor Green

Write-Host "`n✅ All done! Please restart your PC and test your sound." -ForegroundColor Cyan
