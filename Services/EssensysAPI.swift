//
//  EssensysAPI.swift
//  EssensysApp
//
//  Service API pour communiquer avec le backend Essensys
//

import Foundation

struct EssensysAPI {
    static let shared = EssensysAPI()
    
    private init() {}
    
    func sendInjection(k: Int, v: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // En mode démo, on simule une réussite immédiate
        if ConnectionManager.shared.isDemoMode {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                completion(.success(()))
            }
            return
        }
        
        let config = ConnectionManager.shared.config
        let baseURL = config.currentURL
        guard let url = URL(string: "\(baseURL)/api/admin/inject") else {
            completion(.failure(NSError(domain: "EssensysAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL invalide"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0
        
        // Ajouter l'authentification si nécessaire (WAN)
        if config.needsPassword && !config.wanPassword.isEmpty {
            let username = config.wanUsername.isEmpty ? "user" : config.wanUsername
            let credentials = "\(username):\(config.wanPassword)".data(using: .utf8)?.base64EncodedString() ?? ""
            request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = ["k": k, "v": v]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                    completion(.success(()))
                } else {
                    let error = NSError(domain: "EssensysAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Erreur HTTP \(httpResponse.statusCode)"])
                    completion(.failure(error))
                }
            } else {
                completion(.failure(NSError(domain: "EssensysAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Réponse invalide"])))
            }
        }.resume()
    }
    
    func getServerInfos(completion: @escaping (Result<ServerInfos, Error>) -> Void) {
        // En mode démo, on retourne des infos fictives
        if ConnectionManager.shared.isDemoMode {
            let mockInfos = ServerInfos(isconnected: true, infos: [], newversion: "1.0.0 (Démo)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                completion(.success(mockInfos))
            }
            return
        }

        let config = ConnectionManager.shared.config
        let baseURL = config.currentURL
        guard let url = URL(string: "\(baseURL)/api/serverinfos") else {
            completion(.failure(NSError(domain: "EssensysAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL invalide"])))
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
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "EssensysAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Pas de données"])))
                return
            }
            
            do {
                let serverInfos = try JSONDecoder().decode(ServerInfos.self, from: data)
                completion(.success(serverInfos))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

struct ServerInfos: Codable {
    let isconnected: Bool
    let infos: [Int]
    let newversion: String?
}

