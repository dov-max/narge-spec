# Cutline DNS Setup for Windows
# Configures encrypted DNS over HTTPS (DoH) for Cutline resolvers
# Run in Administrator PowerShell

param(
    [switch]$Revert,
    [switch]$KeepIPv6
)

$DoHTemplate = "https://dns.thecutline.org/dns-query"
$PrimaryDNS = "64.176.200.99"
$SecondaryDNS = "149.28.79.49"

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Host "ERROR: This script requires Administrator privileges." -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator', then run this script again." -ForegroundColor Yellow
    exit 1
}

if ($Revert) {
    Write-Host "Reverting DNS settings to automatic..." -ForegroundColor Yellow
    
    # Remove DoH templates
    $existingTemplates = Get-DnsClientDohServerAddress | Where-Object { $_.ServerAddress -in @($PrimaryDNS, $SecondaryDNS) }
    foreach ($template in $existingTemplates) {
        Remove-DnsClientDohServerAddress -ServerAddress $template.ServerAddress -ErrorAction SilentlyContinue
        Write-Host "Removed DoH template for $($template.ServerAddress)" -ForegroundColor Gray
    }
    
    # Reset DNS to automatic for all adapters
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
    foreach ($adapter in $adapters) {
        Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ResetServerAddresses
        Write-Host "Reset DNS for adapter: $($adapter.Name)" -ForegroundColor Gray
    }
    
    Write-Host "DNS settings reverted to automatic." -ForegroundColor Green
    Write-Host "You may need to restart your computer or network adapter for changes to take effect." -ForegroundColor Cyan
    exit 0
}

Write-Host "Cutline DNS Setup for Windows" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""

# Register DoH templates
Write-Host "Registering DoH templates..." -ForegroundColor Yellow

foreach ($ip in @($PrimaryDNS, $SecondaryDNS)) {
    $existing = Get-DnsClientDohServerAddress -ServerAddress $ip -ErrorAction SilentlyContinue
    if ($existing) {
        Remove-DnsClientDohServerAddress -ServerAddress $ip -ErrorAction SilentlyContinue
    }
    Add-DnsClientDohServerAddress -ServerAddress $ip -DohTemplate $DoHTemplate -AllowFallbackToUdp $false -AutoUpgrade $true
    Write-Host "  Registered DoH for $ip" -ForegroundColor Green
}

# Configure network adapters
Write-Host ""
Write-Host "Configuring network adapters..." -ForegroundColor Yellow

$adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
if ($adapters.Count -eq 0) {
    Write-Host "ERROR: No active network adapters found." -ForegroundColor Red
    exit 1
}

foreach ($adapter in $adapters) {
    Write-Host "  Configuring adapter: $($adapter.Name)" -ForegroundColor Gray
    
    # Set DNS servers
    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses @($PrimaryDNS, $SecondaryDNS)
    
    # Disable IPv6 DNS unless -KeepIPv6 is specified
    if (-not $KeepIPv6) {
        # Clear IPv6 DNS servers to prevent leaks
        Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses @() -AddressFamily IPv6 -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Cutline DNS is now configured with encrypted DNS over HTTPS." -ForegroundColor Cyan
Write-Host ""
Write-Host "IMPORTANT NOTES:" -ForegroundColor Yellow
Write-Host "  - DoH requires Windows 10 version 19628+ or Windows 11" -ForegroundColor White
Write-Host "  - IPv6 DNS bindings have been cleared to prevent leaks" -ForegroundColor White
if (-not $KeepIPv6) {
    Write-Host "    (Use -KeepIPv6 flag if you need IPv6 DNS)" -ForegroundColor Gray
}
Write-Host "  - Chrome/Edge have separate 'Secure DNS' settings that may override system DNS" -ForegroundColor White
Write-Host "    To use system DNS in Chrome/Edge: Settings > Privacy > Security > Use secure DNS" -ForegroundColor Gray
Write-Host "    Set to 'With your current service provider' or use: $DoHTemplate" -ForegroundColor Gray
Write-Host ""
Write-Host "Verify setup at: https://thecutline.org/verify" -ForegroundColor Cyan
Write-Host ""
Write-Host "To revert: Run this script with -Revert flag" -ForegroundColor Gray
