//
//  HomeView.swift
//  EssensysApp
//
//  Vue d'accueil avec les scènes d'éclairage
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var searchText = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Info Banner
                InfoBanner()
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Recherche...", text: $searchText)
                    Image(systemName: "mic")
                        .foregroundColor(.gray)
                    Image(systemName: "text.viewfinder")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                // Scènes d'éclairage
                LightingScenesSection()
                
                // Éclairage Indirects
                IndirectLightsSection()
                
                // Chauffage (Aperçu Dashboard)
                HeatingSection()
                
                // Configuration (Aperçu Dashboard)
                ConfigurationSummaryView()
                
                // Notifications
                NotificationsSection()
                
                // Dernière action
                LastActionSection()
            }
            .padding()
        }
        .alert("Erreur", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
}


struct LightingScenesSection: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    @State private var showingError = false
    @State private var errorMessage = ""
    
    let scenes: [LightingScene] = [
        LightingScene(
            id: "reveil",
            name: "Réveil",
            icon: "sun.max.fill",
            description: "Allume : Cuisine, Salon indirect 1",
            actions: [(k: 616, v: "4"), (k: 617, v: "4")]
        ),
        LightingScene(
            id: "soiree",
            name: "Soirée",
            icon: "sofa.fill",
            description: "Allume : Salon indirect 1 & 2",
            actions: [(k: 617, v: "4"), (k: 618, v: "4")]
        ),
        LightingScene(
            id: "nuit",
            name: "Nuit",
            icon: "moon.fill",
            description: "Éteint : tout",
            actions: [(k: 610, v: "4")]
        ),
        LightingScene(
            id: "depart",
            name: "Départ",
            icon: "door.left.hand.open",
            description: "Éteint : tout sauf le couloir",
            actions: [(k: 610, v: "4"), (k: 619, v: "4")]
        )
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scènes d'éclairage")
                .font(.headline)
            
            Text("Ces actions envoient des ordres. L'état réel des lumières n'est pas connu.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ForEach(scenes) { scene in
                LightingSceneRow(scene: scene) { error in
                    errorMessage = error
                    showingError = true
                }
            }
        }
        .alert("Erreur", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
}

struct LightingScene: Identifiable {
    let id: String
    let name: String
    let icon: String
    let description: String
    let actions: [(k: Int, v: String)]
}

struct LightingSceneRow: View {
    let scene: LightingScene
    let onError: (String) -> Void
    @State private var isActivating = false
    
    var body: some View {
        HStack {
            Image(systemName: scene.icon)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(scene.name)
                    .font(.body)
                    .fontWeight(.medium)
                Text(scene.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                activateScene()
            }) {
                if isActivating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Allumer")
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(isActivating)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private func activateScene() {
        isActivating = true
        
        let group = DispatchGroup()
        var lastError: Error?
        
        for action in scene.actions {
            group.enter()
            EssensysAPI.shared.sendInjection(k: action.k, v: action.v) { result in
                switch result {
                case .success:
                    break
                case .failure(let error):
                    lastError = error
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            isActivating = false
            if let error = lastError {
                onError(error.localizedDescription)
            }
        }
    }
}


struct LastActionSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(.blue)
                Text("http://mon.essensys.fr")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("Dernière action envoyée. > error code < 4:222")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

