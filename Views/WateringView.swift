//
//  WateringView.swift
//  EssensysApp
//
//  Vue de pilotage de l'arrosage.
//

import SwiftUI

enum WateringMode: String, CaseIterable, Identifiable, Codable {
    case auto = "Automatique (planning)"
    case force15 = "Forçage arrosage 15 minutes"
    case force30 = "Forçage arrosage 30 minutes"
    case force60 = "Forçage arrosage 1 heure"
    case off = "OFF"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .auto: return "calendar.badge.clock"
        case .force15: return "drop.circle" // or "15.circle"
        case .force30: return "drop.circle.fill"
        case .force60: return "cloud.rain.fill"
        case .off: return "power.circle"
        }
    }
    
    var label: String {
        switch self {
        case .auto: return "Auto"
        case .force15: return "15 min"
        case .force30: return "30 min"
        case .force60: return "1h"
        case .off: return "OFF"
        }
    }
}

struct WateringButton: View {
    let mode: WateringMode
    let currentMode: WateringMode
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.system(size: 24))
                Text(mode.label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(currentMode == mode ? Color.blue.opacity(0.15) : Color.white)
            .foregroundColor(currentMode == mode ? .blue : .gray)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(currentMode == mode ? Color.blue : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

struct WateringView: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    @State private var selectedMode: WateringMode = .off
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Info Banner
                    InfoBanner()
                    
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Arrosage")
                            .font(.headline)
                            .foregroundColor(Color(hex: "2D3748"))
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            // Row 1: Auto and OFF
                            HStack(spacing: 12) {
                                WateringButton(mode: .auto, currentMode: selectedMode) { setMode(.auto) }
                                WateringButton(mode: .off, currentMode: selectedMode) { setMode(.off) }
                            }
                            
                            Divider()
                                .padding(.vertical, 4)
                            
                            Text("Forçage")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                            
                            // Row 2: Forcings
                            HStack(spacing: 12) {
                                WateringButton(mode: .force15, currentMode: selectedMode) { setMode(.force15) }
                                WateringButton(mode: .force30, currentMode: selectedMode) { setMode(.force30) }
                                WateringButton(mode: .force60, currentMode: selectedMode) { setMode(.force60) }
                            }
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    
                    Spacer()
                }
                .padding()
            }
            .background(Color(.systemGray6).opacity(0.3))
            .navigationTitle("Arrosage")
            .alert("Erreur", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func setMode(_ mode: WateringMode) {
        selectedMode = mode
        
        if ConnectionManager.shared.isDemoMode {
            // Nothing more to do
        } else {
            // TODO: Implémenter l'appel API réel ici
            // ex: EssensysAPI.shared.sendInjection(...)
        }
    }
}
