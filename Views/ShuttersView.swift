//
//  ShuttersView.swift
//  EssensysApp
//
//  Created by Nicolas Rineau on 03/01/2026.
//

import SwiftUI

struct ShutterItem: Identifiable {
    let id = UUID()
    let name: String
    let activeIndex: Int // Index pour activer (monter/descendre) est souvent le même, la valeur change ou l'inverse
    let upValue: String
    let downValue: String
    let stopValue: String
}

// Données des volets (Exemple - À ADAPTER avec les vrais indices)
struct ShuttersData {
    static let shutters: [String: [ShutterItem]] = [
        "Salon": [
            ShutterItem(name: "Baie Vitrée", activeIndex: 600, upValue: "1", downValue: "2", stopValue: "0"),
            ShutterItem(name: "Fenêtre", activeIndex: 600, upValue: "4", downValue: "8", stopValue: "0")
        ],
        "Chambres": [
            ShutterItem(name: "Grande Chambre", activeIndex: 601, upValue: "1", downValue: "2", stopValue: "0"),
            ShutterItem(name: "Petite Chambre", activeIndex: 601, upValue: "4", downValue: "8", stopValue: "0")
        ],
        "Cuisine": [
            ShutterItem(name: "Cuisine", activeIndex: 602, upValue: "1", downValue: "2", stopValue: "0")
        ]
    ]
    
    // Ordre d'affichage des pièces
    static let roomsOrder = ["Salon", "Cuisine", "Chambres"]
}

struct ShuttersView: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    @State private var lastAction: String = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header du tab
                HStack {
                    Image(systemName: "blinds.horizontal.closed")
                        .font(.title)
                        .foregroundColor(.blue)
                    Text("Volets")
                        .font(.title)
                        .fontWeight(.bold)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top)
                
                LazyVStack(spacing: 15) {
                    ForEach(ShuttersData.roomsOrder, id: \.self) { room in
                        if let shutters = ShuttersData.shutters[room] {
                            ShutterRoomCard(roomName: room, shutters: shutters, lastAction: $lastAction)
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color(.systemGray6).opacity(0.3))
    }
}

struct ShutterRoomCard: View {
    let roomName: String
    let shutters: [ShutterItem]
    @Binding var lastAction: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(roomName)
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 1) {
                ForEach(shutters) { shutter in
                    HStack {
                        Text(shutter.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "2D3748"))
                        
                        Spacer()
                        
                        HStack(spacing: 15) {
                            // Bouton Monter
                            ShutterButton(icon: "arrow.up", color: .blue) {
                                sendCommand(shutter: shutter, value: shutter.upValue, action: "Monter")
                            }
                            
                            // Bouton Stop
                            ShutterButton(icon: "square.fill", color: .gray) {
                                sendCommand(shutter: shutter, value: shutter.stopValue, action: "Stop")
                            }
                            
                            // Bouton Descendre
                            ShutterButton(icon: "arrow.down", color: .blue) {
                                sendCommand(shutter: shutter, value: shutter.downValue, action: "Descendre")
                            }
                        }
                    }
                    .padding()
                    .background(Color.white)
                    
                    if shutter.id != shutters.last?.id {
                        Divider()
                            .padding(.leading)
                    }
                }
            }
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
    
    func sendCommand(shutter: ShutterItem, value: String, action: String) {
        EssensysAPI.shared.sendInjection(k: shutter.activeIndex, v: value) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    lastAction = "\(action) \(shutter.name) envoyé à \(Date())"
                    print("Commande volet envoyée: \(shutter.name) - \(action)")
                case .failure(let error):
                    lastAction = "Erreur: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct ShutterButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1))
                .foregroundColor(color)
                .cornerRadius(8)
        }
    }
}
