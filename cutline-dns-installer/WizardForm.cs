using System;
using System.Drawing;
using System.Windows.Forms;

namespace CutlineDnsInstaller
{
    public class WizardForm : Form
    {
        private Panel contentPanel;
        private Panel buttonPanel;
        private Button primaryButton;
        private Button cancelButton;
        private Label titleLabel;
        private RichTextBox messageBox;
        private ProgressBar progressBar;
        
        private WizardState currentState;
        private bool isUninstall;
        private InstallWorker worker;

        public enum WizardState
        {
            Welcome,
            Working,
            Done
        }

        public WizardForm(bool uninstall)
        {
            isUninstall = uninstall;
            worker = new InstallWorker();
            InitializeComponents();
            ShowWelcomeScreen();
        }

        private void InitializeComponents()
        {
            this.Text = "Cutline DNS Setup";
            this.Size = new Size(500, 400);
            this.FormBorderStyle = FormBorderStyle.FixedDialog;
            this.MaximizeBox = false;
            this.MinimizeBox = false;
            this.StartPosition = FormStartPosition.CenterScreen;
            this.Icon = SystemIcons.Shield;

            contentPanel = new Panel
            {
                Dock = DockStyle.Fill,
                Padding = new Padding(20)
            };

            titleLabel = new Label
            {
                Font = new Font("Segoe UI", 16F, FontStyle.Bold),
                AutoSize = true,
                Location = new Point(20, 20)
            };

            messageBox = new RichTextBox
            {
                Location = new Point(20, 60),
                Size = new Size(440, 200),
                ReadOnly = true,
                BorderStyle = BorderStyle.None,
                BackColor = this.BackColor,
                Font = new Font("Segoe UI", 10F)
            };

            progressBar = new ProgressBar
            {
                Location = new Point(20, 270),
                Size = new Size(440, 23),
                Style = ProgressBarStyle.Marquee,
                Visible = false
            };

            buttonPanel = new Panel
            {
                Dock = DockStyle.Bottom,
                Height = 60,
                Padding = new Padding(20, 10, 20, 10)
            };

            primaryButton = new Button
            {
                Size = new Size(100, 32),
                Location = new Point(260, 14),
                Font = new Font("Segoe UI", 9F),
                UseVisualStyleBackColor = true
            };
            primaryButton.Click += PrimaryButton_Click;

            cancelButton = new Button
            {
                Text = "Cancel",
                Size = new Size(100, 32),
                Location = new Point(370, 14),
                Font = new Font("Segoe UI", 9F),
                UseVisualStyleBackColor = true
            };
            cancelButton.Click += CancelButton_Click;

            contentPanel.Controls.Add(titleLabel);
            contentPanel.Controls.Add(messageBox);
            contentPanel.Controls.Add(progressBar);
            buttonPanel.Controls.Add(primaryButton);
            buttonPanel.Controls.Add(cancelButton);

            this.Controls.Add(contentPanel);
            this.Controls.Add(buttonPanel);
        }

        private void ShowWelcomeScreen()
        {
            currentState = WizardState.Welcome;
            
            if (isUninstall)
            {
                titleLabel.Text = "Uninstall Cutline DNS";
                messageBox.Text = "This will remove Cutline DNS from your computer and restore your network settings to use DHCP.\n\n" +
                                "The following will be removed:\n" +
                                "• DNS configuration (64.176.200.99, 149.28.79.49)\n" +
                                "• DoH (DNS over HTTPS) templates\n" +
                                "• Network monitor scheduled task\n" +
                                "• Installation files\n\n" +
                                "IPv6 will be re-enabled on all adapters.";
                primaryButton.Text = "Uninstall";
            }
            else
            {
                titleLabel.Text = "Cutline DNS Setup";
                messageBox.Text = "This will configure encrypted DNS on your PC.\n\n" +
                                "What will be configured:\n" +
                                "• Encrypted DNS on all network adapters (Wi-Fi, Ethernet, cellular)\n" +
                                "• DNS servers: 64.176.200.99, 149.28.79.49\n" +
                                "• DoH template: https://dns.thecutline.org/dns-query (Windows 11)\n" +
                                "• IPv6 will be disabled to prevent DNS leaks\n" +
                                "• Automatic configuration for new network adapters\n\n" +
                                "Administrator privileges are required.";
                primaryButton.Text = "Install";
            }

            cancelButton.Text = "Cancel";
            cancelButton.Enabled = true;
            progressBar.Visible = false;
        }

