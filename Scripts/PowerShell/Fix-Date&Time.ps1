<#
.SYNOPSIS
  Detects the Domain Controller and syncs time with it (net time + w32tm).

.NOTES
  Save this file as Sync-Time-With-DC.ps1
  Run as "Run as Administrator"
#>

param(
    [string] $DomainName = $env:USERDNSDOMAIN,    # Automatically uses the machine's domain if available
    [switch] $UsePdcAsPeer                        # If you want to force using PDC as a peer
)

function Write-Log {
    param($msg) 
    $t = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    Write-Host "[$t] $msg"
}

# Check for administrator privileges
if (-not ([bool]([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))) {
    Write-Host "Please run the script with administrator privileges (Run as Administrator)." -ForegroundColor Red
    exit 1
}

if (-not $DomainName) {
    Write-Log "No domain specified and no domain found for this machine."
    exit 1
}

Write-Log "Attempting to find a Domain Controller for domain: $DomainName"

$dcHost = $null

# Method 1: Try using ActiveDirectory module (Get-ADDomainController)
try {
    if (Get-Command Get-ADDomainController -ErrorAction SilentlyContinue) {
        Write-Log "Using Get-ADDomainController..."
        $adc = Get-ADDomainController -DomainName $DomainName -Discover -ErrorAction Stop
        if ($adc) { $dcHost = $adc.HostName }
    }
} catch {
    Write-Log "Get-ADDomainController is not available or failed."
}

# Method 2: Use .NET AD API to get PDC (as an alternative)
if (-not $dcHost) {
    try {
        Write-Log "Trying System.DirectoryServices.ActiveDirectory to get PDC..."
        $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
        $pdc = $domain.PdcRoleOwner
        if ($pdc -and $pdc.Name) {
            $dcHost = $pdc.Name
        }
    } catch {
        Write-Log "Failed using System.DirectoryServices.ActiveDirectory."
    }
}

# Method 3: nltest as a fallback
if (-not $dcHost) {
    try {
        Write-Log "Trying nltest /dsgetdc:$DomainName ..."
        $out = nltest /dsgetdc:$DomainName 2>&1
        # Search for the line containing DC Name
        foreach ($line in $out) {
            if ($line -match "DC: (.+?) ") {
                $dcHost = $Matches[1].Trim()
                break
            }
            if ($line -match "DC: (.+?)$") {
                $dcHost = $Matches[1].Trim()
                break
            }
            if ($line -match "DC: (.+?)\\") {
                $dcHost = $Matches[1].Trim()
                break
            }
        }
    } catch {
        Write-Log "nltest did not return a useful result."
    }
}

if (-not $dcHost) {
    Write-Log "Failed to automatically find the DC hostname."
    exit 1
}

Write-Log "DC hostname found: $dcHost"

# Convert hostname to IP (prefer IPv4)
$dcIP = $null
try {
    $addrs = [System.Net.Dns]::GetHostAddresses($dcHost) | Where-Object { $_.AddressFamily -eq 'InterNetwork' }
    if ($addrs -and $addrs.Count -gt 0) {
        $dcIP = $addrs[0].IPAddressToString
    } else {
        # If no IPv4, take any address
        $addrAny = [System.Net.Dns]::GetHostAddresses($dcHost) | Select-Object -First 1
        if ($addrAny) { $dcIP = $addrAny.IPAddressToString }
    }
} catch {
    Write-Log "Failed to resolve DC hostname to IP: $_"
}

if (-not $dcIP) {
    Write-Log "Could not get IP for the DC ($dcHost)."
    exit 1
}

Write-Log "DC IP address is: $dcIP"

# If user wants to use PDC as peer, set manualpeerlist to PDC IP
if ($UsePdcAsPeer) {
    Write-Log "UsePdcAsPeer option enabled — will use this DC as manualpeerlist."
}

# Execute synchronization commands
Write-Log "Running: net time \\$dcIP /set /yes"
try {
    $nettimeOut = net time "\\$dcIP" /set /yes 2>&1
    Write-Host $nettimeOut
} catch {
    Write-Log "net time command failed: $_"
}

# Configure w32tm to use the DC as NTP peer and resync
Write-Log "Configuring w32tm to use $dcIP as manualpeerlist and resyncing"
try {
    # Set manualpeerlist and update configuration
    & w32tm /config /manualpeerlist:"$dcIP" /syncfromflags:manual /reliable:yes /update 2>&1 | ForEach-Object { Write-Host $_ }
    # Immediate resync
    & w32tm /resync /nowait 2>&1 | ForEach-Object { Write-Host $_ }
    Write-Log "Resync requested."
} catch {
    Write-Log "Failed to run w32tm or resync: $_"
}

Write-Log "Script execution finished."
