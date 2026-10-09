//
//  HeatingView.swift
//  EssensysApp
//
//  Vue de pilotage du chauffage par zones et modes.
//

import SwiftUI

enum HeatingMode: String, CaseIterable, Identifiable, Codable {
    case confort = "Confort"
    case eco = "Éco"
    case horsGel = "Hors Gel"
    case off = "Arrêt"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .confort: return "flame.fill"
        case .eco: return "leaf.fill"
        case .horsGel: return "thermometer.snowflake"
        case .off: return "power.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .confort: return .orange
        case .eco: return .green
        case .horsGel: return .blue
        case .off: return .gray
        }
    }
}

struct HeatingZone: Identifiable, Codable {
    let id: String
    var name: String
    var currentMode: HeatingMode
}

struct HeatingView: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // Simuler la persistence pour ce prototype
    @State private var zones: [HeatingZone] = [
        HeatingZone(id: "zone_jour", name: "Chauffage Zone Jour", currentMode: .confort),
        HeatingZone(id: "zone_nuit", name: "Chauffage Zone Nuit", currentMode: .eco),
        HeatingZone(id: "zone_sdb1", name: "Chauffage Salle de bain 1", currentMode: .confort),
        HeatingZone(id: "zone_sdb2", name: "Chauffage Salle de bain 2", currentMode: .confort)
    ]
    
    @State private var cumulusMode: CumulusMode = .onAutonome
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Info Banner
                    InfoBanner()
                    
                    
                    
                    ForEach($zones) { $zone in
                        HeatingZoneCard(zone: $zone, onError: { error in
                            errorMessage = error
                            showingError = true
                        })
                    }

                    // Cumulus Section
                    CumulusCard(mode: $cumulusMode, onError: { error in
                        errorMessage = error
                        showingError = true
                    })
                }
                .padding()
            }
            .background(Color(.systemGray6).opacity(0.3))
            .navigationTitle("Chauffage")
            .alert("Erreur", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
}

struct HeatingZoneCard: View {
    @Binding var zone: HeatingZone
    let onError: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "thermometer")
                    .foregroundColor(zone.currentMode.color)
                    .font(.title2)
                
                Text(zone.name)
                    .font(.headline)
                    .foregroundColor(Color(hex: "2D3748"))
                
                Spacer()
                
                Text(zone.currentMode.rawValue)
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(zone.currentMode.color.opacity(0.1))
                    .foregroundColor(zone.currentMode.color)
                    .cornerRadius(4)
            }
            
            Divider()
            
            // Mode Selection
            HStack(spacing: 10) {
                ForEach(HeatingMode.allCases) { mode in
                    Button(action: {
                        setMode(mode)
                    }) {
                        VStack(spacing: 6) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 20))
                            Text(mode.rawValue)
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(zone.currentMode == mode ? mode.color.opacity(0.15) : Color.white)
                        .foregroundColor(zone.currentMode == mode ? mode.color : .gray)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(zone.currentMode == mode ? mode.color : Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func setMode(_ mode: HeatingMode) {
        // Optimistic UI Update
        let oldMode = zone.currentMode
        zone.currentMode = mode
        
        // Simulation d'appel API
        // Dans une vraie implémentation, on mapperait le mode vers un index/valeur compatible avec sendInjection
        // ex: Confort = "1", Eco = "2", etc.
        
        if ConnectionManager.shared.isDemoMode {
            // Nothing more to do
        } else {
            // TODO: Implémenter l'appel API réel ici
            // EssensysAPI.shared.sendInjection(...)
        }
    }
}

enum CumulusMode: String, CaseIterable, Identifiable, Codable {
    case onAutonome = "ON (autonome)"
    case suiviHPHC = "Suivi HP/HC"
    case off = "OFF"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .onAutonome: return "bolt.fill"
        case .suiviHPHC: return "clock.arrow.2.circlepath"
        case .off: return "power.circle"
        }
    }
}

struct CumulusCard: View {
    @Binding var mode: CumulusMode
    let onError: (String) -> Void
    
    // Couleur violette demandée
    let purpleColor = Color(hex: "805AD5") 
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "drop.fill") // Icone pour le Cumulus
                    .foregroundColor(purpleColor)
                    .font(.title2)
                
                Text("Cumulus")
                    .font(.headline)
                    .foregroundColor(Color(hex: "2D3748"))
                
                Spacer()
                
                Text(mode.rawValue)
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(mode == .off ? Color.gray.opacity(0.1) : purpleColor.opacity(0.1))
                    .foregroundColor(mode == .off ? .gray : purpleColor)
                    .cornerRadius(4)
            }
            
            Divider()
            
            HStack(spacing: 10) {
                ForEach(CumulusMode.allCases) { option in
                    Button(action: {
                        setMode(option)
                    }) {
                        VStack(spacing: 6) {
                            Image(systemName: option.icon)
                                .font(.system(size: 20))
                            Text(option.rawValue)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true) // Allow wrapping if needed
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity) // Uniform height
                        .padding(.vertical, 10)
                        .padding(.horizontal, 4)
                        .background(mode == option ? (option == .off ? Color.gray.opacity(0.15) : purpleColor.opacity(0.15)) : Color.white)
                        .foregroundColor(mode == option ? (option == .off ? .gray : purpleColor) : .gray)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(mode == option ? (option == .off ? .gray : purpleColor) : Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true) // Ensure text wrapping doesn't break layout
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func setMode(_ newMode: CumulusMode) {
        mode = newMode
        // TODO: Implémenter l'appel API réel ici
    }
}
