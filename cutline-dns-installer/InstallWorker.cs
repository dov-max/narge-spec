using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using Microsoft.Win32;

namespace CutlineDnsInstaller
{
    public class InstallWorker
    {
        private const string PrimaryDNS = "64.176.200.99";
        private const string SecondaryDNS = "149.28.79.49";
        private const string DoHTemplate = "https://dns.thecutline.org/dns-query";
        private const string DisplayName = "Cutline DNS";
        private const string TaskName = "CutlineDnsNetworkMonitor";
        private const string InstallPath = @"C:\Program Files\Cutline DNS";
        private const string InstalledExeName = "cutline-dns-setup.exe";

        public void Install(Action<string> log)
        {
            log("Installing Cutline DNS...");
            log("");

            string installedExePath = Path.Combine(InstallPath, InstalledExeName);
            string currentExePath = GetCurrentExecutablePath();
            
            if (!File.Exists(installedExePath) || !string.Equals(Path.GetFullPath(currentExePath), Path.GetFullPath(installedExePath), StringComparison.OrdinalIgnoreCase))
            {
                log($"Installing to {InstallPath}...");
                Directory.CreateDirectory(InstallPath);
                File.Copy(currentExePath, installedExePath, true);
                log("✓ Installed");
                log("");
            }

            var adapters = GetPhysicalNetworkAdapters();
            if (adapters.Count == 0)
            {
                log("WARNING: No physical network adapters found.");
                log("");
            }
            else
            {
                log($"Found {adapters.Count} physical network adapter(s):");
                foreach (var adapter in adapters)
                {
                    log($"  • {adapter}");
                }
                log("");

                log("Configuring DNS on all adapters...");
                foreach (var adapter in adapters)
                {
                    SetDnsServers(adapter, PrimaryDNS, SecondaryDNS);
                    DisableIPv6(adapter);
                }
                log("✓ DNS configured");
                log("");
            }

            if (IsWindows11OrLater())
            {
                log("Registering encrypted DNS (DoH) templates...");
                RegisterDoHTemplate(PrimaryDNS, DoHTemplate, adapters);
                RegisterDoHTemplate(SecondaryDNS, DoHTemplate, adapters);
                log("✓ DoH templates registered");
                log("");
            }
            else
            {
                log("Windows 10 detected - DoH not available (DNS will work via port 53)");
                log("");
            }

            log("Flushing DNS cache...");
            FlushDnsCache();
            log("✓ DNS cache flushed");
            log("");

            log("Installing network monitor task...");
            CreateScheduledTask();
            log("✓ Task installed");
            log("");

            log("Registering in Programs and Features...");
            RegisterUninstaller();
            log("✓ Registered");
            log("");
        }

        public void Uninstall(Action<string> log)
        {
            log("Removing Cutline DNS...");
            log("");

            var adapters = GetPhysicalNetworkAdapters();
            if (adapters.Count > 0)
            {
                log("Restoring DNS settings on all adapters...");
                foreach (var adapter in adapters)
                {
                    RestoreDnsServers(adapter);
                    EnableIPv6(adapter);
                }
                log("✓ DNS restored to DHCP");
                log("");
            }

            if (IsWindows11OrLater())
            {
                log("Removing DoH templates...");
                RemoveDoHTemplate(PrimaryDNS, adapters);
                RemoveDoHTemplate(SecondaryDNS, adapters);
                log("✓ DoH templates removed");
                log("");
            }

            log("Removing network monitor task...");
            RemoveScheduledTask();
            log("✓ Task removed");
            log("");

            log("Flushing DNS cache...");
            FlushDnsCache();
            log("✓ DNS cache flushed");
            log("");

            log("Unregistering from Programs and Features...");
            UnregisterUninstaller();
            log("✓ Unregistered");
            log("");

            try
            {
                string installedExePath = GetInstalledExecutablePath();
                if (File.Exists(installedExePath))
                {
                    string currentExe = GetCurrentExecutablePath();
                    if (string.Equals(Path.GetFullPath(currentExe), Path.GetFullPath(installedExePath), StringComparison.OrdinalIgnoreCase))
                    {
                        log("Scheduling file removal on next reboot...");
                        RunCommand("cmd.exe", $"/c timeout /t 2 /nobreak > nul && rd /s /q \"{InstallPath}\"", ignoreErrors: true);
                    }
                    else
                    {
                        log("Removing installation files...");
                        Directory.Delete(InstallPath, true);
                        log("✓ Files removed");
                        log("");
                    }
                }
            }
            catch (Exception ex)
            {
                log($"Note: Could not remove installation files: {ex.Message}");
            }
        }

