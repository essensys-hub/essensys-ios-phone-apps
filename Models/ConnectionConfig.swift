//
//  ConnectionConfig.swift
//  EssensysApp
//
//  Configuration de connexion pour Essensys
//

import Foundation

enum ConnectionMode: String, Codable {
    case local = "local"
    case wan = "wan"
}

struct ConnectionConfig: Codable {
    var mode: ConnectionMode
    var localURL: String
    var wanURL: String
    var wanUsername: String
    var wanPassword: String
    
    static let `default` = ConnectionConfig(
        mode: .local,
        localURL: "http://mon.essensys.fr",
        wanURL: "",
        wanUsername: "",
        wanPassword: ""
    )
    
    var currentURL: String {
        switch mode {
        case .local:
            return localURL
        case .wan:
            return wanURL.isEmpty ? "https://mon.essensys.fr" : wanURL
        }
    }
    
    var needsPassword: Bool {
        return mode == .wan
    }
}

