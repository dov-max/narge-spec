import Foundation
import NetworkExtension

class DNSManager: ObservableObject {
    @Published var isEnabled = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var requiresUserApproval = false
    
    private let serverURL = "https://dns.thecutline.org/dns-query"
    private let bootstrapServers = ["64.176.200.99", "149.28.79.49"]
    private let configurationDescription = "Cutline DNS"
    
    func checkStatus() {
        isLoading = true
        errorMessage = nil
        
        NEDNSSettingsManager.shared().loadFromPreferences { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Failed to load DNS settings: \(error.localizedDescription)"
                    self?.isEnabled = false
                    return
                }
                
                self?.isEnabled = NEDNSSettingsManager.shared().isEnabled
            }
        }
    }
    
    func enableDNS() {
        isLoading = true
        errorMessage = nil
        requiresUserApproval = false
        
        NEDNSSettingsManager.shared().loadFromPreferences { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Failed to load preferences: \(error.localizedDescription)"
                }
                return
            }
            
            let dnsSettings = NEDNSOverHTTPSSettings(servers: self.bootstrapServers)
            dnsSettings.serverURL = URL(string: self.serverURL)
            
            NEDNSSettingsManager.shared().dnsSettings = dnsSettings
            
            let connectRule = NEOnDemandRuleConnect()
            connectRule.interfaceTypeMatch = .any
            
            NEDNSSettingsManager.shared().onDemandRules = [connectRule]
            
            NEDNSSettingsManager.shared().saveToPreferences { [weak self] error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        let nsError = error as NSError
                        if nsError.domain == "NEConfigurationErrorDomain" && nsError.code == 10 {
                            self?.requiresUserApproval = true
                        }
                        self?.errorMessage = "Failed to save DNS settings: \(error.localizedDescription)"
                        self?.checkStatus()
                    } else {
                        self?.requiresUserApproval = true
                        self?.isEnabled = true
                    }
                }
            }
        }
    }
    
    func disableDNS() {
        isLoading = true
        errorMessage = nil
        requiresUserApproval = false
        
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
                    }
                }
            }
        }
    }
}