        private void ShowWorkingScreen()
        {
            currentState = WizardState.Working;
            
            if (isUninstall)
            {
                titleLabel.Text = "Removing Cutline DNS";
            }
            else
            {
                titleLabel.Text = "Setting up";
            }

            messageBox.Clear();
            progressBar.Visible = true;
            progressBar.Style = ProgressBarStyle.Marquee;
            primaryButton.Enabled = false;
            cancelButton.Enabled = false;

            var bgWorker = new System.ComponentModel.BackgroundWorker();
            bgWorker.DoWork += (s, e) =>
            {
                try
                {
                    if (isUninstall)
                    {
                        worker.Uninstall((msg) => AppendMessage(msg));
                    }
                    else
                    {
                        worker.Install((msg) => AppendMessage(msg));
                    }
                    e.Result = true;
                }
                catch (Exception ex)
                {
                    e.Result = ex;
                }
            };
            bgWorker.RunWorkerCompleted += (s, e) =>
            {
                if (e.Result is Exception ex)
                {
                    ShowError(ex.Message);
                }
                else
                {
                    ShowDoneScreen();
                }
            };
            bgWorker.RunWorkerAsync();
        }

        private void ShowDoneScreen()
        {
            currentState = WizardState.Done;
            progressBar.Visible = false;

            if (isUninstall)
            {
                titleLabel.Text = "Uninstallation Complete";
                messageBox.Clear();
                messageBox.Text = "Cutline DNS has been removed from your system.\n\n" +
                                "Your network settings have been restored to use DHCP.\n" +
                                "IPv6 has been re-enabled on all adapters.";
            }
            else
            {
                titleLabel.Text = "Setup Complete";
                messageBox.Clear();
                messageBox.Text = "Cutline DNS is now active on your system.\n\n" +
                                "New network adapters will be configured automatically.\n\n";
                
                var linkLabel = new LinkLabel
                {
                    Text = "Verify your connection at thecutline.org/verify",
                    Location = new Point(20, 180),
                    Size = new Size(440, 20),
                    Font = new Font("Segoe UI", 10F)
                };
                linkLabel.LinkClicked += (s, e) =>
                {
                    System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
                    {
                        FileName = "https://thecutline.org/verify",
                        UseShellExecute = true
                    });
                };
                contentPanel.Controls.Add(linkLabel);
            }

            primaryButton.Text = "Close";
            primaryButton.Enabled = true;
            cancelButton.Visible = false;
        }

        private void ShowError(string message)
        {
            progressBar.Visible = false;
            titleLabel.Text = "Error";
            messageBox.Clear();
            messageBox.Text = $"An error occurred:\n\n{message}\n\n" +
                            "The operation may have been partially completed. " +
                            "You can try running the installer again.";
            primaryButton.Text = "Close";
            primaryButton.Enabled = true;
            cancelButton.Visible = false;
        }

        private void AppendMessage(string message)
        {
            if (messageBox.InvokeRequired)
            {
                messageBox.Invoke(new Action<string>(AppendMessage), message);
                return;
            }

            messageBox.AppendText(message + "\n");
            messageBox.SelectionStart = messageBox.Text.Length;
            messageBox.ScrollToCaret();
        }

        private void PrimaryButton_Click(object sender, EventArgs e)
        {
            switch (currentState)
            {
                case WizardState.Welcome:
                    ShowWorkingScreen();
                    break;
                case WizardState.Done:
                    this.Close();
                    break;
            }
        }

        private void CancelButton_Click(object sender, EventArgs e)
        {
            if (currentState == WizardState.Welcome)
            {
                this.Close();
            }
        }
    }
}
