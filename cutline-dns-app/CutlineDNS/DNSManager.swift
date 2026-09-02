import Foundation
import NetworkExtension
import Network
#if os(macOS)
import SystemConfiguration
import AppKit
#else
import UIKit
#endif

enum VerificationResult: Equatable {
    case notTested
    case checking
    case working
    case privateRelayDetected
    case onNotReachable
    case offNotBlocked
    case networkError(String)
    
    static func == (lhs: VerificationResult, rhs: VerificationResult) -> Bool {
        switch (lhs, rhs) {
        case (.notTested, .notTested),
             (.checking, .checking),
             (.working, .working),
             (.privateRelayDetected, .privateRelayDetected),
             (.onNotReachable, .onNotReachable),
             (.offNotBlocked, .offNotBlocked):
            return true
        case (.networkError(let lhsMsg), .networkError(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
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
    @Published var waitingForUserToEnable = false
    @Published var showAdvanced = false
    @Published var verificationResult: VerificationResult = .notTested
    @Published var onTestResult: String?
    @Published var offTestResult: String?
    @Published var diagnosticInfo = DiagnosticInfo()
    @Published var networkStats: NetworkStats?
    
    private let serverURL = "https://dns.thecutline.org/dns-query"
    private let bootstrapServers = ["64.176.200.99", "149.28.79.49"]
    private let configurationDescription = "Cutline DNS"
    private let cutlineServers = ["64.176.200.99", "149.28.79.49", "dns.thecutline.org"]
    
    private var pathMonitor: NWPathMonitor?
    
    deinit {
        pathMonitor?.cancel()
    }
    
    func onAppear() {
        fullRefresh()
    }
    
    func onSceneActive() {
        fullRefresh()
    }
    
    func fullRefresh() {
        verificationResult = .notTested
        onTestResult = nil
        offTestResult = nil
        isLoading = true
        
        NEDNSSettingsManager.shared().loadFromPreferences { [weak self] error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    self.isLoading = false
                    self.verificationResult = .networkError(error.localizedDescription)
                    return
                }
                
                self.isEnabled = NEDNSSettingsManager.shared().isEnabled
                self.gatherDiagnostics()
                
                if self.isEnabled {
                    self.waitingForUserToEnable = false
                    self.verifyConnection()
                } else {
                    self.isLoading = false
                }
            }
        }
    }
    
    func gatherDiagnostics() {
        var info = DiagnosticInfo()
        
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
        
        info.encryptedDNSEnabled = NEDNSSettingsManager.shared().isEnabled
        info.privateRelayStatus = detectPrivateRelay()
        
        #if os(macOS)
        info.services = enumerateDNSServersMacOS()
        #else
        info.services = []
        #endif
        
        DispatchQueue.main.async {
            self.diagnosticInfo.services = info.services
            self.diagnosticInfo.encryptedDNSEnabled = info.encryptedDNSEnabled
            self.diagnosticInfo.privateRelayStatus = info.privateRelayStatus
        }
        
        fetchNetworkStats()
    }
    
    private func detectPrivateRelay() -> PrivateRelayStatus {
        guard let proxySettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] else {
            return .unknown
        }
        
        let privateRelayDomains = ["mask.icloud.com", "mask-h2.icloud.com"]
        
        if let httpsProxy = proxySettings["HTTPSProxy"] as? String {
            if privateRelayDomains.contains(where: { httpsProxy.contains($0) }) {
                return .on
            }
        }
        
        if let pacURL = proxySettings["ProxyAutoConfigURLString"] as? String {
            if privateRelayDomains.contains(where: { pacURL.contains($0) }) {
                return .on
            }
        }
        
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
        if let dynamicStore = SCDynamicStoreCreate(nil, "CutlineDNS" as CFString, nil, nil),
           let proxies = SCDynamicStoreCopyProxies(dynamicStore) as? [String: Any] {
            if let httpsProxy = proxies["HTTPSProxy"] as? String,
               privateRelayDomains.contains(where: { httpsProxy.contains($0) }) {
                return .on
            }
        }
        #endif
        
        return .off
    }
    
    func fetchNetworkStats() {
        let session = URLSession.shared
        
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
        
        guard let serviceIDs = SCDynamicStoreCopyKeyList(dynamicStore, "State:/Network/Service/.*/DNS" as CFString) as? [String] else {
            return services
        }
        
        for key in serviceIDs {
            guard let dict = SCDynamicStoreCopyValue(dynamicStore, key as CFString) as? [String: Any],
                  let dnsServers = dict["ServerAddresses"] as? [String], !dnsServers.isEmpty else {
                continue
            }
            
            let components = key.split(separator: "/")
            let serviceName = components.count >= 4 ? String(components[3]) : "Unknown"
            
            let isCutline = dnsServers.contains { server in
                cutlineServers.contains(server)
            }
            
            services.append(NetworkService(name: serviceName, dnsServers: dnsServers, isCutline: isCutline))
        }
        
        return services
    }
    #endif
    
    func verifyConnection() {
        verificationResult = .checking
        
        if diagnosticInfo.privateRelayStatus == .on {
            isLoading = false
            verificationResult = .privateRelayDetected
            return
        }
        
        let group = DispatchGroup()
        var onSuccess = false
        var offSuccess = false
        var lastError: String?
        
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        let session = URLSession(configuration: config)
        
        group.enter()
        var onRequest = URLRequest(url: URL(string: "https://on.thecutline.org/ok")!)
        onRequest.cachePolicy = .reloadIgnoringLocalCacheData
        session.dataTask(with: onRequest) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                onSuccess = true
                DispatchQueue.main.async {
                    self.onTestResult = "✓ Resolved"
                }
            } else if let error = error {
                lastError = error.localizedDescription
                DispatchQueue.main.async {
                    self.onTestResult = "Failed: \(error.localizedDescription)"
                }
            }
            group.leave()
        }.resume()
        
