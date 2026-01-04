//
//  ConnectionManager.swift
//  EssensysApp
//
//  Gestionnaire de connexion Essensys
//

import Foundation
import Combine

class ConnectionManager: ObservableObject {
    static let shared = ConnectionManager()
    
    @Published var config: ConnectionConfig
    @Published var isConnected: Bool = false
    @Published var connectionError: String?
    
    private let configKey = "essensys_connection_config"
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Charger la configuration depuis UserDefaults
        if let data = UserDefaults.standard.data(forKey: configKey),
           let decoded = try? JSONDecoder().decode(ConnectionConfig.self, from: data) {
            self.config = decoded
        } else {
            self.config = ConnectionConfig.default
        }
        
        // Tester la connexion au démarrage
        testConnection()
    }
    
    func saveConfig() {
        if let encoded = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(encoded, forKey: configKey)
        }
        testConnection()
    }
    
    func testConnection() {
        connectionError = nil
        isConnected = false
        
        let urlString = config.currentURL
        guard let url = URL(string: "\(urlString)/api/serverinfos") else {
            connectionError = "URL invalide"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0
        
        // Ajouter l'authentification si nécessaire (WAN)
        if config.needsPassword && !config.wanPassword.isEmpty {
            let username = config.wanUsername.isEmpty ? "user" : config.wanUsername
            let credentials = "\(username):\(config.wanPassword)".data(using: .utf8)?.base64EncodedString() ?? ""
            request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.connectionError = error.localizedDescription
                    self?.isConnected = false
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        self?.isConnected = true
                        self?.connectionError = nil
                    } else {
                        self?.connectionError = "Erreur HTTP \(httpResponse.statusCode)"
                        self?.isConnected = false
                    }
                }
            }
        }.resume()
    }
}

