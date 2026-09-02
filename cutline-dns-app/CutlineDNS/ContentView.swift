import SwiftUI
import NetworkExtension

struct ContentView: View {
    @StateObject private var dnsManager = DNSManager()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @State private var showAdvanced = false
    
    var body: some View {
        adaptiveContainer {
            contentStack
        }
        .onAppear {
            dnsManager.loadFromPreferences()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                dnsManager.loadFromPreferences()
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
            
            // Free and Open Source (quiet)
            Text("Free & Open Source")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Network Stats (compact, always when we have data and in working step)
            if let stats = dnsManager.networkStats, dnsManager.wizardStep == .working {
                VStack(spacing: 8) {
                    if let distinctIPs = stats.distinctIPs7d {
                        HStack {
                            Image(systemName: "person.2")
                                .foregroundColor(Color(red: 0.0, green: 0.4, blue: 0.8))
                            Text("\(distinctIPs) distinct IPs (7d)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let latency = stats.latencyP50Ms {
                        HStack {
                            Image(systemName: "speedometer")
                                .foregroundColor(Color(red: 0.0, green: 0.4, blue: 0.8))
                            Text("p50: \(String(format: "%.1f", latency))ms")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let ewr = stats.ewr, let lax = stats.lax,
                       let ewrLatency = ewr.latencyP50Ms,
                       let laxLatency = lax.latencyP50Ms {
                        HStack(spacing: 16) {
                            Text("EWR \(String(format: "%.0f", ewrLatency))ms")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("LAX \(String(format: "%.0f", laxLatency))ms")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            // Status pill
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
            
            // Wizard steps - one visible at a time
            wizardStepView
            
            // Private Relay warning (only if it's a problem)
            if dnsManager.diagnosticInfo.privateRelayStatus == .on {
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
            }
            
            // Advanced (collapsed)
            if dnsManager.wizardStep == .working {
                VStack(spacing: 0) {
                    Button(action: {
                        withAnimation {
                            showAdvanced.toggle()
                        }
                    }) {
                        HStack {
                            Image(systemName: "waveform.path.ecg")
                                .foregroundColor(Color(red: 0.0, green: 0.4, blue: 0.8))
                            Text("Advanced")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal)
                    
                    if showAdvanced {
                        advancedView
                    }
                }
            }
            
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
    
    @ViewBuilder
    private var wizardStepView: some View {
        switch dnsManager.wizardStep {
        case .notStarted:
            // Show Turn On button
            Button(action: {
                dnsManager.enableDNS()
            }) {
                Text("Turn On Cutline DNS")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(red: 0.0, green: 0.4, blue: 0.8))
                    .cornerRadius(12)
            }
            .disabled(dnsManager.isLoading)
            .padding(.horizontal)
            
        case .installingFilter:
            // Step 1: Installing
            VStack(spacing: 12) {
                HStack {
                    ProgressView()
                    Text(dnsManager.stepMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
            
        case .filterInstalled:
            // Step 1 complete: Filter installed
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(dnsManager.stepMessage)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
            
        case .needsEnabling:
            // Step 2: Enable it
            VStack(alignment: .leading, spacing: 12) {
                if !dnsManager.stepMessage.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(dnsManager.stepMessage)
                            .font(.headline)
                    }
                }
                
                Text("Cutline DNS is Disabled. In Filters, set Cutline DNS to Enabled.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                #if os(macOS)
                if let screenshot = NSImage(named: "SettingsFilters") {
                    Image(nsImage: screenshot)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .cornerRadius(8)
                }
                #endif
                
                Button(action: {
                    dnsManager.openSystemSettings()
                }) {
                    Text("Open Filters")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(red: 0.0, green: 0.4, blue: 0.8))
                        .cornerRadius(8)
                }
                
                Button(action: {
                    dnsManager.checkAfterUserEnabled()
                }) {
                    Text("I've Enabled It")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color(red: 0.0, green: 0.4, blue: 0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(red: 0.0, green: 0.4, blue: 0.8).opacity(0.1))
                        .cornerRadius(8)
                }
                .disabled(dnsManager.isLoading)
            }
            .padding()
            .background(dnsManager.stepMessage.contains("Still") ? Color.orange.opacity(0.2) : Color.yellow.opacity(0.2))
            .cornerRadius(12)
            .padding(.horizontal)
            
        case .confirming:
            // Step 3: Confirming
            VStack(spacing: 12) {
                HStack {
                    ProgressView()
                    Text(dnsManager.stepMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
            
        case .working:
            // Step 4: Working
            VStack(spacing: 12) {
                // Verify button
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
                
                // Disable button
                Button(action: {
                    dnsManager.disableDNS()
                }) {
                    Text("Disable Cutline DNS")
                        .font(.headline)
                        .foregroundColor(Color(red: 0.0, green: 0.4, blue: 0.8))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(12)
                }
                .disabled(dnsManager.isLoading)
            }
            .padding(.horizontal)
            
            // Verification results
            verificationResultView
        }
    }
    
    @ViewBuilder
    private var verificationResultView: some View {
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
                    Text("Cutline is on")
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
                    Text(getSimplifiedFailureReason(reason))
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
                
                Button(action: {
                    dnsManager.verifyDNS()
                }) {
                    Text("Retry Verification")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.0, green: 0.4, blue: 0.8))
                        .cornerRadius(8)
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
    }
    
    private func getSimplifiedFailureReason(_ reason: String) -> String {
        // Show one problem - prioritize Private Relay
        if reason.contains("Private Relay") {
            return "Private Relay is on"
        } else if reason.contains("off.thecutline.org") && !reason.contains("blocked") {
            return "DNS not routing through Cutline"
        } else if reason.contains("on.thecutline.org") {
            return "Connection problem"
        } else {
            return "Verification failed"
        }
    }
    
    @ViewBuilder
    private var advancedView: some View {
        VStack(alignment: .leading, spacing: 12) {
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

#Preview {
    ContentView()
}
