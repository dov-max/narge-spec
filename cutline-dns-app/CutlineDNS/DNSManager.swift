import Foundation
import NetworkExtension
import Network
#if os(macOS)
import SystemConfiguration
import AppKit
#else
import UIKit
#endif

enum WizardStep {
    case notStarted
    case installingFilter
    case filterInstalled
    case needsEnabling
    case confirming
    case working
}

enum VerificationResult {
    case notTested
    case testing
    case waitingForDNS(attempt: Int, maxAttempts: Int)
    case passed
    case failed(reason: String)
}

struct NetworkService {
    let name: String
    let dnsServers: [String]
    let isCutline: Bool
}

enum PrivateRelayStatus {
    case on
    case off
    case unknown
}

struct NetworkStats {
    var distinctIPs7d: Int?
    var latencyP50Ms: Double?
    var latencyWindow: String?
    var health: String?
    var asOf: String?
    var ewr: BoxStats?
    var lax: BoxStats?
    
    struct BoxStats {
        var health: String?
        var latencyP50Ms: Double?
    }
}

struct DiagnosticInfo {
    var activeInterface: String = "Unknown"
    var services: [NetworkService] = []
    var encryptedDNSEnabled: Bool = false
    var dohReachable: Bool?
    var dohError: String?
    var privateRelayStatus: PrivateRelayStatus = .unknown
}

class DNSManager: ObservableObject {
    @Published var isEnabled = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var verificationResult: VerificationResult = .notTested
    @Published var onTestResult: String?
    @Published var offTestResult: String?
    @Published var diagnosticInfo = DiagnosticInfo()
    @Published var networkStats: NetworkStats?
    @Published var wizardStep: WizardStep = .notStarted
    @Published var stepMessage: String = ""
    
    private let serverURL = "https://dns.thecutline.org/dns-query"
    private let bootstrapServers = ["64.176.200.99", "149.28.79.49"]
    private let configurationDescription = "Cutline DNS"
    private let cutlineServers = ["64.176.200.99", "149.28.79.49", "dns.thecutline.org"]
    
    private var pathMonitor: NWPathMonitor?
    private var verificationRetryTimer: Timer?
    private let maxVerificationRetries = 6  // ~15 seconds with 2.5s intervals
    
    deinit {
        verificationRetryTimer?.invalidate()
        pathMonitor?.cancel()
    }
    
