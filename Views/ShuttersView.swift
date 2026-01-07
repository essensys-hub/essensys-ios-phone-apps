//
//  ShuttersView.swift
//  essensys-iphone
//
//  Created by ANTIGRAVITY on 2026-01-04.
//

import SwiftUI

struct ShutterItem: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let label: String
    let openIndex: Int
    let closeIndex: Int
    let value: String
}

struct RoomShutters: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let icon: String
    var shutters: [ShutterItem]
}

struct ShuttersView: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    @State private var errorMessage = ""
    @State private var showingError = false
    
    // Grouped Data
    @State private var rooms: [RoomShutters] = [
        RoomShutters(name: "Salon", icon: "sofa.fill", shutters: [
            ShutterItem(name: "volet1salon", label: "Volet 1", openIndex: 617, closeIndex: 620, value: "1"),
            ShutterItem(name: "volet2salon", label: "Volet 2", openIndex: 617, closeIndex: 620, value: "2"),
            ShutterItem(name: "volet3salon", label: "Volet 3", openIndex: 617, closeIndex: 620, value: "4")
        ]),
        RoomShutters(name: "Salle à Manger", icon: "fork.knife", shutters: [
            ShutterItem(name: "volet1salleamanger", label: "Volet 1", openIndex: 617, closeIndex: 620, value: "8"),
            ShutterItem(name: "volet2salleamanger", label: "Volet 2", openIndex: 617, closeIndex: 620, value: "16")
        ]),
        RoomShutters(name: "Cuisine", icon: "cooktop.fill", shutters: [
            ShutterItem(name: "volet1cuisine", label: "Volet 1", openIndex: 619, closeIndex: 622, value: "1"),
            ShutterItem(name: "volet2cuisine", label: "Volet 2", openIndex: 619, closeIndex: 622, value: "2")
        ]),
        RoomShutters(name: "Salle de Bain", icon: "shower.fill", shutters: [
            ShutterItem(name: "voletsdb", label: "Salle de Bain 1", openIndex: 619, closeIndex: 622, value: "4")
        ]),
        RoomShutters(name: "Grande Chambre", icon: "bed.double.fill", shutters: [
            ShutterItem(name: "volet1gdchamb", label: "Volet 1", openIndex: 618, closeIndex: 621, value: "1"),
            ShutterItem(name: "volet2gdchamb", label: "Volet 2", openIndex: 618, closeIndex: 621, value: "2")
        ]),
        RoomShutters(name: "Petites Chambres", icon: "bed.double.fill", shutters: [
            ShutterItem(name: "volet1ptchamb", label: "Chambre 1", openIndex: 618, closeIndex: 621, value: "4"),
            ShutterItem(name: "volet2ptchamb", label: "Chambre 2", openIndex: 618, closeIndex: 621, value: "8"),
            ShutterItem(name: "volet3ptchamb", label: "Chambre 3", openIndex: 618, closeIndex: 621, value: "16")
        ]),
        RoomShutters(name: "Bureau", icon: "desktopcomputer", shutters: [
            ShutterItem(name: "voletbureau", label: "Bureau", openIndex: 617, closeIndex: 620, value: "32")
        ])
    ]
    
    // Expansion State
    @State private var expandedRoomIds: Set<UUID> = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Info Banner
                InfoBanner()
                    .padding()
                
                // Global Controls
                HStack(spacing: 20) {
                    Button(action: { openAll() }) {
                        VStack {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title)
                            Text("Tout Ouvrir")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    
                    Button(action: { closeAll() }) {
                        VStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.title)
                            Text("Tout Fermer")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
                .padding(.vertical)
                
                List {
                    ForEach($rooms) { $room in
                        RoomShutterCard(
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
                }
                .listStyle(.plain)
            }
            .navigationTitle("Volets")
            .alert("Erreur", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func openAll() {
        let group = DispatchGroup()
        for room in rooms {
            for shutter in room.shutters {
                group.enter()
                EssensysAPI.shared.sendInjection(k: shutter.openIndex, v: shutter.value) { _ in
                    group.leave()
                }
            }
        }
    }
    
    private func closeAll() {
        let group = DispatchGroup()
        for room in rooms {
            for shutter in room.shutters {
                group.enter()
                EssensysAPI.shared.sendInjection(k: shutter.closeIndex, v: shutter.value) { _ in
                    group.leave()
                }
            }
        }
    }
}

struct RoomShutterCard: View {
    let room: RoomShutters
    @Binding var isExpanded: Bool
    let onError: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: room.icon)
                    .foregroundColor(.blue)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(room.name)
                        .font(.headline)
                    Text("\(room.shutters.count) volet\(room.shutters.count > 1 ? "s" : "")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Group Actions
                Button(action: { moveAll(open: true) }) {
                   Image(systemName: "arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.small)
                
                Button(action: { moveAll(open: false) }) {
                   Image(systemName: "arrow.down")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                // Expand Icon
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
                withAnimation {
                    isExpanded.toggle()
                }
            }
            
            // Details
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(room.shutters) { shutter in
                        ShutterRow(shutter: shutter, onError: onError)
                    }
                }
                .padding(.leading)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func moveAll(open: Bool) {
        let group = DispatchGroup()
        for shutter in room.shutters {
            group.enter()
            let k = open ? shutter.openIndex : shutter.closeIndex
            EssensysAPI.shared.sendInjection(k: k, v: shutter.value) { result in
                 if case .failure(let error) = result {
                    onError(error.localizedDescription)
                }
                group.leave()
            }
        }
    }
}

struct ShutterRow: View {
    let shutter: ShutterItem
    let onError: (String) -> Void
    
    @State private var isCooldown = false
    
    var body: some View {
        HStack {
            Image(systemName: "window.vertical.closed")
                .foregroundColor(.gray)
                .frame(width: 20)
                
            Text(shutter.label)
                .font(.body)
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: {
                    moveShutter(open: true)
                }) {
                    Image(systemName: "arrow.up")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.small)
                .disabled(isCooldown)
                .opacity(isCooldown ? 0.6 : 1.0)
                
                Button(action: {
                    moveShutter(open: false)
                }) {
                    Image(systemName: "arrow.down")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isCooldown)
                .opacity(isCooldown ? 0.6 : 1.0)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray5))
        .cornerRadius(8)
    }
    
    private func moveShutter(open: Bool) {
        startCooldown()
        let k = open ? shutter.openIndex : shutter.closeIndex
        let v = shutter.value
        
        EssensysAPI.shared.sendInjection(k: k, v: v) { result in
            DispatchQueue.main.async {
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isCooldown = false
        }
    }
}
