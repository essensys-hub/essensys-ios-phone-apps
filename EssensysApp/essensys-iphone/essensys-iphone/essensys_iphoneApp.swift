//
//  essensys_iphoneApp.swift
//  essensys-iphone
//
//  Created by Nicolas Rineau on 03/01/2026.
//

import SwiftUI

@main
struct essensys_iphoneApp: App {
    @StateObject private var connectionManager = ConnectionManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectionManager)
        }
    }
}
