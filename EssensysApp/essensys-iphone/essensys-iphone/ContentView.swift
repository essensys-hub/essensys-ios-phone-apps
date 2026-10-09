//
//  ContentView.swift
//  essensys-iphone
//
//  Created by Nicolas Rineau on 03/01/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var connectionManager: ConnectionManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Header Tab Bar
            CustomHeaderView(selectedTab: $selectedTab)
            
            // Content
            ZStack {
                switch selectedTab {
                case 0:
                    HomeView()
                case 1:
                    LightingView()
                case 2:
                    ShuttersView()
                case 3:
                    HeatingView()
                case 4:
                    AlarmView()
                case 5:
                    WateringView()
                case 6:
                    ConfigurationView()
                default:
                    HomeView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Background color slightly gray to match dashboard look
            .background(Color(.systemGray6).opacity(0.3))
            
            Spacer(minLength: 0)
        }
        .edgesIgnoringSafeArea(.bottom) // Full screen feel
        .overlay(alignment: .bottom) {
            // Error banner overlay at bottom instead of top
            if let error = connectionManager.connectionError {
                VStack {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.white)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
        }
    }
}

// MARK: - Merged SharedComponents (from SharedComponents.swift)

struct InfoBanner: View {
    var body: some View {
        HStack {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
            Text("Essensys fonctionne en boucle ouverte : les équipements ne remontent pas leur état.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

struct NotificationsSection: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Notifications")
                    .font(.headline)
                Text("10 notifications pour ce mois")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
            
            Button("Modifier") {
                // TODO: Ouvrir les notifications
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct PreviousActionsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(.blue)
                Text("http://mon.essensys.fr envoi hier à DEV")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("Précédente : Ordre < Activer Départ - envoyé hier à 21:48")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(.blue)
                Text("http://mon.essensys.fr")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Actif") {
                    // TODO: Gérer l'état actif
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            
            Text("Précédente.....En cours de DEV")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.blue)
                Text("Précédente : Ordre < Activer Départ - envoyé hier à 21:48")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}


// MARK: - Heating Component

struct HeatingSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chauffage")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 15) {
                Text("Zones de Chauffage")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(alignment: .center, spacing: 15) {
                    Text("19°")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(Color(hex: "4A5568"))
                    
                    // Barre de progression (représentation simplifiée)
                    HStack(spacing: 4) {
                        ForEach(0..<6) { index in
                            Rectangle()
                                .fill(index < 3 ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2))
                                .frame(width: 40, height: 6)
                        }
                    }
                }
                
                Text("Zone Jour : 7h00 - 21h00 - Température cible à maintenir")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "thermometer")
                        .foregroundColor(.teal)
                    Text("Pendant la zone Jour :")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("10.4 ?")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(15)
                }
                 
                Text("Précédente : Ordre < Activer Départ - envoyé hier à 21:48")
                    .font(.caption2)
                    .foregroundColor(Color.gray.opacity(0.6))
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
}

// MARK: - Indirect Lights Component

struct IndirectLightsSection: View {
    let roomsWithIndirect: [RoomLighting] = LightingData.rooms.filter { !$0.indirectLights.isEmpty }
    
