using System;
using System.Diagnostics;
using System.Linq;
using System.Security.Principal;
using Microsoft.Win32;

namespace CutlineDnsInstaller
{
    class Program
    {
        private const string PrimaryDNS = "64.176.200.99";
        private const string SecondaryDNS = "149.28.79.49";
        private const string DoHTemplate = "https://dns.thecutline.org/dns-query";
        private const string DisplayName = "Cutline DNS";
        private const string TaskName = "CutlineDnsNetworkMonitor";
        
        private static bool _silentMode = false;

        static int Main(string[] args)
        {
            bool isUninstall = args.Any(a => 
                a.Equals("/uninstall", StringComparison.OrdinalIgnoreCase) ||
                a.Equals("-uninstall", StringComparison.OrdinalIgnoreCase) ||
                a.Equals("/u", StringComparison.OrdinalIgnoreCase));

            _silentMode = args.Any(a => 
                a.Equals("/silent", StringComparison.OrdinalIgnoreCase) ||
                a.Equals("-silent", StringComparison.OrdinalIgnoreCase) ||
                a.Equals("/s", StringComparison.OrdinalIgnoreCase));

            if (!IsAdministrator())
            {
                if (!_silentMode)
                {
                    Console.WriteLine("ERROR: This installer requires Administrator privileges.");
                    Console.WriteLine("Please run as Administrator.");
                    Console.ReadKey();
                }
                return 1;
            }

            try
            {
                if (isUninstall)
                {
                    Uninstall();
                }
                else
                {
                    Install();
                }
                return 0;
            }
            catch (Exception ex)
            {
                if (!_silentMode)
                {
                    Console.WriteLine($"\nERROR: {ex.Message}");
                    Console.WriteLine("\nPress any key to exit...");
                    Console.ReadKey();
                }
                return 1;
            }
        }

        static bool IsAdministrator()
        {
            try
            {
                WindowsIdentity identity = WindowsIdentity.GetCurrent();
                WindowsPrincipal principal = new WindowsPrincipal(identity);
                return principal.IsInRole(WindowsBuiltInRole.Administrator);
            }
            catch
            {
                return false;
            }
        }

        static void Install()
        {
            Console.WriteLine("Cutline DNS Setup");
            Console.WriteLine("=================\n");
            Console.WriteLine("Installing encrypted DNS for Windows...\n");

            var adapters = GetPhysicalNetworkAdapters();
            if (adapters.Count == 0)
            {
                Console.WriteLine("WARNING: No physical network adapters found.");
            }
            else
            {
                Console.WriteLine($"Found {adapters.Count} physical network adapter(s):\n");
                foreach (var adapter in adapters)
                {
                    Console.WriteLine($"  • {adapter}");
                }
                Console.WriteLine();

                Console.WriteLine("Configuring DNS on all adapters...");
                foreach (var adapter in adapters)
                {
                    SetDnsServers(adapter, PrimaryDNS, SecondaryDNS);
                    DisableIPv6(adapter);
                }
                Console.WriteLine("✓ DNS configured\n");
            }

            if (IsWindows11OrLater())
            {
                Console.WriteLine("Registering encrypted DNS (DoH) templates...");
                RegisterDoHTemplate(PrimaryDNS, DoHTemplate);
                RegisterDoHTemplate(SecondaryDNS, DoHTemplate);
                Console.WriteLine("✓ DoH templates registered\n");
            }
            else
            {
                Console.WriteLine("Windows 10 detected - DoH not available (DNS will work via port 53)\n");
            }

            Console.WriteLine("Flushing DNS cache...");
            FlushDnsCache();
            Console.WriteLine("✓ DNS cache flushed\n");

            Console.WriteLine("Installing network monitor task...");
            CreateScheduledTask();
            Console.WriteLine("✓ Task installed\n");

            Console.WriteLine("Registering in Programs and Features...");
            RegisterUninstaller();
            Console.WriteLine("✓ Registered\n");

            Console.WriteLine("========================================");
            Console.WriteLine("Installation complete!");
            Console.WriteLine("========================================\n");
            Console.WriteLine("Cutline DNS is now active on your system.");
            Console.WriteLine("New network adapters will be configured automatically.\n");
            Console.WriteLine("Verify at: https://thecutline.org/verify\n");
            Console.WriteLine("To uninstall:");
            Console.WriteLine("  • Settings → Apps → Cutline DNS → Uninstall");
            Console.WriteLine($"  • Or run: {GetExecutablePath()} /uninstall\n");
            
            if (!_silentMode)
            {
                Console.WriteLine("Press any key to exit...");
                Console.ReadKey();
            }
        }

        static void Uninstall()
        {
            Console.WriteLine("Cutline DNS Uninstaller");
            Console.WriteLine("=======================\n");
            Console.WriteLine("Removing Cutline DNS...\n");

            var adapters = GetPhysicalNetworkAdapters();
            if (adapters.Count > 0)
            {
                Console.WriteLine("Restoring DNS settings on all adapters...");
                foreach (var adapter in adapters)
                {
                    RestoreDnsServers(adapter);
                    EnableIPv6(adapter);
                }
                Console.WriteLine("✓ DNS restored to DHCP\n");
            }

            if (IsWindows11OrLater())
            {
                Console.WriteLine("Removing DoH templates...");
                RemoveDoHTemplate(PrimaryDNS);
                RemoveDoHTemplate(SecondaryDNS);
                Console.WriteLine("✓ DoH templates removed\n");
            }

            Console.WriteLine("Removing network monitor task...");
            RemoveScheduledTask();
            Console.WriteLine("✓ Task removed\n");

            Console.WriteLine("Flushing DNS cache...");
            FlushDnsCache();
            Console.WriteLine("✓ DNS cache flushed\n");

            Console.WriteLine("Unregistering from Programs and Features...");
            UnregisterUninstaller();
            Console.WriteLine("✓ Unregistered\n");

            Console.WriteLine("========================================");
            Console.WriteLine("Uninstallation complete!");
            Console.WriteLine("========================================\n");
            Console.WriteLine("Cutline DNS has been removed from your system.");
            Console.WriteLine("Your network settings have been restored.\n");
            
            if (!_silentMode)
            {
                Console.WriteLine("Press any key to exit...");
                Console.ReadKey();
            }
        }

