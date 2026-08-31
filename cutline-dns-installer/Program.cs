using System;
using System.Linq;
using System.Security.Principal;
using System.Windows.Forms;

namespace CutlineDnsInstaller
{
    class Program
    {
        [STAThread]
        static int Main(string[] args)
        {
            bool isUninstall = args.Any(a => 
                a.Equals("/uninstall", StringComparison.OrdinalIgnoreCase) ||
                a.Equals("-uninstall", StringComparison.OrdinalIgnoreCase) ||
                a.Equals("/u", StringComparison.OrdinalIgnoreCase));

            bool silentMode = args.Any(a => 
                a.Equals("/silent", StringComparison.OrdinalIgnoreCase) ||
                a.Equals("-silent", StringComparison.OrdinalIgnoreCase) ||
                a.Equals("/s", StringComparison.OrdinalIgnoreCase));

            if (!IsAdministrator())
            {
                if (!silentMode)
                {
                    MessageBox.Show(
                        "This installer requires Administrator privileges.\n\nPlease run as Administrator.",
                        "Administrator Required",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Error);
                }
                return 1;
            }

            if (silentMode)
            {
                return RunSilent(isUninstall);
            }

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            
            try
            {
                using (var wizard = new WizardForm(isUninstall))
                {
                    Application.Run(wizard);
                }
                return 0;
            }
            catch (Exception ex)
            {
                MessageBox.Show(
                    $"An error occurred:\n\n{ex.Message}",
                    "Error",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);
                return 1;
            }
        }

        static int RunSilent(bool isUninstall)
        {
            try
            {
                var worker = new InstallWorker();
                if (isUninstall)
                {
                    worker.Uninstall(_ => { });
                }
                else
                {
                    worker.Install(_ => { });
                }
                return 0;
            }
            catch
            {
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
    }
}