    func loadFromPreferences() {
        isLoading = true
        errorMessage = nil
        
        NEDNSSettingsManager.shared().loadFromPreferences { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Failed to load DNS settings: \(error.localizedDescription)"
                    self?.isEnabled = false
                    self?.wizardStep = .notStarted
                    return
                }
                
                self?.isEnabled = NEDNSSettingsManager.shared().isEnabled
                
                // Determine wizard step based on current state
                if self?.isEnabled == true {
                    // Already enabled, skip to confirm/verify
                    self?.wizardStep = .working
                    self?.verifyDNS()
                } else if NEDNSSettingsManager.shared().dnsSettings != nil {
                    // Filter exists but disabled, skip to step 2
                    self?.wizardStep = .needsEnabling
                } else {
                    // No filter, need to start from beginning
                    self?.wizardStep = .notStarted
                }
                
                self?.gatherDiagnostics()
            }
        }
    }
    
    func checkStatus() {
        loadFromPreferences()
    }
    
    func gatherDiagnostics() {
        var info = DiagnosticInfo()
        
        // Get active interface
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.usesInterfaceType(.wifi) {
                    self?.diagnosticInfo.activeInterface = "Wi-Fi"
                } else if path.usesInterfaceType(.cellular) {
                    self?.diagnosticInfo.activeInterface = "Cellular"
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self?.diagnosticInfo.activeInterface = "Ethernet"
                } else if path.usesInterfaceType(.loopback) {
                    self?.diagnosticInfo.activeInterface = "Loopback"
                } else {
                    self?.diagnosticInfo.activeInterface = "Other"
                }
            }
            monitor.cancel()
        }
        monitor.start(queue: DispatchQueue.global())
        
        // Check encrypted DNS status
        info.encryptedDNSEnabled = NEDNSSettingsManager.shared().isEnabled
        
        // Detect Private Relay
        info.privateRelayStatus = detectPrivateRelay()
        
        // Platform-specific DNS enumeration
        #if os(macOS)
        info.services = enumerateDNSServersMacOS()
        #else
        // iOS/iPadOS/visionOS: Cannot enumerate per-adapter DNS from sandbox
        info.services = []
        #endif
        
        DispatchQueue.main.async {
            self.diagnosticInfo.services = info.services
            self.diagnosticInfo.encryptedDNSEnabled = info.encryptedDNSEnabled
            self.diagnosticInfo.privateRelayStatus = info.privateRelayStatus
        }
        
        // Fetch network stats
        fetchNetworkStats()
    }
    
    private func detectPrivateRelay() -> PrivateRelayStatus {
        // Check CFNetwork proxy settings for iCloud Private Relay indicators
        guard let proxySettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] else {
            return .unknown
        }
        
        // Check for mask.icloud.com or mask-h2.icloud.com in proxy settings
        let privateRelayDomains = ["mask.icloud.com", "mask-h2.icloud.com"]
        
        // Check HTTPS proxy
        if let httpsProxy = proxySettings["HTTPSProxy"] as? String {
            if privateRelayDomains.contains(where: { httpsProxy.contains($0) }) {
                return .on
            }
        }
        
        // Check PAC URL
        if let pacURL = proxySettings["ProxyAutoConfigURLString"] as? String {
            if privateRelayDomains.contains(where: { pacURL.contains($0) }) {
                return .on
            }
        }
        
        // Check scoped proxies
        if let scopedProxies = proxySettings["__SCOPED__"] as? [String: Any] {
            for (_, scopedSettings) in scopedProxies {
                if let scopedDict = scopedSettings as? [String: Any] {
                    if let httpsProxy = scopedDict["HTTPSProxy"] as? String,
                       privateRelayDomains.contains(where: { httpsProxy.contains($0) }) {
                        return .on
                    }
                    if let pacURL = scopedDict["ProxyAutoConfigURLString"] as? String,
                       privateRelayDomains.contains(where: { pacURL.contains($0) }) {
                        return .on
                    }
                }
            }
        }
        
        #if os(macOS)
        // Additional macOS check via SystemConfiguration
        if let dynamicStore = SCDynamicStoreCreate(nil, "CutlineDNS" as CFString, nil, nil),
           let proxies = SCDynamicStoreCopyProxies(dynamicStore) as? [String: Any] {
            if let httpsProxy = proxies["HTTPSProxy"] as? String,
               privateRelayDomains.contains(where: { httpsProxy.contains($0) }) {
                return .on
            }
        }
        #endif
        
        // If we checked and found nothing, consider it off
        return .off
    }
    
    func fetchNetworkStats() {
        let session = URLSession.shared
        
        // Fetch combined stats
        if let url = URL(string: "https://dns.thecutline.org/stats.json") {
            session.dataTask(with: url) { [weak self] data, _, _ in
                guard let data = data else { return }
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    var stats = NetworkStats()
                    stats.distinctIPs7d = json["distinct_ips_7d"] as? Int
                    stats.latencyP50Ms = json["latency_p50_ms"] as? Double
                    stats.latencyWindow = json["latency_window"] as? String
                    stats.health = json["health"] as? String
                    stats.asOf = json["as_of"] as? String
                    
                    DispatchQueue.main.async {
                        self?.networkStats = stats
                    }
                    
                    // Try fetching per-box stats
                    self?.fetchBoxStats()
                }
            }.resume()
        }
    }
    
    private func fetchBoxStats() {
        let session = URLSession.shared
        let group = DispatchGroup()
        
        var ewrStats: NetworkStats.BoxStats?
        var laxStats: NetworkStats.BoxStats?
        
        // Fetch EWR stats
        group.enter()
        if let url = URL(string: "https://ewr.dns.thecutline.org/stats.json") {
            session.dataTask(with: url) { data, response, _ in
                defer { group.leave() }
                
                guard let data = data,
                      let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return
                }
                
                ewrStats = NetworkStats.BoxStats(
                    health: json["health"] as? String,
                    latencyP50Ms: json["latency_p50_ms"] as? Double
                )
            }.resume()
        } else {
            group.leave()
        }
        
        // Fetch LAX stats
        group.enter()
        if let url = URL(string: "https://lax.dns.thecutline.org/stats.json") {
            session.dataTask(with: url) { data, response, _ in
                defer { group.leave() }
                
                guard let data = data,
                      let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return
                }
                
                laxStats = NetworkStats.BoxStats(
                    health: json["health"] as? String,
                    latencyP50Ms: json["latency_p50_ms"] as? Double
                )
            }.resume()
        } else {
            group.leave()
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.networkStats?.ewr = ewrStats
            self?.networkStats?.lax = laxStats
        }
    }
    
    #if os(macOS)
    private func enumerateDNSServersMacOS() -> [NetworkService] {
        var services: [NetworkService] = []
        
        guard let dynamicStore = SCDynamicStoreCreate(nil, "CutlineDNS" as CFString, nil, nil) else {
            return services
        }
        
        // Get network service IDs
        guard let serviceIDs = SCDynamicStoreCopyKeyList(dynamicStore, "State:/Network/Service/.*/DNS" as CFString) as? [String] else {
            return services
        }
        
        for key in serviceIDs {
            guard let dict = SCDynamicStoreCopyValue(dynamicStore, key as CFString) as? [String: Any],
                  let dnsServers = dict["ServerAddresses"] as? [String], !dnsServers.isEmpty else {
                continue
            }
            
            // Extract service name from key (State:/Network/Service/{serviceID}/DNS)
            let components = key.split(separator: "/")
            let serviceName = components.count >= 4 ? String(components[3]) : "Unknown"
            
            // Check if any DNS server is Cutline
            let isCutline = dnsServers.contains { server in
                cutlineServers.contains(server)
            }
            
            services.append(NetworkService(name: serviceName, dnsServers: dnsServers, isCutline: isCutline))
        }
        
        return services
    }
    #endif
    
    func enableDNS() {
        // Step 1: Install the filter
        isLoading = true
        errorMessage = nil
        wizardStep = .installingFilter
        stepMessage = "Installing..."
        
        NEDNSSettingsManager.shared().loadFromPreferences { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Failed to load preferences: \(error.localizedDescription)"
                    self.wizardStep = .notStarted
                }
                return
            }
            
            let dnsSettings = NEDNSOverHTTPSSettings(servers: self.bootstrapServers)
            dnsSettings.serverURL = URL(string: self.serverURL)
            
            NEDNSSettingsManager.shared().localizedDescription = "Cutline DNS"
            NEDNSSettingsManager.shared().dnsSettings = dnsSettings
            
            let connectRule = NEOnDemandRuleConnect()
            connectRule.interfaceTypeMatch = .any
            
            NEDNSSettingsManager.shared().onDemandRules = [connectRule]
            
            NEDNSSettingsManager.shared().saveToPreferences { [weak self] error in
                guard let self = self else { return }
                
                if let error = error {
                    let nsError = error as NSError
                    
                    // Check if this is "configuration is unchanged" error
                    // NEConfigurationErrorDomain code 9 means configuration is unchanged
                    let isUnchangedError = nsError.domain == "NEConfigurationErrorDomain" && nsError.code == 9
                    
                    if isUnchangedError {
                        // Configuration is unchanged = SUCCESS (filter is already installed)
                        // Continue to wait for DNS row
                        self.waitForDNSRow()
                    } else {
                        // Actual error
                        DispatchQueue.main.async {
                            self.isLoading = false
                            self.errorMessage = "Failed to save DNS settings: \(error.localizedDescription)"
                            self.wizardStep = .notStarted
                        }
                    }
                    return
                }
                
                // Configuration saved (unchanged = success)
                // Now wait for the DNS row to exist
                self.waitForDNSRow()
            }
        }
    }
    
    private func waitForDNSRow(attempt: Int = 0) {
        let maxAttempts = 8
        
        NEDNSSettingsManager.shared().loadFromPreferences { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Failed to verify DNS settings: \(error.localizedDescription)"
                    self.wizardStep = .notStarted
                }
                return
            }
            
            // Check if dnsSettings is non-nil (filter installed in API)
            if NEDNSSettingsManager.shared().dnsSettings != nil {
                // Filter installed, step 1 complete
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.stepMessage = "Filter installed."
                    self.wizardStep = .filterInstalled
                    
                    // After a brief delay, move to step 2
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.wizardStep = .needsEnabling
                        // Now open Filters pane
                        self.openFiltersPane()
                    }
                }
            } else if attempt < maxAttempts {
                // Filter not ready yet, retry after a short delay
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.25) {
                    self.waitForDNSRow(attempt: attempt + 1)
                }
            } else {
                // Max retries reached
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "DNS configuration not ready. Please try again."
                    self.wizardStep = .notStarted
                }
            }
        }
    }
    
    func checkAfterUserEnabled() {
        // Step 3: Confirm
        isLoading = true
        wizardStep = .confirming
        stepMessage = "Checking..."
        
        // Check after a short delay to give the system time to update
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { [weak self] in
            NEDNSSettingsManager.shared().loadFromPreferences { [weak self] error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    if let error = error {
                        self.isLoading = false
                        self.errorMessage = "Failed to verify: \(error.localizedDescription)"
                        self.wizardStep = .needsEnabling
                        return
                    }
                    
                    self.isEnabled = NEDNSSettingsManager.shared().isEnabled
                    
                    if !self.isEnabled {
                        // Still disabled
                        self.isLoading = false
                        self.stepMessage = "Still Disabled."
                        self.wizardStep = .needsEnabling
                        // Open Filters again
                        #if os(macOS)
                        self.openFiltersPane()
                        #else
                        self.openSystemSettings()
                        #endif
                    } else {
                        // Enabled! Show message then verify
                        self.stepMessage = "Enabled. Checking..."
                        // Run fail-closed verify
                        self.verifyDNS()
                    }
                }
            }
        }
    }
    
    func disableDNS() {
        isLoading = true
        errorMessage = nil
        
        NEDNSSettingsManager.shared().loadFromPreferences { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Failed to load preferences: \(error.localizedDescription)"
                }
                return
            }
            
            NEDNSSettingsManager.shared().removeFromPreferences { [weak self] error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.errorMessage = "Failed to remove DNS settings: \(error.localizedDescription)"
                    } else {
                        self?.isEnabled = false
                        self?.wizardStep = .notStarted
                        self?.verificationResult = .notTested
                    }
                }
            }
        }
    }
    
    func runDiagnosticTest(retryAttempt: Int = 0) {
        // Cancel any existing retry timer
        verificationRetryTimer?.invalidate()
        verificationRetryTimer = nil
        
        if retryAttempt == 0 {
            verificationResult = .testing
            onTestResult = nil
            offTestResult = nil
            
            // Refresh diagnostics first
            gatherDiagnostics()
        }
        
        let group = DispatchGroup()
        var onSuccess = false
        var offFailed = false
        var onError: String?
        var offError: String?
        var dohSuccess = false
        var dohErrorMsg: String?
        
        // Test DoH endpoint reachability (use /stats.json as /dns-query returns 400 without DNS body)
        group.enter()
        testURL(urlString: "https://dns.thecutline.org/stats.json") { success, error in
            dohSuccess = success
            dohErrorMsg = error
            group.leave()
        }
        
        // Test on.thecutline.org/ok - should succeed
        group.enter()
        testURL(urlString: "https://on.thecutline.org/ok") { success, error in
            onSuccess = success
            if success {
                onError = "✓ Resolved"
            } else {
                onError = error ?? "Failed"
            }
            group.leave()
        }
        
        // Test off.thecutline.org/ok - should fail (NXDOMAIN)
        group.enter()
        testURL(urlString: "https://off.thecutline.org/ok") { success, error in
            offFailed = !success
            if !success {
                offError = "✓ Blocked (expected)"
            } else {
                offError = "⚠️ Resolved (should be blocked)"
            }
            group.leave()
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            self.diagnosticInfo.dohReachable = dohSuccess
            self.diagnosticInfo.dohError = dohErrorMsg
            self.onTestResult = onError
            self.offTestResult = offError
            
            let privateRelayOn = self.diagnosticInfo.privateRelayStatus == .on
            let testPassed = onSuccess && offFailed
            
            if testPassed {
                // Test passed - Step 4: Working
                self.verificationResult = .passed
                self.wizardStep = .working
            } else if self.diagnosticInfo.encryptedDNSEnabled && retryAttempt < self.maxVerificationRetries {
                // DNS is enabled but test failed - retry after a delay (DNS cache may need to clear)
                self.verificationResult = .waitingForDNS(attempt: retryAttempt + 1, maxAttempts: self.maxVerificationRetries)
                
                // Schedule retry after 2.5 seconds
                self.verificationRetryTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
                    self?.runDiagnosticTest(retryAttempt: retryAttempt + 1)
                }
            } else {
                // Test failed and either DNS not enabled or max retries reached
                if !onSuccess && !offFailed {
                    // Both failed - check Private Relay first
                    if privateRelayOn {
                        self.verificationResult = .failed(reason: "iCloud Private Relay is on. Private Relay bypasses Cutline DNS, so the cut will not work. Turn off Private Relay and try again.")
                    } else {
                        self.verificationResult = .failed(reason: "Neither domain resolved. Check your internet connection.")
                    }
                } else if !onSuccess {
                    if privateRelayOn {
                        self.verificationResult = .failed(reason: "on.thecutline.org did not resolve. iCloud Private Relay is on and may be interfering. Turn off Private Relay and try again.")
                    } else {
                        self.verificationResult = .failed(reason: "on.thecutline.org did not resolve. Check your internet connection.")
                    }
                } else if !offFailed {
                    // off.thecutline.org succeeded when it should be blocked
                    if privateRelayOn {
                        self.verificationResult = .failed(reason: "iCloud Private Relay is on. Private Relay bypasses Cutline DNS, so the cut will not work. Turn off Private Relay.")
                    } else if self.diagnosticInfo.encryptedDNSEnabled {
                        self.verificationResult = .failed(reason: "off.thecutline.org resolved when it should be blocked. Cutline DNS is enabled but something else is leaking DNS queries.")
                    } else {
                        self.verificationResult = .failed(reason: "off.thecutline.org resolved when it should be blocked. DNS is not routing through Cutline.")
                    }
                } else {
                    self.verificationResult = .failed(reason: "Verification failed.")
                }
                
                // Stay on working step even if verify failed
                self.wizardStep = .working
            }
        }
    }
    
    func verifyDNS() {
        runDiagnosticTest()
    }
    
    private func testURL(urlString: String, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(false, "Invalid URL")
            return
        }
        
        // Use reloadIgnoringLocalCacheData to bypass URL cache
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.httpMethod = "GET"
        
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: config)
        
        let task = session.dataTask(with: request) { _, response, error in
            if let error = error {
                let nsError = error as NSError
                // DNS resolution failures
                if nsError.domain == NSURLErrorDomain &&
                   (nsError.code == NSURLErrorCannotFindHost ||
                    nsError.code == NSURLErrorDNSLookupFailed) {
                    completion(false, "DNS lookup failed")
                } else {
                    completion(false, error.localizedDescription)
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                completion(httpResponse.statusCode == 200, "HTTP \(httpResponse.statusCode)")
            } else {
                completion(false, "No response")
            }
        }
        task.resume()
    }
    
    func openSystemSettings() {
        #if os(macOS)
        openFiltersPane()
        #elseif os(iOS)
        // Open the app's Settings page (not the DNS pane, as there's no public URL for that)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #elseif os(visionOS)
        // Open Settings if possible
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
    
    #if os(macOS)
    private func openFiltersPane() {
        // Step a: Check if already on Filters detail pane
        if isOnFiltersDetailPane() {
            // Already there, just activate Settings
            activateSystemSettings()
            return
        }
        
        // Step b/c: Open or navigate to Network pane, then poll for Filters row
        let settingsRunning = NSWorkspace.shared.runningApplications.contains { app in
            app.bundleIdentifier == "com.apple.systempreferences"
        }
        
        if !settingsRunning {
            // Settings not running, open Network pane
            if let url = URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension") {
                let config = NSWorkspace.OpenConfiguration()
                config.activates = false  // Keep Cutline front until click succeeds
                NSWorkspace.shared.open(url, configuration: config) { _, _ in
                    // Start polling after a brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.pollForFiltersRowAndClick(attempt: 0)
                    }
                }
            }
        } else {
            // Settings running, check if we need to navigate to Network
            if !isOnNetworkPane() {
                // Not on Network pane, open it
                if let url = URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension") {
                    NSWorkspace.shared.open(url)
                }
            }
            activateSystemSettings()
            
            // Start polling after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.pollForFiltersRowAndClick(attempt: 0)
            }
        }
    }
    
    private func isOnFiltersDetailPane() -> Bool {
        let script = """
        tell application "System Settings"
            try
                set frontWindow to window 1
                tell frontWindow
                    -- Check for "Filters & Proxies" static text
                    if exists (static text "Filters & Proxies") then
                        return true
                    end if
                    -- Check for "Cutline DNS" UI element
                    if exists (UI element "Cutline DNS") then
                        return true
                    end if
                end tell
                return false
            on error
                return false
            end try
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let result = scriptObject.executeAndReturnError(&error)
            if error == nil, let boolValue = result.booleanValue {
                return boolValue
            }
        }
        return false
    }
    
    private func isOnNetworkPane() -> Bool {
        let script = """
        tell application "System Settings"
            try
                set frontWindow to window 1
                tell frontWindow
                    -- Check if Network UI elements exist (Wi-Fi, etc.)
                    if exists (UI element "Wi-Fi") then
                        return true
                    end if
                    if exists (UI element "Network") then
                        return true
                    end if
                end tell
                return false
            on error
                return false
            end try
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let result = scriptObject.executeAndReturnError(&error)
            if error == nil, let boolValue = result.booleanValue {
                return boolValue
            }
        }
        return false
    }
    
    private func activateSystemSettings() {
        NSWorkspace.shared.runningApplications.first { app in
            app.bundleIdentifier == "com.apple.systempreferences"
        }?.activate()
    }
    
    private func pollForFiltersRowAndClick(attempt: Int) {
        let maxAttempts = 20  // ~8 seconds with 0.4s intervals
        
        // Check if Filters row exists (not the back button)
        if filtersRowExists() {
            // Found it, click once
            clickFiltersRow()
            
            // Poll for success
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.pollForFiltersPaneSuccess(attempt: 0)
            }
        } else if attempt < maxAttempts {
            // Not found yet, retry
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.pollForFiltersRowAndClick(attempt: attempt + 1)
            }
        } else {
            // Max retries reached, give up
            NSLog("Cutline DNS: Filters row not found after polling")
        }
    }
    
    private func filtersRowExists() -> Bool {
        let script = """
        tell application "System Settings"
            try
                set frontWindow to window 1
                tell frontWindow
                    -- Look for Filters UI element in the Network list (not back button)
                    if exists (UI element "Filters") then
                        -- Make sure it's in a list, not a title bar
                        set filtersElement to UI element "Filters"
                        set parentElement to container of filtersElement
                        set grandparent to container of parentElement
                        -- Check if it's in a scroll area or list (Network service list)
                        if class of grandparent is scroll area or class of parentElement is scroll area then
                            return true
                        end if
                    end if
                end tell
                return false
            on error
                return false
            end try
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let result = scriptObject.executeAndReturnError(&error)
            if error == nil, let boolValue = result.booleanValue {
                return boolValue
            }
        }
        return false
    }
    
    private func clickFiltersRow() {
        let script = """
        tell application "System Settings"
            try
                activate
                set frontWindow to window 1
                tell frontWindow
                    -- Click the Filters row in the Network list
                    set filtersElement to UI element "Filters"
                    set parentElement to container of filtersElement
                    set grandparent to container of parentElement
                    -- Verify it's in the list before clicking
                    if class of grandparent is scroll area or class of parentElement is scroll area then
                        click filtersElement
                        return true
                    end if
                end tell
                return false
            on error errMsg
                return false
            end try
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
        }
    }
    
    private func pollForFiltersPaneSuccess(attempt: Int) {
        let maxAttempts = 10  // ~5 seconds
        
        // Check if we're on Filters detail pane
        if isOnFiltersDetailPane() {
            // Success! Stop polling
            NSLog("Cutline DNS: Successfully navigated to Filters pane")
            return
        } else if attempt < maxAttempts {
            // Not there yet, keep polling
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.pollForFiltersPaneSuccess(attempt: attempt + 1)
            }
        } else {
            // Failed to navigate
            NSLog("Cutline DNS: Failed to navigate to Filters pane")
        }
    }
    #endif
    
    func isCutlineServer(_ server: String) -> Bool {
        return cutlineServers.contains(server)
    }
    
    func getPlatformSettingsInstructions() -> String {
        #if os(macOS)
        return "System Settings → Network → VPN & Filters → Cutline DNS"
        #elseif os(iOS)
        return "Settings → General → VPN & Device Management → DNS → Cutline DNS"
        #elseif os(visionOS)
        return "Settings → General → VPN & Device Management → DNS → Cutline DNS"
        #else
        return "Settings → VPN & Device Management → DNS → Cutline DNS"
        #endif
    }
}
