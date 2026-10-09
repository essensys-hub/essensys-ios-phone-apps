//
//  ConfigurationView.swift
//  EssensysApp
//
//  Vue de configuration avec gestion de la connexion (local/WAN)
//

import SwiftUI

struct ConfigurationView: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    @State private var isEditing = false
    @State private var localURL: String = ""
    @State private var wanURL: String = ""
    @State private var wanUsername: String = ""
    @State private var wanPassword: String = ""
    @State private var selectedMode: ConnectionMode = .local
    @State private var showingPasswordAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Bannière d'information
                    InfoBanner()
                    
                    // Section Chauffage (à implémenter)
                    //HeatingSection()
                    
                    // Section Configuration Backend
                    BackendConfigSection(
                        isEditing: $isEditing,
                        localURL: $localURL,
                        wanURL: $wanURL,
                        wanUsername: $wanUsername,
                        wanPassword: $wanPassword,
                        selectedMode: $selectedMode,
                        connectionManager: connectionManager
                    )
                    
                    // Section Notifications
                    //NotificationsConfigSection()
                    
                    // Version Footer
                    VStack(spacing: 4) {
                        Text("Essensys iOS")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                }
                .padding()
            }
            .navigationTitle("Configuration")
            .onAppear {
                loadConfig()
            }
        }
    }
    
    private func loadConfig() {
        localURL = connectionManager.config.localURL
        wanURL = connectionManager.config.wanURL
        wanUsername = connectionManager.config.wanUsername
        wanPassword = connectionManager.config.wanPassword
        selectedMode = connectionManager.config.mode
    }
}



struct BackendConfigSection: View {
    @Binding var isEditing: Bool
    @Binding var localURL: String
    @Binding var wanURL: String
    @Binding var wanUsername: String
    @Binding var wanPassword: String
    @Binding var selectedMode: ConnectionMode
    @ObservedObject var connectionManager: ConnectionManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Configuration Backend")
                .font(.headline)
            
            if !isEditing {
                // Mode affichage
                VStack(alignment: .leading, spacing: 8) {
                    Text("URL du backend:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(connectionManager.config.currentURL)
                        .font(.caption)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                    
                    HStack {
                        Text("Mode:")
                            .font(.subheadline)
                        Spacer()
                        
                        Picker("Mode", selection: Binding(
                            get: { selectedMode },
                            set: { newValue in
                                selectedMode = newValue
                                connectionManager.config.mode = newValue
                                connectionManager.saveConfig()
                            }
                        )) {
                            Text("Local").tag(ConnectionMode.local)
                            Text("WAN").tag(ConnectionMode.wan)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 150)
                    }
                    
                    Button("Modifier") {
                        isEditing = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
            } else {
                // Mode édition
                VStack(alignment: .leading, spacing: 12) {
                    // Sélection du mode
                    Picker("Mode de connexion", selection: $selectedMode) {
                        Text("Local (WiFi)").tag(ConnectionMode.local)
                        Text("WAN").tag(ConnectionMode.wan)
                    }
                    .pickerStyle(.segmented)
                    
                    if selectedMode == .local {
                        // Configuration locale
                        VStack(alignment: .leading, spacing: 8) {
                            Text("URL locale:")
                                .font(.subheadline)
                            TextField("http://mon.essensys.fr", text: $localURL)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            
                            Text("Connexion WiFi locale sans mot de passe")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        // Configuration WAN
                        VStack(alignment: .leading, spacing: 8) {
                            Text("URL WAN (DNS):")
                                .font(.subheadline)
                            TextField("https://essensys.example.com", text: $wanURL)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .keyboardType(.URL)
                            
                            Text("Nom d'utilisateur:")
                                .font(.subheadline)
                            TextField("Nom d'utilisateur (Optionnel)", text: $wanUsername)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            
                            Text("Mot de passe:")
                                .font(.subheadline)
                            SecureField("Mot de passe WAN", text: $wanPassword)
                                .textFieldStyle(.roundedBorder)
                            
                            Text("Connexion WAN avec authentification")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Button("Enregistrer") {
                            saveConfig()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        
                        Button("Annuler") {
                            cancelEdit()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            
            // Indicateur de connexion
            HStack {
                Circle()
                    .fill(connectionManager.isConnected ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(connectionManager.isConnected ? "Connecté" : "Déconnecté")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !connectionManager.isConnected {
                    Button("Tester") {
                        connectionManager.testConnection()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private func saveConfig() {
        connectionManager.config.mode = selectedMode
        connectionManager.config.localURL = localURL.isEmpty ? "http://mon.essensys.fr" : localURL
        connectionManager.config.wanURL = wanURL
        connectionManager.config.wanUsername = wanUsername
        connectionManager.config.wanPassword = wanPassword
        connectionManager.saveConfig()
        isEditing = false
    }
    
    private func cancelEdit() {
        localURL = connectionManager.config.localURL
        wanURL = connectionManager.config.wanURL
        wanUsername = connectionManager.config.wanUsername
        wanPassword = connectionManager.config.wanPassword
        selectedMode = connectionManager.config.mode
        isEditing = false
    }
}
/*
struct NotificationsConfigSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notifications")
                .font(.headline)
            
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundColor(.blue)
                Text("Modifier: marc@essensys.fr")
                    .font(.subheadline)
                
                Spacer()
                
                Button("Modifier") {
                    // TODO: Ouvrir la configuration des notifications
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
}
*/