        static System.Collections.Generic.List<string> GetPhysicalNetworkAdapters()
        {
            var result = new System.Collections.Generic.List<string>();
            
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
            catch (Exception ex)
            {
                Console.WriteLine($"Warning: Could not enumerate adapters: {ex.Message}");
            }

            return result;
        }

        static void SetDnsServers(string adapterName, string primary, string secondary)
        {
            try
            {
                RunPowerShell($"Set-DnsClientServerAddress -InterfaceAlias '{adapterName}' -ServerAddresses '{primary}','{secondary}'");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"  Warning: Could not set DNS for {adapterName}: {ex.Message}");
            }
        }

        static void RestoreDnsServers(string adapterName)
        {
            try
            {
                RunPowerShell($"Set-DnsClientServerAddress -InterfaceAlias '{adapterName}' -ResetServerAddresses");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"  Warning: Could not restore DNS for {adapterName}: {ex.Message}");
            }
        }

        static void DisableIPv6(string adapterName)
        {
            try
            {
                RunPowerShell($"Disable-NetAdapterBinding -Name '{adapterName}' -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue");
            }
            catch
            {
            }
        }

        static void EnableIPv6(string adapterName)
        {
            try
            {
                RunPowerShell($"Enable-NetAdapterBinding -Name '{adapterName}' -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue");
            }
            catch
            {
            }
        }

        static void RegisterDoHTemplate(string ipAddress, string template)
        {
            try
            {
                RunPowerShell($"Remove-DnsClientDohServerAddress -ServerAddress '{ipAddress}' -ErrorAction SilentlyContinue");
                RunPowerShell($"Add-DnsClientDohServerAddress -ServerAddress '{ipAddress}' -DohTemplate '{template}' -AllowFallbackToUdp $false -AutoUpgrade $true");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"  Warning: Could not register DoH for {ipAddress}: {ex.Message}");
            }
        }

        static void RemoveDoHTemplate(string ipAddress)
        {
            try
            {
                RunPowerShell($"Remove-DnsClientDohServerAddress -ServerAddress '{ipAddress}' -ErrorAction SilentlyContinue");
            }
            catch
            {
            }
        }

        static void FlushDnsCache()
        {
            try
            {
                RunPowerShell("Clear-DnsClientCache");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"  Warning: Could not flush DNS cache: {ex.Message}");
            }
        }

        static void CreateScheduledTask()
        {
            try
            {
                RemoveScheduledTask();
                
                string exePath = GetExecutablePath();
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

                string tempXml = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "cutline-task.xml");
                System.IO.File.WriteAllText(tempXml, xml);

                RunCommand("schtasks.exe", $"/Create /TN \"{TaskName}\" /XML \"{tempXml}\" /F");
                
                try { System.IO.File.Delete(tempXml); } catch { }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"  Warning: Could not create scheduled task: {ex.Message}");
            }
        }

        static void RemoveScheduledTask()
        {
            try
            {
                RunCommand("schtasks.exe", $"/Delete /TN \"{TaskName}\" /F", ignoreErrors: true);
            }
            catch
            {
            }
        }

        static void RegisterUninstaller()
        {
            try
            {
                string exePath = GetExecutablePath();
                string uninstallKey = @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\CutlineDNS";
                
                using (RegistryKey key = Registry.LocalMachine.CreateSubKey(uninstallKey))
                {
                    if (key != null)
                    {
                        key.SetValue("DisplayName", DisplayName);
                        key.SetValue("DisplayIcon", exePath);
                        key.SetValue("DisplayVersion", "1.0.0");
                        key.SetValue("Publisher", "The Cutline");
                        key.SetValue("InstallDate", DateTime.Now.ToString("yyyyMMdd"));
                        key.SetValue("UninstallString", $"\"{exePath}\" /uninstall");
                        key.SetValue("QuietUninstallString", $"\"{exePath}\" /uninstall");
                        key.SetValue("NoModify", 1, RegistryValueKind.DWord);
                        key.SetValue("NoRepair", 1, RegistryValueKind.DWord);
                        key.SetValue("EstimatedSize", 5000, RegistryValueKind.DWord);
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"  Warning: Could not register uninstaller: {ex.Message}");
            }
        }

        static void UnregisterUninstaller()
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

        static bool IsWindows11OrLater()
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

        static string GetExecutablePath()
        {
            return Process.GetCurrentProcess().MainModule?.FileName ?? 
                   AppContext.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar) + 
                   Path.DirectorySeparatorChar + "cutline-dns-setup.exe";
        }

        static void RunPowerShell(string command)
        {
            RunCommand("powershell.exe", $"-NoProfile -Command \"{command}\"");
        }

        static void RunCommand(string fileName, string arguments, bool ignoreErrors = false)
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
