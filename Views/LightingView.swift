//
//  LightingView.swift
//  EssensysApp
//
//  Vue de contrôle de l'éclairage groupé par pièce
//

import SwiftUI

struct LightingView: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // Persistence de l'ordre des pièces (via UUID strings)
    @AppStorage("LightingView.roomOrder") private var savedRoomOrderString: String = ""
    
    // État local des pièces (pour le reordering)
    @State private var rooms: [RoomLighting] = []
    
    // État d'expansion global (UUID des pièces ouvertes)
    // Par défaut vide = tout fermé
    @State private var expandedRoomIds: Set<UUID> = []
    
    // Mode édition pour le reordering
    @State private var isEditing = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Bannière d'information
                InfoBanner()
                    .padding()
                
                // Contrôles globaux
                HStack {
                    Button("Tout ouvrir") {
                        expandAll()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    
                    Button("Tout fermer") {
                        collapseAll()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    EditButton() // Bouton natif SwiftUI pour activer le mode édition de la liste
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                List {
                    ForEach(rooms) { room in
                        RoomLightingCard(
                            room: room,
                            isExpanded: Binding(
                                get: { expandedRoomIds.contains(room.id) },
                                set: { isExpanded in
                                    if isExpanded {
                                        expandedRoomIds.insert(room.id)
                                    } else {
                                        expandedRoomIds.remove(room.id)
                                    }
                                }
                            ),
                            onError: { error in
                                errorMessage = error
                                showingError = true
                            }
                        )
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                    .onMove(perform: move)
                }
                .listStyle(.plain)
            }
            .navigationTitle("Éclairage")
            .onAppear {
                loadRooms()
            }
            .alert("Erreur", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func loadRooms() {
        let allRooms = LightingData.rooms
        
        if savedRoomOrderString.isEmpty {
            // Premier lancement ou pas de sauvegarde : ordre par défaut (catégorisé si possible, ou juste liste)
            // Ici on va prendre l'ordre par défaut de LightingData mais on pourrait appliquer le tri par catégorie existant avant
            // Pour simplifier et respecter "par défaut", on prend la liste telle quelle,
            // ou on peut pré-trier par catégorie comme avant si l'utilisateur n'a jamais touché.
            // Reprenons le tri par catégorie initial pour la première vue :
            rooms = sortByDefaultCategories(allRooms)
        } else {
            // Charger l'ordre sauvegardé
            let savedIds = savedRoomOrderString.split(separator: ",").map { String($0) }
            
            // Reconstruire la liste dans l'ordre
            var orderedRooms: [RoomLighting] = []
            var remainingRooms = allRooms
            
            for idStr in savedIds {
                if let index = remainingRooms.firstIndex(where: { $0.id.uuidString == idStr }) {
                    orderedRooms.append(remainingRooms[index])
                    remainingRooms.remove(at: index)
                }
            }
            
            // Ajouter les pièces manquantes (nouvelles pièces ajoutées dans le code par ex) à la fin
            orderedRooms.append(contentsOf: remainingRooms)
            rooms = orderedRooms
        }
    }
    
    private func sortByDefaultCategories(_ rooms: [RoomLighting]) -> [RoomLighting] {
        // Logique de tri par catégorie initiale pour avoir une vue propre au premier lancement
        let categoryOrder = ["Chambres", "Bureau", "Salles de bain", "Toilettes", "Annexes", "Escalier", "Autres"]
        var sorted: [RoomLighting] = []
        
        for category in categoryOrder {
            let categoryRooms = rooms.filter { room in
                getCategory(for: room) == category
            }
            sorted.append(contentsOf: categoryRooms)
        }
        
        return sorted
    }
    
    private func getCategory(for room: RoomLighting) -> String {
        if room.roomName.contains("Chambre") { return "Chambres" }
        if room.roomName.contains("Bureau") { return "Bureau" }
        if room.roomName.contains("Bain") { return "Salles de bain" }
        if room.roomName.contains("WC") { return "Toilettes" }
        if room.roomName.contains("Annexe") { return "Annexes" }
        if room.roomName.contains("Escalier") { return "Escalier" }
        return "Autres"
    }
    
    private func saveOrder() {
        let ids = rooms.map { $0.id.uuidString }
        savedRoomOrderString = ids.joined(separator: ",")
    }
    
    private func move(from source: IndexSet, to destination: Int) {
        rooms.move(fromOffsets: source, toOffset: destination)
        saveOrder()
    }
    
    private func expandAll() {
        for room in rooms {
            expandedRoomIds.insert(room.id)
        }
    }
    
    private func collapseAll() {
        expandedRoomIds.removeAll()
    }
}

struct RoomLightingCard: View {
    let room: RoomLighting
    @Binding var isExpanded: Bool
    let onError: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // En-tête de la pièce
            HStack {
                Image(systemName: room.icon)
                    .foregroundColor(.blue)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(room.roomName)
                        .font(.headline)
                    
                    // Afficher le nombre de lampes
                    let totalLights = room.allLights.count
                    if totalLights > 0 {
                        Text("\(totalLights) lampe\(totalLights > 1 ? "s" : "")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Boutons groupe
                if !room.directLights.isEmpty || !room.indirectLights.isEmpty {
                    Button(action: {
                        turnOnAll()
                    }) {
                        Image(systemName: "sun.max.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.small)
                    
                    Button(action: {
                        turnOffAll()
                    }) {
                        Image(systemName: "moon.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Button(action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                        .padding(8)
                        .background(Color.white.opacity(0.5)) // Zone de touche augmentée avec fond léger
                        .clipShape(Circle())
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            // Tap gesture sur l'entête pour toggle (sauf sur les boutons)
            .onTapGesture {
                withAnimation {
                    isExpanded.toggle()
                }
            }
            
            // Détails (si expandé)
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // Lumières directes
                    if !room.directLights.isEmpty {
                        Text("Directes")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        ForEach(room.directLights) { light in
                            LightingItemRow(light: light, onError: onError)
                        }
                    }
                    
                    // Lumières indirectes
                    if !room.indirectLights.isEmpty {
                        Text("Indirectes")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.top, room.directLights.isEmpty ? 0 : 12)
                        
                        ForEach(room.indirectLights) { light in
                            LightingItemRow(light: light, onError: onError)
                        }
                    }
                }
                .padding(.leading)
            }
        }
        .padding(.vertical, 4)
    }
    
    // ... turnOnAll and turnOffAll logic remains same, but we need to copy implementation
    private func turnOnAll() {
        let allLights = room.allLights
        let group = DispatchGroup()
        var lastError: Error?
        
        for light in allLights {
            group.enter()
            EssensysAPI.shared.sendInjection(k: light.onIndex, v: light.value) { result in
                if case .failure(let error) = result {
                    lastError = error
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if let error = lastError {
                onError(error.localizedDescription)
            }
        }
    }
    
    private func turnOffAll() {
        let allLights = room.allLights
        let group = DispatchGroup()
        var lastError: Error?
        
        for light in allLights {
            group.enter()
            EssensysAPI.shared.sendInjection(k: light.offIndex, v: light.value) { result in
                if case .failure(let error) = result {
                    lastError = error
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if let error = lastError {
                onError(error.localizedDescription)
            }
        }
    }
}

struct LightingItemRow: View {
    let light: LightingItem
    let onError: (String) -> Void
    @State private var isOperating = false
    
    var body: some View {
        HStack {
            Image(systemName: light.isIndirect ? "lightbulb.2.fill" : "lightbulb.fill")
                .foregroundColor(light.isIndirect ? .orange : .yellow)
                .frame(width: 20)
            
            Text(light.name)
                .font(.body)
            
            Spacer()
            
            Button(action: {
                turnOn()
            }) {
                Image(systemName: "sun.max.fill")
                Text("On")
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.small)
            .disabled(isOperating)
            
            Button(action: {
                turnOff()
            }) {
                Image(systemName: "moon.fill")
                Text("Off")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isOperating)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray5))
        .cornerRadius(8)
    }
    
    private func turnOn() {
        isOperating = true
        EssensysAPI.shared.sendInjection(k: light.onIndex, v: light.value) { result in
            DispatchQueue.main.async {
                isOperating = false
                switch result {
                case .success:
                    break
                case .failure(let error):
                    onError(error.localizedDescription)
                }
            }
        }
    }
    
    private func turnOff() {
        isOperating = true
        EssensysAPI.shared.sendInjection(k: light.offIndex, v: light.value) { result in
            DispatchQueue.main.async {
                isOperating = false
                switch result {
                case .success:
                    break
                case .failure(let error):
                    onError(error.localizedDescription)
                }
            }
        }
    }
}




// MARK: - Merged Models (from LightingModels.swift)

struct LightingItem: Identifiable {
    let id = UUID()
    let name: String
    let onIndex: Int
    let offIndex: Int
    let value: String
    let isIndirect: Bool
}

struct RoomLighting: Identifiable {
    let id = UUID()
    let roomName: String
    let icon: String
    var directLights: [LightingItem]
    var indirectLights: [LightingItem]
    
    var allLights: [LightingItem] {
        directLights + indirectLights
    }
}

// Données des lumières basées sur le frontend Essensys
struct LightingData {
    static let rooms: [RoomLighting] = [
        // Autres pièces (Salon, Cuisine, etc.)
        RoomLighting(
            roomName: "Salon",
            icon: "sofa.fill",
            directLights: [
                LightingItem(name: "Salon", onIndex: 612, offIndex: 606, value: "128", isIndirect: false)
            ],
            indirectLights: [
                LightingItem(name: "Indirect 1", onIndex: 611, offIndex: 605, value: "2", isIndirect: true),
                LightingItem(name: "Indirect 2", onIndex: 611, offIndex: 605, value: "4", isIndirect: true)
            ]
        ),
        
        // Chambres
        // Chambres
        RoomLighting(
            roomName: "Grande Chambre",
            icon: "bed.double.fill",
            directLights: [
                LightingItem(name: "Grande Chambre", onIndex: 614, offIndex: 608, value: "128", isIndirect: false)
            ],
            indirectLights: [
                LightingItem(name: "Chevet 1", onIndex: 613, offIndex: 607, value: "2", isIndirect: true),
                LightingItem(name: "Chevet 2", onIndex: 613, offIndex: 607, value: "4", isIndirect: true)
            ]
        ),
        RoomLighting(
            roomName: "Petite Chambre 1",
            icon: "bed.double.fill",
            directLights: [
                LightingItem(name: "Petite Chambre 1", onIndex: 614, offIndex: 608, value: "64", isIndirect: false)
            ],
            indirectLights: [
                LightingItem(name: "Chevet 1", onIndex: 613, offIndex: 607, value: "8", isIndirect: true),
                LightingItem(name: "Chevet 2", onIndex: 613, offIndex: 607, value: "16", isIndirect: true)
            ]
        ),
        RoomLighting(
            roomName: "Petite Chambre 2",
            icon: "bed.double.fill",
            directLights: [
                LightingItem(name: "Petite Chambre 2", onIndex: 614, offIndex: 608, value: "32", isIndirect: false)
            ],
            indirectLights: [
                LightingItem(name: "Chevet", onIndex: 613, offIndex: 607, value: "32", isIndirect: true)
            ]
        ),
        RoomLighting(
            roomName: "Petite Chambre 3",
            icon: "bed.double.fill",
            directLights: [
                LightingItem(name: "Petite Chambre 3", onIndex: 614, offIndex: 608, value: "16", isIndirect: false)
            ],
            indirectLights: [
                LightingItem(name: "Chevet", onIndex: 613, offIndex: 607, value: "64", isIndirect: true)
            ]
        ),
        
        // Bureau
        RoomLighting(
            roomName: "Bureau",
            icon: "desktopcomputer",
            directLights: [
                LightingItem(name: "Bureau", onIndex: 612, offIndex: 606, value: "32", isIndirect: false)
            ],
            indirectLights: []
        ),
        
        // Salles de bain
        RoomLighting(
            roomName: "Salle de Bain 1",
            icon: "shower.fill",
            directLights: [
                LightingItem(name: "Salle de Bain 1", onIndex: 616, offIndex: 610, value: "128", isIndirect: false)
            ],
            indirectLights: [
                LightingItem(name: "Miroir", onIndex: 615, offIndex: 609, value: "4", isIndirect: true)
            ]
        ),
        RoomLighting(
            roomName: "Salle de Bain 2",
            icon: "shower.fill",
            directLights: [
                LightingItem(name: "Salle de Bain 2", onIndex: 615, offIndex: 609, value: "8", isIndirect: false)
            ],
            indirectLights: [
                LightingItem(name: "Miroir", onIndex: 615, offIndex: 609, value: "16", isIndirect: true)
            ]
        ),
        
        // Toilettes
        RoomLighting(
            roomName: "WC 1",
            icon: "toilet.fill",
            directLights: [
                LightingItem(name: "WC 1", onIndex: 615, offIndex: 609, value: "32", isIndirect: false)
            ],
            indirectLights: []
        ),
        RoomLighting(
            roomName: "WC 2",
            icon: "toilet.fill",
            directLights: [
                LightingItem(name: "WC 2", onIndex: 615, offIndex: 609, value: "64", isIndirect: false)
            ],
            indirectLights: []
        ),
        
        // Annexes
        RoomLighting(
            roomName: "Annexe 1",
            icon: "door.left.hand.open",
            directLights: [
                LightingItem(name: "Annexe 1", onIndex: 616, offIndex: 610, value: "8", isIndirect: false)
            ],
            indirectLights: []
        ),
        RoomLighting(
            roomName: "Annexe 2",
            icon: "door.left.hand.open",
            directLights: [
                LightingItem(name: "Annexe 2", onIndex: 616, offIndex: 610, value: "16", isIndirect: false)
            ],
            indirectLights: []
        ),
        
        // Escalier
        RoomLighting(
            roomName: "Escalier",
            icon: "stairs",
            directLights: [
                LightingItem(name: "Escalier", onIndex: 613, offIndex: 607, value: "1", isIndirect: false)
            ],
            indirectLights: []
        ),
        

        RoomLighting(
            roomName: "Salle à Manger",
            icon: "fork.knife",
            directLights: [
                LightingItem(name: "Salle à Manger", onIndex: 612, offIndex: 606, value: "64", isIndirect: false)
            ],
            indirectLights: []
        ),
        RoomLighting(
            roomName: "Cuisine",
            icon: "cooktop.fill",
            directLights: [
                LightingItem(name: "Cuisine", onIndex: 615, offIndex: 609, value: "1", isIndirect: false)
            ],
            indirectLights: [
                LightingItem(name: "Plans de travail", onIndex: 615, offIndex: 609, value: "2", isIndirect: true)
            ]
        ),
        RoomLighting(
            roomName: "Entrée",
            icon: "door.garage.closed",
            directLights: [
                LightingItem(name: "Entrée", onIndex: 611, offIndex: 605, value: "1", isIndirect: false)
            ],
            indirectLights: []
        ),
        RoomLighting(
            roomName: "Dégagement 1",
            icon: "rectangle.3.group.fill",
            directLights: [
                LightingItem(name: "Dégagement 1", onIndex: 616, offIndex: 610, value: "1", isIndirect: false)
            ],
            indirectLights: []
        ),
        RoomLighting(
            roomName: "Dégagement 2",
            icon: "rectangle.3.group.fill",
            directLights: [
                LightingItem(name: "Dégagement 2", onIndex: 616, offIndex: 610, value: "2", isIndirect: false)
            ],
            indirectLights: []
        ),
        RoomLighting(
            roomName: "Dressing",
            icon: "tshirt.fill",
            directLights: [
                LightingItem(name: "Dressing", onIndex: 611, offIndex: 605, value: "8", isIndirect: false)
            ],
            indirectLights: [
                LightingItem(name: "Placards", onIndex: 611, offIndex: 605, value: "16", isIndirect: true)
            ]
        ),
        RoomLighting(
            roomName: "Pièce de service",
            icon: "wrench.and.screwdriver.fill",
            directLights: [
                LightingItem(name: "Pièce de service", onIndex: 615, offIndex: 609, value: "128", isIndirect: false)
            ],
            indirectLights: []
        ),
        RoomLighting(
            roomName: "Terrasse",
            icon: "sun.max.fill",
            directLights: [
                LightingItem(name: "Terrasse", onIndex: 616, offIndex: 610, value: "4", isIndirect: false)
            ],
            indirectLights: []
        )
    ]
}
