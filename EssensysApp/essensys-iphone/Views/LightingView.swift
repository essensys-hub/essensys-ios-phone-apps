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
    
    // Persistence des noms personnalisés (JSON String [ID: Name])
    @AppStorage("LightingView.customNames") private var savedCustomNamesString: String = "{}"
    
    // État local des pièces (pour le reordering et renaming)
    @State private var rooms: [RoomLighting] = []
    
    // État d'expansion global (UUID des pièces ouvertes)
    // Par défaut vide = tout fermé
    @State private var expandedRoomIds: Set<String> = [] // IDs are Strings now
    
    // Mode édition pour le reordering et renaming
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
                    
                    EditButton() // Bouton natif SwiftUI pour activer le mode édition
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                List {
                    ForEach($rooms) { $room in
                        RoomLightingCard(
                            room: $room,
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
            // Sauvegarder les noms si modifications
            .onChangeCompat(of: rooms) { _ in
                saveCustomNames()
            }
            .alert("Erreur", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func loadRooms() {
        var allRooms = LightingData.rooms
        
        // 1. Charger et appliquer les noms personnalisés
        if let data = savedCustomNamesString.data(using: .utf8),
           let customNames = try? JSONDecoder().decode([String: String].self, from: data) {
            
            for i in 0..<allRooms.count {
                if let customRoomName = customNames[allRooms[i].id] {
                    allRooms[i].roomName = customRoomName
                }
                
                for j in 0..<allRooms[i].directLights.count {
                    if let customLightName = customNames[allRooms[i].directLights[j].id] {
                        allRooms[i].directLights[j].name = customLightName
                    }
                }
                
                for k in 0..<allRooms[i].indirectLights.count {
                    if let customLightName = customNames[allRooms[i].indirectLights[k].id] {
                        allRooms[i].indirectLights[k].name = customLightName
                    }
                }
            }
        }
        
        // 2. Appliquer l'ordre sauvegardé
        if savedRoomOrderString.isEmpty {
            rooms = sortByDefaultCategories(allRooms)
        } else {
            let savedIds = savedRoomOrderString.split(separator: ",").map { String($0) }
            var orderedRooms: [RoomLighting] = []
            var remainingRooms = allRooms
            
            for idStr in savedIds {
                if let index = remainingRooms.firstIndex(where: { $0.id == idStr }) {
                    orderedRooms.append(remainingRooms[index])
                    remainingRooms.remove(at: index)
                }
            }
            orderedRooms.append(contentsOf: remainingRooms)
            rooms = orderedRooms
        }
    }
    
    private func sortByDefaultCategories(_ rooms: [RoomLighting]) -> [RoomLighting] {
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
        let ids = rooms.map { $0.id }
        savedRoomOrderString = ids.joined(separator: ",")
    }
    
    private func saveCustomNames() {
        var names: [String: String] = [:]
        for room in rooms {
            names[room.id] = room.roomName
            for light in room.allLights {
                names[light.id] = light.name
            }
        }
        
        if let data = try? JSONEncoder().encode(names),
           let string = String(data: data, encoding: .utf8) {
            savedCustomNamesString = string
        }
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
    @Binding var room: RoomLighting
    @Binding var isExpanded: Bool
    let onError: (String) -> Void
    
    @Environment(\.editMode) var editMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // En-tête de la pièce
            HStack {
                Image(systemName: room.icon)
                    .foregroundColor(.blue)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    if editMode?.wrappedValue == .active {
                        TextField("Nom de la pièce", text: $room.roomName)
                            .textFieldStyle(.roundedBorder)
                            .font(.headline)
                    } else {
                        Text(room.roomName)
                            .font(.headline)
                    }
                    
                    // Afficher le nombre de lampes
                    let totalLights = room.allLights.count
                    if totalLights > 0 {
                        Text("\(totalLights) lampe\(totalLights > 1 ? "s" : "")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Boutons groupe (cachés en mode édition pour clarté)
                if editMode?.wrappedValue != .active {
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
                }
                
                Button(action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                        .padding(8)
                        .background(Color.white.opacity(0.5))
                        .clipShape(Circle())
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .onTapGesture {
                if editMode?.wrappedValue != .active {
                    withAnimation {
                        isExpanded.toggle()
                    }
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
                        
                        ForEach($room.directLights) { $light in
                            LightingItemRow(light: $light, onError: onError)
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
                        
                        ForEach($room.indirectLights) { $light in
                            LightingItemRow(light: $light, onError: onError)
                        }
                    }
                }
                .padding(.leading)
            }
        }
        .padding(.vertical, 4)
    }
    
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
    @Binding var light: LightingItem
    let onError: (String) -> Void
    @State private var isOperating = false
    @State private var isCooldown = false
    @Environment(\.editMode) var editMode
    
    var body: some View {
        HStack {
            Image(systemName: light.isIndirect ? "lightbulb.2.fill" : "lightbulb.fill")
                .foregroundColor(light.isIndirect ? .orange : .yellow)
                .frame(width: 20)
            
            if editMode?.wrappedValue == .active {
                TextField("Nom de la lampe", text: $light.name)
                    .textFieldStyle(.roundedBorder)
            } else {
                Text(light.name)
                    .font(.body)
            }
            
            Spacer()
            
            if editMode?.wrappedValue != .active {
                Button(action: {
                    turnOn()
                }) {
                    Image(systemName: "sun.max.fill")
                    Text("On")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.small)
                .disabled(isOperating || isCooldown)
                .opacity(isCooldown ? 0.6 : 1.0)
                
                Button(action: {
                    turnOff()
                }) {
                    Image(systemName: "moon.fill")
                    Text("Off")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isOperating || isCooldown)
                .opacity(isCooldown ? 0.6 : 1.0)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray5))
        .cornerRadius(8)
    }
    
    private func turnOn() {
        startCooldown()
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
        startCooldown()
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
    
    private func startCooldown() {
        isCooldown = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            isCooldown = false
        }
    }
}




// MARK: - Merged Models (from LightingModels.swift)

struct LightingItem: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    let onIndex: Int
    let offIndex: Int
    let value: String
    let isIndirect: Bool
}

struct RoomLighting: Identifiable, Codable, Equatable {
    let id: String
    var roomName: String
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
            id: "room_salon",
            roomName: "Salon",
            icon: "sofa.fill",
            directLights: [
                LightingItem(id: "light_salon_direct", name: "Salon", onIndex: 612, offIndex: 606, value: "128", isIndirect: false)
            ],
            indirectLights: [
                LightingItem(id: "light_salon_indirect_1", name: "Indirect 1", onIndex: 611, offIndex: 605, value: "2", isIndirect: true),
                LightingItem(id: "light_salon_indirect_2", name: "Indirect 2", onIndex: 611, offIndex: 605, value: "4", isIndirect: true)
            ]
        ),
        
        // Chambres
        RoomLighting(
            id: "room_chambre_grande",
            roomName: "Grande Chambre",
            icon: "bed.double.fill",
            directLights: [
                LightingItem(id: "light_chambre_grande_direct", name: "Grande Chambre", onIndex: 614, offIndex: 608, value: "128", isIndirect: false)
            ],
            indirectLights: [
                LightingItem(id: "light_chambre_grande_chevet_1", name: "Chevet 1", onIndex: 613, offIndex: 607, value: "2", isIndirect: true),
                LightingItem(id: "light_chambre_grande_chevet_2", name: "Chevet 2", onIndex: 613, offIndex: 607, value: "4", isIndirect: true)
            ]
        ),
        RoomLighting(
            id: "room_chambre_petite_1",
            roomName: "Petite Chambre 1",
            icon: "bed.double.fill",
            directLights: [
                LightingItem(id: "light_chambre_petite_1_direct", name: "Petite Chambre 1", onIndex: 614, offIndex: 608, value: "64", isIndirect: false)
            ],
            indirectLights: [
                LightingItem(id: "light_chambre_petite_1_chevet_1", name: "Chevet 1", onIndex: 613, offIndex: 607, value: "8", isIndirect: true),
                LightingItem(id: "light_chambre_petite_1_chevet_2", name: "Chevet 2", onIndex: 613, offIndex: 607, value: "16", isIndirect: true)
            ]
        ),
        RoomLighting(
            id: "room_chambre_petite_2",
            roomName: "Petite Chambre 2",
            icon: "bed.double.fill",
            directLights: [
                LightingItem(id: "light_chambre_petite_2_direct", name: "Petite Chambre 2", onIndex: 614, offIndex: 608, value: "32", isIndirect: false)
            ],
            indirectLights: [
                LightingItem(id: "light_chambre_petite_2_chevet", name: "Chevet", onIndex: 613, offIndex: 607, value: "32", isIndirect: true)
            ]
        ),
        RoomLighting(
            id: "room_chambre_petite_3",
            roomName: "Petite Chambre 3",
            icon: "bed.double.fill",
            directLights: [
                LightingItem(id: "light_chambre_petite_3_direct", name: "Petite Chambre 3", onIndex: 614, offIndex: 608, value: "16", isIndirect: false)
            ],
            indirectLights: [
                LightingItem(id: "light_chambre_petite_3_chevet", name: "Chevet", onIndex: 613, offIndex: 607, value: "64", isIndirect: true)
            ]
        ),
        
        // Bureau
        RoomLighting(
            id: "room_bureau",
            roomName: "Bureau",
            icon: "desktopcomputer",
            directLights: [
                LightingItem(id: "light_bureau_direct", name: "Bureau", onIndex: 612, offIndex: 606, value: "32", isIndirect: false)
            ],
            indirectLights: []
        ),
        
        // Salles de bain
        RoomLighting(
            id: "room_sdb_1",
            roomName: "Salle de Bain 1",
            icon: "shower.fill",
            directLights: [
                LightingItem(id: "light_sdb_1_direct", name: "Salle de Bain 1", onIndex: 616, offIndex: 610, value: "128", isIndirect: false)
            ],
            indirectLights: [
                LightingItem(id: "light_sdb_1_miroir", name: "Miroir", onIndex: 615, offIndex: 609, value: "4", isIndirect: true)
            ]
        ),
        RoomLighting(
            id: "room_sdb_2",
            roomName: "Salle de Bain 2",
            icon: "shower.fill",
            directLights: [
                LightingItem(id: "light_sdb_2_direct", name: "Salle de Bain 2", onIndex: 615, offIndex: 609, value: "8", isIndirect: false)
            ],
            indirectLights: [
                LightingItem(id: "light_sdb_2_miroir", name: "Miroir", onIndex: 615, offIndex: 609, value: "16", isIndirect: true)
            ]
        ),
        
        // Toilettes
        RoomLighting(
            id: "room_wc_1",
            roomName: "WC 1",
            icon: "toilet.fill",
            directLights: [
                LightingItem(id: "light_wc_1_direct", name: "WC 1", onIndex: 615, offIndex: 609, value: "32", isIndirect: false)
            ],
            indirectLights: []
        ),
        RoomLighting(
            id: "room_wc_2",
            roomName: "WC 2",
            icon: "toilet.fill",
            directLights: [
                LightingItem(id: "light_wc_2_direct", name: "WC 2", onIndex: 615, offIndex: 609, value: "64", isIndirect: false)
            ],
            indirectLights: []
        ),
        
        // Annexes
        RoomLighting(
            id: "room_annexe_1",
            roomName: "Annexe 1",
            icon: "door.left.hand.open",
            directLights: [
                LightingItem(id: "light_annexe_1_direct", name: "Annexe 1", onIndex: 616, offIndex: 610, value: "8", isIndirect: false)
            ],
            indirectLights: []
        ),
        RoomLighting(
            id: "room_annexe_2",
            roomName: "Annexe 2",
            icon: "door.left.hand.open",
            directLights: [
                LightingItem(id: "light_annexe_2_direct", name: "Annexe 2", onIndex: 616, offIndex: 610, value: "16", isIndirect: false)
            ],
            indirectLights: []
        ),
        
        // Escalier
        RoomLighting(
            id: "room_escalier",
            roomName: "Escalier",
            icon: "stairs",
            directLights: [
                LightingItem(id: "light_escalier_direct", name: "Escalier", onIndex: 613, offIndex: 607, value: "1", isIndirect: false)
            ],
            indirectLights: []
        ),
        
        RoomLighting(
            id: "room_salle_a_manger",
            roomName: "Salle à Manger",
            icon: "fork.knife",
            directLights: [
                LightingItem(id: "light_salle_a_manger_direct", name: "Salle à Manger", onIndex: 612, offIndex: 606, value: "64", isIndirect: false)
            ],
            indirectLights: []
        ),
        RoomLighting(
            id: "room_cuisine",
            roomName: "Cuisine",
            icon: "cooktop.fill",
            directLights: [
                LightingItem(id: "light_cuisine_direct", name: "Cuisine", onIndex: 615, offIndex: 609, value: "1", isIndirect: false)
            ],
            indirectLights: [
                LightingItem(id: "light_cuisine_plans", name: "Plans de travail", onIndex: 615, offIndex: 609, value: "2", isIndirect: true)
            ]
        ),
        RoomLighting(
            id: "room_entree",
            roomName: "Entrée",
            icon: "door.garage.closed",
            directLights: [
                LightingItem(id: "light_entree_direct", name: "Entrée", onIndex: 611, offIndex: 605, value: "1", isIndirect: false)
            ],
            indirectLights: []
        ),
        RoomLighting(
            id: "room_degagement_1",
            roomName: "Dégagement 1",
            icon: "rectangle.3.group.fill",
            directLights: [
                LightingItem(id: "light_degagement_1_direct", name: "Dégagement 1", onIndex: 616, offIndex: 610, value: "1", isIndirect: false)
            ],
            indirectLights: []
        ),
        RoomLighting(
            id: "room_degagement_2",
            roomName: "Dégagement 2",
            icon: "rectangle.3.group.fill",
            directLights: [
                LightingItem(id: "light_degagement_2_direct", name: "Dégagement 2", onIndex: 616, offIndex: 610, value: "2", isIndirect: false)
            ],
            indirectLights: []
        ),
        RoomLighting(
            id: "room_dressing",
            roomName: "Dressing",
            icon: "tshirt.fill",
            directLights: [
                LightingItem(id: "light_dressing_direct", name: "Dressing", onIndex: 611, offIndex: 605, value: "8", isIndirect: false)
            ],
            indirectLights: [
                LightingItem(id: "light_dressing_placards", name: "Placards", onIndex: 611, offIndex: 605, value: "16", isIndirect: true)
            ]
        ),
        RoomLighting(
            id: "room_service",
            roomName: "Pièce de service",
            icon: "wrench.and.screwdriver.fill",
            directLights: [
                LightingItem(id: "light_service_direct", name: "Pièce de service", onIndex: 615, offIndex: 609, value: "128", isIndirect: false)
            ],
            indirectLights: []
        ),
        RoomLighting(
            id: "room_terrasse",
            roomName: "Terrasse",
            icon: "sun.max.fill",
            directLights: [
                LightingItem(id: "light_terrasse_direct", name: "Terrasse", onIndex: 616, offIndex: 610, value: "4", isIndirect: false)
            ],
            indirectLights: []
        )
    ]
}

// MARK: - Compatibility Extensions

extension View {
    @ViewBuilder
    func onChangeCompat<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        if #available(iOS 17.0, *) {
            self.onChange(of: value) { _, newValue in
                action(newValue)
            }
        } else {
            self.onChange(of: value, perform: action)
        }
    }
}
