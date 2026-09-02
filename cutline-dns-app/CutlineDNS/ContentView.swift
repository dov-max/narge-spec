import SwiftUI
import NetworkExtension

struct ContentView: View {
    @StateObject private var dnsManager = DNSManager()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @State private var showDiagnostics = false
    
    var body: some View {
        adaptiveContainer {
            contentStack
        }
        .onAppear {
            dnsManager.checkStatus()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // Re-check diagnostics when app becomes active
                dnsManager.gatherDiagnostics()
            }
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
            
            // Free and Open Source
            VStack(spacing: 8) {
                Text("Free & Open Source")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.0, green: 0.4, blue: 0.8))
                
                Text("No account • No login • No data collected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Link("View Source Code", destination: URL(string: "https://github.com/dov-max/narge-spec")!)
                    .font(.subheadline)
                    .foregroundColor(Color(red: 0.0, green: 0.4, blue: 0.8))
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(red: 0.0, green: 0.4, blue: 0.8).opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
            
            // Network Stats
            if let stats = dnsManager.networkStats {
                VStack(spacing: 8) {
                    if let distinctIPs = stats.distinctIPs7d {
                        HStack {
                            Image(systemName: "person.2")
                                .foregroundColor(Color(red: 0.0, green: 0.4, blue: 0.8))
                            Text("\(distinctIPs) distinct source IPs (7 days)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let latency = stats.latencyP50Ms, let window = stats.latencyWindow {
                        HStack {
                            Image(systemName: "speedometer")
                                .foregroundColor(Color(red: 0.0, green: 0.4, blue: 0.8))
                            Text("p50 latency: \(String(format: "%.1f", latency))ms (\(window))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let ewr = stats.ewr, let lax = stats.lax {
                        HStack(spacing: 16) {
                            if let ewrLatency = ewr.latencyP50Ms {
                                VStack {
                                    Text("EWR")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("\(String(format: "%.0f", ewrLatency))ms")
                                        .font(.caption)
                                }
                            }
                            if let laxLatency = lax.latencyP50Ms {
                                VStack {
                                    Text("LAX")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("\(String(format: "%.0f", laxLatency))ms")
                                        .font(.caption)
                                }
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
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
            
            VStack(spacing: 12) {
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
                .disabled(dnsManager.isLoading)
                
                Button(action: {
                    dnsManager.verifyDNS()
                }) {
                    Text("Verify It Works")
                        .font(.headline)
                        .foregroundColor(Color(red: 0.0, green: 0.4, blue: 0.8))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 0.0, green: 0.4, blue: 0.8).opacity(0.1))
                        .cornerRadius(12)
                }
                .disabled({
                    switch dnsManager.verificationResult {
                    case .testing, .waitingForDNS:
                        return true
                    default:
                        return false
                    }
                }())
            }
            .padding(.horizontal)
            
            // Network Diagnostics
            VStack(spacing: 0) {
                Button(action: {
                    withAnimation {
                        showDiagnostics.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: "waveform.path.ecg")
                            .foregroundColor(Color(red: 0.0, green: 0.4, blue: 0.8))
                        Text("Network Diagnostics")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: showDiagnostics ? "chevron.up" : "chevron.down")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal)
                
                if showDiagnostics {
                    VStack(alignment: .leading, spacing: 12) {
                        // Private Relay Status - Show prominently first
                        HStack(alignment: .top) {
                            Text("iCloud Private Relay:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            VStack(alignment: .leading) {
                                switch dnsManager.diagnosticInfo.privateRelayStatus {
                                case .on:
                                    Text("⚠️ ON")
                                        .font(.subheadline)
                                        .foregroundColor(.orange)
                                    Text("Private Relay bypasses Cutline DNS")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                case .off:
                                    Text("✓ OFF")
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                case .unknown:
                                    Text("Unknown")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Active Interface
                        HStack {
                            Text("Active Interface:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(dnsManager.diagnosticInfo.activeInterface)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        // Encrypted DNS Status
                        HStack {
                            Text("Cutline DNS (Encrypted):")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(dnsManager.diagnosticInfo.encryptedDNSEnabled ? "Enabled" : "Disabled")
                                .font(.subheadline)
                                .foregroundColor(dnsManager.diagnosticInfo.encryptedDNSEnabled ? .green : .secondary)
                        }
                        
                        // DoH Reachability
                        if let dohReachable = dnsManager.diagnosticInfo.dohReachable {
                            HStack(alignment: .top) {
                                Text("DoH Endpoint:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                VStack(alignment: .leading) {
                                    Text(dohReachable ? "✓ Reachable" : "✗ Not Reachable")
                                        .font(.subheadline)
                                        .foregroundColor(dohReachable ? .green : .red)
                                    if !dohReachable, let error = dnsManager.diagnosticInfo.dohError {
                                        Text(error)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        
                        #if os(macOS)
                        // DNS Servers per Service (macOS only)
                        if !dnsManager.diagnosticInfo.services.isEmpty {
                            Divider()
                            Text("DNS Servers by Service:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            ForEach(dnsManager.diagnosticInfo.services, id: \.name) { service in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(service.name)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        if service.isCutline {
                                            Text("(Cutline)")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        }
                                    }
                                    ForEach(service.dnsServers, id: \.self) { server in
                                        HStack {
                                            Text("  •")
                                                .font(.caption2)
                                            Text(server)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            if dnsManager.isCutlineServer(server) {
                                                Text("Cutline")
                                                    .font(.caption2)
                                                    .foregroundColor(.green)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.green.opacity(0.2))
                                                    .cornerRadius(4)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        #endif
                        
                        Text("Note: Even if per-adapter DNS shows router/ISP servers, Cutline DNS (Encrypted) takes priority when enabled.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top, 4)
                }
            }
            
            // Verification results
            switch dnsManager.verificationResult {
            case .testing:
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Testing DNS...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                
            case .waitingForDNS(let attempt, let maxAttempts):
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Waiting for DNS cache to clear...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Attempt \(attempt) of \(maxAttempts)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let onResult = dnsManager.onTestResult,
                       let offResult = dnsManager.offTestResult {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("on.thecutline.org: \(onResult)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("off.thecutline.org: \(offResult)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                
            case .passed:
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("✓")
                            .font(.title)
                            .foregroundColor(.green)
                        Text("Cutline DNS is Working")
                            .font(.headline)
                    }
                    
                    if let onResult = dnsManager.onTestResult,
                       let offResult = dnsManager.offTestResult {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("on.thecutline.org: \(onResult)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("off.thecutline.org: \(offResult)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.2))
                .cornerRadius(12)
                .padding(.horizontal)
                
            case .failed(let reason):
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("✗")
                            .font(.title)
                            .foregroundColor(.red)
                        Text("Verification Failed")
                            .font(.headline)
                    }
                    
                    Text(reason)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let onResult = dnsManager.onTestResult,
                       let offResult = dnsManager.offTestResult {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("on.thecutline.org: \(onResult)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("off.thecutline.org: \(offResult)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.2))
                .cornerRadius(12)
                .padding(.horizontal)
                
            case .notTested:
                EmptyView()
            }
            
            if dnsManager.requiresUserApproval {
                VStack(alignment: .leading, spacing: 12) {
                    Text("⚠️ Action Required")
                        .font(.headline)
                    
                    Text("Go to \(dnsManager.getPlatformSettingsInstructions()) to approve the configuration")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        dnsManager.openSystemSettings()
                    }) {
                        Text("Open Settings")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(red: 0.0, green: 0.4, blue: 0.8))
                            .cornerRadius(8)
                    }
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
            
            VStack(spacing: 8) {
                Link("How Verification Works", destination: URL(string: "https://thecutline.org/verify")!)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Link("Privacy Policy", destination: URL(string: "https://thecutline.org/privacy")!)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 30)
        }
    }
}

#Preview {
    ContentView()
}
