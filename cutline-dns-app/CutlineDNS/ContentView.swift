import SwiftUI
import NetworkExtension

struct ContentView: View {
    @StateObject private var dnsManager = DNSManager()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerView
                
                if dnsManager.isLoading && dnsManager.verificationResult == .notTested {
                    checkingView
                } else if !dnsManager.isEnabled {
                    offStateView
                } else if dnsManager.waitingForUserToEnable {
                    waitingForEnableView
                } else {
                    switch dnsManager.verificationResult {
                    case .working:
                        workingView
                    case .checking:
                        checkingView
                    case .privateRelayDetected:
                        privateRelayView
                    case .onNotReachable, .offNotBlocked, .networkError:
                        problemView
                    case .notTested:
                        checkingView
                    }
                }
                
                if dnsManager.showAdvanced {
                    advancedView
                }
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .frame(minWidth: 480, idealWidth: 520, minHeight: 640, idealHeight: 720)
        .onAppear {
            dnsManager.onAppear()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active && dnsManager.waitingForUserToEnable {
                dnsManager.loadStatus()
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "network")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            Text("Cutline DNS")
                .font(.title)
                .fontWeight(.semibold)
        }
        .padding(.top, 16)
    }
    
    private var checkingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .padding()
        }
    }
    
    private var offStateView: some View {
        VStack(spacing: 20) {
            Text("Free and open source. No account.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 8)
            
            Button(action: {
                dnsManager.saveConfiguration()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dnsManager.openSystemSettings()
                }
            }) {
                Text("Turn on Cutline DNS")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var waitingForEnableView: some View {
        VStack(spacing: 20) {
            #if os(macOS)
            if let image = NSImage(named: "SettingsFilters") {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 450)
                    .cornerRadius(8)
                    .shadow(radius: 2)
            }
            #endif
            
            Text("Apple requires you to set Cutline DNS to Enabled.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            #if os(macOS)
            Text("In System Settings → Network → Filters, flip the switch, then return here.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            #elseif os(iOS) || os(visionOS)
            Text("In Settings → General → VPN & Device Management → DNS → Cutline DNS, enable it, then return here.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            #endif
            
            Button(action: {
                dnsManager.userConfirmedEnabled()
            }) {
                Text("I've enabled it")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(dnsManager.isLoading)
        }
        .padding(.vertical)
    }
    
    private var workingView: some View {
        VStack(spacing: 20) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
                
                Text("Cutline is on")
                    .font(.body)
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 8)
            
            Button(action: {
                dnsManager.disableDNS()
            }) {
                Text("Disable")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(dnsManager.isLoading)
            
            Button(action: {
                dnsManager.showAdvanced.toggle()
            }) {
                HStack {
                    Text("Advanced")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Image(systemName: dnsManager.showAdvanced ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    private var privateRelayView: some View {
        VStack(spacing: 20) {
            Text("iCloud Private Relay is on")
                .font(.body)
                .foregroundColor(.primary)
            
            Text("The cut will not work while Private Relay is enabled.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                dnsManager.retryVerification()
            }) {
                Text("Retry")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(dnsManager.isLoading)
            
            Button(action: {
                dnsManager.showAdvanced.toggle()
            }) {
                HStack {
                    Text("Advanced")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Image(systemName: dnsManager.showAdvanced ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    private var problemView: some View {
        VStack(spacing: 20) {
            Text(problemTitle)
                .font(.body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Text(problemDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                dnsManager.retryVerification()
            }) {
                Text("Retry")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(dnsManager.isLoading)
            
            Button(action: {
                dnsManager.showAdvanced.toggle()
            }) {
                HStack {
                    Text("Advanced")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Image(systemName: dnsManager.showAdvanced ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    private var problemTitle: String {
        switch dnsManager.verificationResult {
        case .onNotReachable:
            return "Cannot reach verification server"
        case .offNotBlocked:
            return "DNS not cutting"
        case .networkError:
            return "Network error"
        default:
            return "Problem detected"
        }
    }
    
    private var problemDescription: String {
        switch dnsManager.verificationResult {
        case .onNotReachable:
            return "Unable to connect to on.thecutline.org"
        case .offNotBlocked:
            return "Verification shows DNS is not blocking as expected"
        case .networkError(let message):
            return message
        default:
            return "Please retry or check Advanced for details"
        }
    }
    
    private var advancedView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
            
            Text("Advanced")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Verification Details")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Status: \(verificationStatusText)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Probe: on.thecutline.org → should succeed")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Probe: off.thecutline.org → should fail")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Link("GitHub Repository", destination: URL(string: "https://github.com/dov-max/narge-spec")!)
                .font(.caption)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(10)
    }
    
    private var verificationStatusText: String {
        switch dnsManager.verificationResult {
        case .notTested:
            return "Not tested"
        case .checking:
            return "Checking..."
        case .working:
            return "Working"
        case .privateRelayDetected:
            return "Private Relay detected"
        case .onNotReachable:
            return "On probe failed"
        case .offNotBlocked:
            return "Off probe succeeded (should fail)"
        case .networkError(let message):
            return "Error: \(message)"
        }
    }
}

#Preview {
    ContentView()
}
