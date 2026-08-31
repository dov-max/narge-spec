import SwiftUI
import NetworkExtension

struct ContentView: View {
    @StateObject private var dnsManager = DNSManager()
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "network")
                .font(.system(size: 60))
                .foregroundColor(.brown)
                .padding(.top, 40)
            
            Text("Cutline DNS")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                HStack {
                    Circle()
                        .fill(dnsManager.isEnabled ? Color.green : Color.gray)
                        .frame(width: 12, height: 12)
                    
                    Text(dnsManager.isEnabled ? "Enabled" : "Disabled")
                        .font(.title2)
                        .fontWeight(.medium)
                }
                
                if dnsManager.isLoading {
                    ProgressView()
                        .padding()
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Button(action: {
                if dnsManager.isEnabled {
                    dnsManager.disableDNS()
                } else {
                    dnsManager.enableDNS()
                }
            }) {
                Text(dnsManager.isEnabled ? "Disable Cutline DNS" : "Enable Cutline DNS")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.brown)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .disabled(dnsManager.isLoading)
            
            if dnsManager.requiresUserApproval {
                VStack(alignment: .leading, spacing: 8) {
                    Text("⚠️ Action Required")
                        .font(.headline)
                    Text("Go to Settings → VPN & Device Management → DNS to approve the configuration")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.yellow.opacity(0.2))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            if isPrivateRelayLikelyEnabled() {
                VStack(alignment: .leading, spacing: 8) {
                    Text("⚠️ iCloud Private Relay")
                        .font(.headline)
                    Text("Private Relay bypasses Cutline DNS and the cut will not work. To use Cutline, turn off Private Relay in Settings.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.2))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            if let error = dnsManager.errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                Link("Verify It Works", destination: URL(string: "https://thecutline.org/verify")!)
                    .font(.subheadline)
                
                Link("Privacy Policy", destination: URL(string: "https://thecutline.org/privacy")!)
                    .font(.subheadline)
            }
            .padding(.bottom, 30)
        }
        .onAppear {
            dnsManager.checkStatus()
        }
    }
    
    private func isPrivateRelayLikelyEnabled() -> Bool {
        #if os(iOS)
        return false
        #else
        return false
        #endif
    }
}

#Preview {
    ContentView()
}