        private List<string> GetPhysicalNetworkAdapters()
        {
            var result = new List<string>();
            
            try
            {
                var psi = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = "-NoProfile -Command \"Get-NetAdapter | Where-Object { " +
                               "$_.InterfaceDescription -notlike '*Loopback*' -and " +
                               "$_.InterfaceDescription -notlike '*Hyper-V*' -and " +
                               "$_.InterfaceDescription -notlike '*vEthernet*' -and " +
                               "$_.InterfaceDescription -notlike '*WSL*' -and " +
                               "$_.InterfaceDescription -notlike '*Bluetooth*' -and " +
                               "$_.InterfaceDescription -notlike '*ISATAP*' -and " +
                               "$_.InterfaceDescription -notlike '*Teredo*' -and " +
                               "$_.InterfaceDescription -notlike '*VPN*' -and " +
                               "$_.InterfaceDescription -notlike '*TAP*' -and " +
                               "$_.InterfaceDescription -notlike '*WireGuard*' -and " +
                               "$_.InterfaceDescription -notlike '*OpenVPN*' -and " +
                               "($_.MediaType -eq 'Native 802.11' -or $_.MediaType -eq '802.3' -or $_.InterfaceDescription -like '*WWAN*' -or $_.InterfaceDescription -like '*Mobile*' -or $_.InterfaceDescription -like '*Cellular*') " +
                               "} | Select-Object -ExpandProperty Name\"",
                    RedirectStandardOutput = true,
                    UseShellExecute = false,
                    CreateNoWindow = true
                };

                using (var process = Process.Start(psi))
                {
                    if (process != null)
                    {
                        string output = process.StandardOutput.ReadToEnd();
                        process.WaitForExit();
                        
                        var lines = output.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);
                        result.AddRange(lines.Select(l => l.Trim()).Where(l => !string.IsNullOrWhiteSpace(l)));
                    }
                }
            }
            catch
            {
            }