    // Pour l'affichage "preview", on ne prend que quelques pièces
    let previewRooms: [RoomLighting] = {
        let all = LightingData.rooms.filter { !$0.indirectLights.isEmpty }
        // On prend Salon, Cuisine, SDB, Chambres comme dans le screen
        return all.filter { room in
            ["Salon", "Cuisine", "Salle de Bain 1", "Grande Chambre", "Petite Chambre 1"].contains(room.roomName)
        }
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Éclairage Indirects")
                .font(.headline)
            
            VStack(spacing: 1) {
                ForEach(previewRooms) { room in
                    HStack {
                        Text(room.roomName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "2D3748"))
                        
                        if room.roomName == "Salle de Bain 1" {
                            Text("(Éclairage miroir)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if room.roomName == "Salle de Bain 1" {
                            // Style "Link"
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray.opacity(0.5))
                        } else {
                            // Boutons
                            HStack(spacing: 8) {
                                Button(action: {}) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "sun.max.fill")
                                            .font(.caption2)
                                        Text("Allumer")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.yellow.opacity(0.2)) // Couleur à ajuster
                                    .foregroundColor(.orange) // Couleur à ajuster
                                    .cornerRadius(6)
                                }
                                
                                Button(action: {}) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "moon.fill")
                                            .font(.caption2)
                                        Text("Éteindre")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(hex: "E2E8F0"))
                                    .foregroundColor(Color(hex: "4A5568"))
                                    .cornerRadius(6)
                                }
                            }
                        }
                        
                        if room.roomName != "Salle de Bain 1" {
                             Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray.opacity(0.3))
                                .padding(.leading, 8)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    
                    if room.id != previewRooms.last?.id {
                        Divider()
                            .padding(.leading)
                    }
                }
            }
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
}

// MARK: - Configuration Summary Component

struct ConfigurationSummaryView: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                Text("Configuration")
                    .font(.headline)
            }
            .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 15) {
                Text("Configuration Backend")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("URL du backend: \(connectionManager.config.currentURL)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    HStack {
                        Text("Mode: \(connectionManager.config.mode == .local ? "Local" : "WAN")")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(connectionManager.config.mode == .local ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                            .foregroundColor(connectionManager.config.mode == .local ? .green : .blue)
                            .cornerRadius(4)
                        
                        Spacer()
                        
                        Button("Basculer \(connectionManager.config.mode == .local ? "WAN" : "Local")") {
                            let newMode: ConnectionMode = connectionManager.config.mode == .local ? .wan : .local
                            connectionManager.config.mode = newMode
                            connectionManager.saveConfig()
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notifications")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(.blue)
                        Text("Modifier: marc@essensys.fr")
                            .font(.caption)
                        
                        Spacer()
                        
                        Button("Modifier") {}
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
}

// MARK: - Custom Header Component

struct CustomHeaderView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var connectionManager: ConnectionManager
    
    let tabs = ["Accueil", "Éclairage", "Volets", "Chauffage", "Alarme", "Arrosage", "Configuration"]
    
    var body: some View {
        VStack(spacing: 15) {
            HStack(spacing: 15) {
                // Logo / Brand
                Menu {
                    Button(action: {
                        connectionManager.config.mode = .local
                        connectionManager.saveConfig()
                    }) {
                        Label("Essensys Local", systemImage: "network")
                    }
                    
                    Button(action: {
                        connectionManager.config.mode = .wan
                        connectionManager.saveConfig()
                    }) {
                        Label("Essensys WAN", systemImage: "globe")
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: connectionManager.isDemoMode ? "play.rectangle.fill" : (connectionManager.config.mode == .local ? "wifi" : "globe"))
                            .font(.title2)
                            .foregroundColor(connectionManager.isDemoMode ? .red : (connectionManager.config.mode == .local ? .green : .blue))
                        Text("Essensys")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(Color(hex: "2D3748"))
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                // Tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(0..<tabs.count, id: \.self) { index in
                            Button(action: {
                                withAnimation {
                                    selectedTab = index
                                }
                            }) {
                                Text(tabs[index])
                                    .font(.subheadline)
                                    .fontWeight(selectedTab == index ? .bold : .regular)
                                    .foregroundColor(selectedTab == index ? .blue : .gray)
                                    .padding(.bottom, 4)
                                    .padding(.horizontal, 4)
                                    .overlay(
                                        Rectangle()
                                            .frame(height: 2)
                                            .foregroundColor(selectedTab == index ? .blue : .clear)
                                            .offset(y: 4)
                                        , alignment: .bottom
                                    )
                                    .fixedSize()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
            Divider()
        }
        .background(Color.white)
    }
}

// Extension pour gérer les couleurs Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(ConnectionManager.shared)
}