        group.enter()
        var offRequest = URLRequest(url: URL(string: "https://off.thecutline.org/ok")!)
        offRequest.cachePolicy = .reloadIgnoringLocalCacheData
        session.dataTask(with: offRequest) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                offSuccess = true
                DispatchQueue.main.async {
                    self.offTestResult = "⚠️ Resolved (should be blocked)"
                }
            } else {
                DispatchQueue.main.async {
                    self.offTestResult = "✓ Blocked (expected)"
                }
            }
            group.leave()
        }.resume()
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.isLoading = false
            
            if onSuccess && !offSuccess {
                self.verificationResult = .working
            } else if !onSuccess {
                self.verificationResult = .onNotReachable
            } else if offSuccess {
                self.verificationResult = .offNotBlocked
            } else if let error = lastError {
                self.verificationResult = .networkError(error)
            }
        }
    }
    
    func saveConfiguration() {
        isLoading = true
        waitingForUserToEnable = false
        
        NEDNSSettingsManager.shared().loadFromPreferences { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.verificationResult = .networkError(error.localizedDescription)
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
                
                DispatchQueue.main.async {
                    if let error = error {
                        let nsError = error as NSError
                        if nsError.domain == "NEConfigurationErrorDomain" {
                            self.isLoading = false
                            self.waitingForUserToEnable = true
                            return
                        }
                    }
                    
                    self.isLoading = false
                    self.waitingForUserToEnable = true
                }
            }
        }
    }
    
    func userConfirmedEnabled() {
        fullRefresh()
    }
    
    func openSystemSettings() {
        #if os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
        #elseif os(iOS) || os(visionOS)
        if let url = URL(string: "App-Prefs:General&path=ManagedConfigurationList") {
            UIApplication.shared.open(url)
        }
        #endif
    }
    
    func disableDNS() {
        isLoading = true
        
        NEDNSSettingsManager.shared().removeFromPreferences { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if error == nil {
                    self?.isEnabled = false
                    self?.verificationResult = .notTested
                    self?.waitingForUserToEnable = false
                }
            }
        }
    }
    
    func retryVerification() {
        fullRefresh()
    }
}
