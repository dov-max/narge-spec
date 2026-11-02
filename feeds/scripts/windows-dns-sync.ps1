# Narge Windows Server DNS Sync
# 
# Syncs the Narge domain list to Windows Server DNS Query Resolution Policies.
# Runs idempotently - safe to run on a schedule (e.g., daily task).
#
# Requirements:
#   - Windows Server 2016 or later
#   - DNS Server role installed
#   - Run as Administrator
#
# Usage:
#   .\windows-dns-sync.ps1 -Install
#   .\windows-dns-sync.ps1 -Uninstall
#
# Environment variables (optional):
#   $env:NARGE_FEED_URL - Custom feed URL (defaults to public feed)

param(
    [switch]$Install,
    [switch]$Uninstall
)

$FEED_URL = if ($env:NARGE_FEED_URL) { $env:NARGE_FEED_URL } else { "https://feeds.thecutline.org/v1/narge-plain-nocomments.txt" }
$POLICY_PREFIX = "Narge-Block-"

function Install-NargeBlocks {
    Write-Host "Fetching Narge domain list from $FEED_URL..."
    
    try {
        $domains = (Invoke-WebRequest -Uri $FEED_URL -UseBasicParsing).Content -split "`n" | Where-Object { $_ -match '\S' }
        Write-Host "Fetched $($domains.Count) domains"
    }
    catch {
        Write-Error "Failed to fetch Narge list: $_"
        exit 1
    }
    
    # Remove old policies
    Write-Host "Removing old Narge policies..."
    Get-DnsServerQueryResolutionPolicy | Where-Object { $_.Name -like "${POLICY_PREFIX}*" } | ForEach-Object {
        Remove-DnsServerQueryResolutionPolicy -Name $_.Name -Force
    }
    
    # Add new policies
    Write-Host "Adding Query Resolution Policies..."
    $count = 0
    foreach ($domain in $domains) {
        $domain = $domain.Trim()
        if ($domain -and -not $domain.StartsWith("#")) {
            $policyName = "${POLICY_PREFIX}${count}"
            try {
                Add-DnsServerQueryResolutionPolicy `
                    -Name $policyName `
                    -Action IGNORE `
                    -FQDN "EQ,$domain,*.$domain" `
                    -PassThru | Out-Null
                $count++
            }
            catch {
                Write-Warning "Failed to add policy for ${domain}: $_"
            }
        }
    }
    
    Write-Host "Added $count Query Resolution Policies"
    Write-Host "Narge blocks installed successfully"
}

function Uninstall-NargeBlocks {
    Write-Host "Removing all Narge Query Resolution Policies..."
    
    $policies = Get-DnsServerQueryResolutionPolicy | Where-Object { $_.Name -like "${POLICY_PREFIX}*" }
    $count = $policies.Count
    
    $policies | ForEach-Object {
        Remove-DnsServerQueryResolutionPolicy -Name $_.Name -Force
    }
    
    Write-Host "Removed $count Narge policies"
    Write-Host "Narge blocks uninstalled successfully"
}

# Main
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

if ($Install) {
    Install-NargeBlocks
}
elseif ($Uninstall) {
    Uninstall-NargeBlocks
}
else {
    Write-Host "Usage: .\windows-dns-sync.ps1 -Install | -Uninstall"
    exit 1
}
