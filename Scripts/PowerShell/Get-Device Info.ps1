# =========================================
# Full PowerShell Script: Complete Device Info
# Export to TXT with sizes in GB and Summary
# =========================================

$OutputPath = "$env:USERPROFILE\Desktop\DeviceInfo.txt"

function Write-Section {
    param($Title)
    "`n==================== $Title ====================" | Out-File -FilePath $OutputPath -Append
}

# Clear previous file if exists
if (Test-Path $OutputPath) { Remove-Item $OutputPath }

# --------------------------
# System Information
# --------------------------
Write-Section "System Information"
$sys = Get-CimInstance Win32_ComputerSystem
$memGB = [math]::Round($sys.TotalPhysicalMemory / 1GB, 2)
"Manufacturer : $($sys.Manufacturer)" | Out-File -FilePath $OutputPath -Append
"Model        : $($sys.Model)" | Out-File -FilePath $OutputPath -Append
"Name         : $($sys.Name)" | Out-File -FilePath $OutputPath -Append
"Domain       : $($sys.Domain)" | Out-File -FilePath $OutputPath -Append
"UserName     : $($sys.UserName)" | Out-File -FilePath $OutputPath -Append
"TotalMemory  : $memGB GB" | Out-File -FilePath $OutputPath -Append

# --------------------------
# Operating System
# --------------------------
Write-Section "Operating System"
$os = Get-CimInstance Win32_OperatingSystem
"Caption      : $($os.Caption)" | Out-File -FilePath $OutputPath -Append
"Version      : $($os.Version)" | Out-File -FilePath $OutputPath -Append
"BuildNumber  : $($os.BuildNumber)" | Out-File -FilePath $OutputPath -Append
"Architecture : $($os.OSArchitecture)" | Out-File -FilePath $OutputPath -Append
"SerialNumber : $($os.SerialNumber)" | Out-File -FilePath $OutputPath -Append
"InstallDate  : $([Management.ManagementDateTimeConverter]::ToDateTime($os.InstallDate))" | Out-File -FilePath $OutputPath -Append

# --------------------------
# BIOS
# --------------------------
Write-Section "BIOS"
$bios = Get-CimInstance Win32_BIOS
"Manufacturer : $($bios.Manufacturer)" | Out-File -FilePath $OutputPath -Append
"Name         : $($bios.Name)" | Out-File -FilePath $OutputPath -Append
"SerialNumber : $($bios.SerialNumber)" | Out-File -FilePath $OutputPath -Append
"ReleaseDate  : $($bios.ReleaseDate)" | Out-File -FilePath $OutputPath -Append
"SMBIOSVer    : $($bios.SMBIOSBIOSVersion)" | Out-File -FilePath $OutputPath -Append

# --------------------------
# CPU
# --------------------------
Write-Section "CPU"
$cpu = Get-CimInstance Win32_Processor
"Name                : $($cpu.Name)" | Out-File -FilePath $OutputPath -Append
"Manufacturer        : $($cpu.Manufacturer)" | Out-File -FilePath $OutputPath -Append
"MaxClockSpeed       : $($cpu.MaxClockSpeed) MHz" | Out-File -FilePath $OutputPath -Append
"Cores               : $($cpu.NumberOfCores)" | Out-File -FilePath $OutputPath -Append
"LogicalProcessors   : $($cpu.NumberOfLogicalProcessors)" | Out-File -FilePath $OutputPath -Append

# --------------------------
# Memory Modules
# --------------------------
Write-Section "Memory Modules"
$totalRAMGB = 0
$mems = Get-CimInstance Win32_PhysicalMemory
foreach ($m in $mems) {
    $sizeGB = [math]::Round($m.Capacity / 1GB, 2)
    $totalRAMGB += $sizeGB
    "Manufacturer: $($m.Manufacturer), PartNumber: $($m.PartNumber), Capacity: $sizeGB GB, Speed: $($m.Speed) MHz" | Out-File -FilePath $OutputPath -Append
}

# --------------------------
# Storage Drives
# --------------------------
Write-Section "Storage Drives"
$disks = Get-CimInstance Win32_DiskDrive
$diskCount = $disks.Count
$totalDiskGB = 0
$totalFreeGB = 0
"Number of Disks: $diskCount" | Out-File -FilePath $OutputPath -Append
foreach ($disk in $disks) {
    $sizeGB = [math]::Round($disk.Size / 1GB, 2)
    $totalDiskGB += $sizeGB
    "Model: $($disk.Model), Manufacturer: $($disk.Manufacturer), Size: $sizeGB GB, MediaType: $($disk.MediaType), Interface: $($disk.InterfaceType)" | Out-File -FilePath $OutputPath -Append
}

# --------------------------
# Disk Partitions
# --------------------------
Write-Section "Disk Partitions"
Get-CimInstance Win32_DiskPartition | Select-Object DiskIndex, Name, Type, Bootable, @{Name="Size(GB)";Expression={[math]::Round($_.Size/1GB,2)}} | Format-Table -AutoSize | Out-String | Out-File -FilePath $OutputPath -Append

# --------------------------
# Volumes
# --------------------------
Write-Section "Volumes"
$volumes = Get-CimInstance Win32_Volume | Where-Object {$_.DriveType -ne 5} # ignore CD-ROM
$volumeTable = $volumes | Select-Object DriveLetter, Label, FileSystem, @{Name="Capacity(GB)";Expression={[math]::Round($_.Capacity/1GB,2)}}, @{Name="FreeSpace(GB)";Expression={[math]::Round($_.FreeSpace/1GB,2)}}
$volumeTable | Format-Table -AutoSize | Out-String | Out-File -FilePath $OutputPath -Append

# Calculate total free space
foreach ($v in $volumes) {
    $totalFreeGB += [math]::Round($v.FreeSpace /1GB,2)
}

# --------------------------
# Network Adapters
# --------------------------
Write-Section "Network Adapters"
Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object {$_.IPEnabled -eq $true} | Select-Object Description, MACAddress, @{Name="IPAddresses";Expression={$_.IPAddress -join ", "}}, @{Name="Gateway";Expression={$_.DefaultIPGateway -join ", "}}, @{Name="DNS";Expression={$_.DNSServerSearchOrder -join ", "}} | Format-Table -AutoSize | Out-String | Out-File -FilePath $OutputPath -Append

# --------------------------
# Video/Graphics
# --------------------------
Write-Section "Video/Graphics"
Get-CimInstance Win32_VideoController | Select-Object Name, @{Name="RAM(GB)";Expression={[math]::Round($_.AdapterRAM/1GB,2)}}, DriverVersion, VideoModeDescription | Format-Table -AutoSize | Out-String | Out-File -FilePath $OutputPath -Append

# --------------------------
# Audio Devices
# --------------------------
Write-Section "Audio Devices"
Get-CimInstance Win32_SoundDevice | Select-Object Name, Manufacturer, Status | Format-Table -AutoSize | Out-String | Out-File -FilePath $OutputPath -Append

# --------------------------
# Summary
# --------------------------
Write-Section "Summary"
"Total Installed RAM  : $totalRAMGB GB" | Out-File -FilePath $OutputPath -Append
"Total Disks          : $diskCount" | Out-File -FilePath $OutputPath -Append
"Total Disk Capacity  : $totalDiskGB GB" | Out-File -FilePath $OutputPath -Append
"Total Free Disk Space: $totalFreeGB GB" | Out-File -FilePath $OutputPath -Append

Write-Host "Full device information with summary exported to: $OutputPath"