            return result;
        }

        private void SetDnsServers(string adapterName, string primary, string secondary)
        {
            try
            {
                RunPowerShell($"Set-DnsClientServerAddress -InterfaceAlias '{adapterName}' -ServerAddresses '{primary}','{secondary}'");
            }
            catch
            {
            }
        }

        private void RestoreDnsServers(string adapterName)
        {
            try
            {
                RunPowerShell($"Set-DnsClientServerAddress -InterfaceAlias '{adapterName}' -ResetServerAddresses");
            }
            catch
            {
            }
        }

        private void DisableIPv6(string adapterName)
        {
            try
            {
                RunPowerShell($"Disable-NetAdapterBinding -Name '{adapterName}' -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue");
            }
            catch
            {
            }
        }

        private void EnableIPv6(string adapterName)
        {
            try
            {
                RunPowerShell($"Enable-NetAdapterBinding -Name '{adapterName}' -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue");
            }
            catch
            {
            }
        }

        private void RegisterDoHTemplate(string ipAddress, string template, List<string> adapters)
        {
            try
            {
                RunPowerShell($"Remove-DnsClientDohServerAddress -ServerAddress '{ipAddress}' -ErrorAction SilentlyContinue");
                RunPowerShell($"Add-DnsClientDohServerAddress -ServerAddress '{ipAddress}' -DohTemplate '{template}' -AllowFallbackToUdp $false -AutoUpgrade $true");
                
                foreach (var adapter in adapters)
                {
                    try
                    {
                        RunPowerShell($"Set-DnsClientServerAddress -InterfaceAlias '{adapter}' -ServerAddresses '{ipAddress}' -DohFlags 2 -ErrorAction SilentlyContinue");
                    }
                    catch
                    {
                    }
                }
            }
            catch
            {
            }
        }

        private void RemoveDoHTemplate(string ipAddress, List<string> adapters)
        {
            try
            {
                RunPowerShell($"Remove-DnsClientDohServerAddress -ServerAddress '{ipAddress}' -ErrorAction SilentlyContinue");
                
                foreach (var adapter in adapters)
                {
                    try
                    {
                        RunPowerShell($"Set-DnsClientServerAddress -InterfaceAlias '{adapter}' -ResetServerAddresses -ErrorAction SilentlyContinue");
                    }
                    catch
                    {
                    }
                }
            }
            catch
            {
            }
        }

        private void FlushDnsCache()
        {
            try
            {
                RunPowerShell("Clear-DnsClientCache");
            }
            catch
            {
            }
        }

        private void CreateScheduledTask()
        {
            try
            {
                RemoveScheduledTask();
                
                string exePath = GetInstalledExecutablePath();
                string xml = $@"<?xml version=""1.0"" encoding=""UTF-16""?>
<Task version=""1.2"" xmlns=""http://schemas.microsoft.com/windows/2004/02/mit/task"">
  <RegistrationInfo>
    <Description>Automatically configure Cutline DNS on new network adapters</Description>
  </RegistrationInfo>
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
    </LogonTrigger>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id=""0"" Path=""Microsoft-Windows-NetworkProfile/Operational""&gt;&lt;Select Path=""Microsoft-Windows-NetworkProfile/Operational""&gt;*[System[EventID=10000]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal>
      <UserId>S-1-5-18</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT5M</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions>
    <Exec>
      <Command>{exePath}</Command>
      <Arguments>/silent</Arguments>
    </Exec>
  </Actions>
</Task>";

                string tempXml = Path.Combine(Path.GetTempPath(), "cutline-task.xml");
                File.WriteAllText(tempXml, xml);

                RunCommand("schtasks.exe", $"/Create /TN \"{TaskName}\" /XML \"{tempXml}\" /F");
                
                try { File.Delete(tempXml); } catch { }
            }
            catch
            {
            }
        }

        private void RemoveScheduledTask()
        {
            try
            {
                RunCommand("schtasks.exe", $"/Delete /TN \"{TaskName}\" /F", ignoreErrors: true);
            }
            catch
            {
            }
        }

        private void RegisterUninstaller()
        {
            try
            {
                string exePath = GetInstalledExecutablePath();
                string uninstallKey = @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\CutlineDNS";
                
                using (RegistryKey key = Registry.LocalMachine.CreateSubKey(uninstallKey))
                {
                    if (key != null)
                    {
                        key.SetValue("DisplayName", DisplayName);
                        key.SetValue("DisplayIcon", exePath);
                        key.SetValue("DisplayVersion", "1.0.0");
                        key.SetValue("Publisher", "Optivantage Solutions LLC");
                        key.SetValue("InstallDate", DateTime.Now.ToString("yyyyMMdd"));
                        key.SetValue("UninstallString", $"\"{exePath}\" /uninstall");
                        key.SetValue("QuietUninstallString", $"\"{exePath}\" /uninstall");
                        key.SetValue("NoModify", 1, RegistryValueKind.DWord);
                        key.SetValue("NoRepair", 1, RegistryValueKind.DWord);
                        key.SetValue("EstimatedSize", 5000, RegistryValueKind.DWord);
                    }
                }
            }
            catch
            {
            }
        }

        private void UnregisterUninstaller()
        {
            try
            {
                string uninstallKey = @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\CutlineDNS";
                Registry.LocalMachine.DeleteSubKey(uninstallKey, false);
            }
            catch
            {
            }
        }

        private bool IsWindows11OrLater()
        {
            try
            {
                var version = Environment.OSVersion.Version;
                return version.Major >= 10 && version.Build >= 22000;
            }
            catch
            {
                return false;
            }
        }

        private string GetCurrentExecutablePath()
        {
            return Process.GetCurrentProcess().MainModule?.FileName ?? 
                   AppContext.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar) + 
                   Path.DirectorySeparatorChar + InstalledExeName;
        }

        private string GetInstalledExecutablePath()
        {
            return Path.Combine(InstallPath, InstalledExeName);
        }

        private void RunPowerShell(string command)
        {
            RunCommand("powershell.exe", $"-NoProfile -Command \"{command}\"");
        }

        private void RunCommand(string fileName, string arguments, bool ignoreErrors = false)
        {
            var psi = new ProcessStartInfo
            {
                FileName = fileName,
                Arguments = arguments,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            using (var process = Process.Start(psi))
            {
                if (process != null)
                {
                    process.WaitForExit();
                    if (!ignoreErrors && process.ExitCode != 0)
                    {
                        string error = process.StandardError.ReadToEnd();
                        if (!string.IsNullOrWhiteSpace(error))
                        {
                            throw new Exception($"Command failed: {error}");
                        }
                    }
                }
            }
        }
    }
}
