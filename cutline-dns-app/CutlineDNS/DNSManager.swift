import Foundation
import NetworkExtension
#if os(macOS)
import SystemConfiguration
#endif

enum VerificationResult: Equatable {
    case notTested
    case checking
    case working
    case privateRelayDetected
    case onNotReachable
    case offNotBlocked
    case networkError(String)
}

class DNSManager: ObservableObject {
    @Published var isEnabled = false
    @Published var verificationResult: VerificationResult = .notTested
    @Published var isLoading = false
    @Published var waitingForUserToEnable = false
    @Published var showAdvanced = false
    @Published var dnsStats: String = ""
    
    private let serverURL = "https://dns.thecutline.org/dns-query"
    private let bootstrapServers = ["64.176.200.99", "149.28.79.49"]
    private var verificationTimer: Timer?
    
    deinit {
        verificationTimer?.invalidate()
    }
    
    func onAppear() {
        verificationResult = .notTested
        isLoading = true
        loadStatus()
    }
    
    func loadStatus() {
        NEDNSSettingsManager.shared().loadFromPreferences { [weak self] error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    self.isLoading = false
                    self.verificationResult = .networkError(error.localizedDescription)
                    return
                }
                
                let wasEnabled = self.isEnabled
                self.isEnabled = NEDNSSettingsManager.shared().isEnabled
                
                if self.waitingForUserToEnable && !self.isEnabled {
                    self.isLoading = false
                    return
                }
                
                if self.isEnabled {
                    self.waitingForUserToEnable = false
                    self.verifyConnection()
                } else {
                    self.isLoading = false
                    self.verificationResult = .notTested
                }
            }
        }
    }
    
    func detectPrivateRelay() -> Bool {
        #if os(macOS)
        if let proxies = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any],
           let autoConfig = proxies[kCFProxyAutoConfigurationURLKey as String] as? String {
            return autoConfig.contains("mask.icloud.com") || autoConfig.contains("mask-h2.icloud.com")
        }
        #endif
        return false
    }
    
    func verifyConnection() {
        verificationResult = .checking
        
        if detectPrivateRelay() {
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
            } else if let error = error {
                lastError = error.localizedDescription
            }
            group.leave()
        }.resume()
        
        group.enter()
        var offRequest = URLRequest(url: URL(string: "https://off.thecutline.org/ok")!)
        offRequest.cachePolicy = .reloadIgnoringLocalCacheData
        session.dataTask(with: offRequest) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                offSuccess = true
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
                        if nsError.domain == "NEConfigurationErrorDomain" && nsError.code == 9 {
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
        isLoading = true
        loadStatus()
    }
    
    func openSystemSettings() {
        #if os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
        #elseif os(iOS)
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
        isLoading = true
        loadStatus()
    }
    
    func loadDNSStats() {
        dnsStats = "DNS Statistics: [Advanced diagnostics would appear here]"
    }
}
