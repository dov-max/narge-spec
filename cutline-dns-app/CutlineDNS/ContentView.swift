import SwiftUI
import NetworkExtension

struct ContentView: View {
    @StateObject private var dnsManager = DNSManager()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        adaptiveContainer {
            contentStack
        }
        .onAppear {
            dnsManager.checkStatus()
        }
    }
    
    @ViewBuilder
    private func adaptiveContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if horizontalSizeClass == .regular {
            ScrollView {
                content()
                    .frame(maxWidth: 460)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity)
        } else {
            content()
        }
    }
    
    private var contentStack: some View {
        VStack(spacing: 30) {
            Image(systemName: "network")
                .font(.system(size: 60))
                .foregroundColor(Color(red: 0.0, green: 0.4, blue: 0.8))
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
            .background(Color.secondary.opacity(0.1))
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
                    .background(Color(red: 0.0, green: 0.4, blue: 0.8))
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
            
            VStack(alignment: .leading, spacing: 8) {
                Text("ℹ️ iCloud Private Relay")
                    .font(.headline)
                Text("If iCloud Private Relay is on, the cut will not work.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
            
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
    }
}

#Preview {
    ContentView()
}
