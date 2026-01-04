//
//  ShuttersView.swift
//  essensys-iphone
//
//  Created by ANTIGRAVITY on 2026-01-04.
//

import SwiftUI

struct ShutterItem: Identifiable {
    let id = UUID()
    let name: String
    let label: String
    let openIndex: Int
    let closeIndex: Int
    let value: String
}

struct ShuttersView: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    @State private var errorMessage = ""
    @State private var showingError = false
    
    // Données provenant de ShutterControl.tsx (Frontend)
    let shutters: [ShutterItem] = [
        ShutterItem(name: "volet1salon", label: "Volet 1 Salon", openIndex: 617, closeIndex: 620, value: "1"),
        ShutterItem(name: "volet2salon", label: "Volet 2 Salon", openIndex: 617, closeIndex: 620, value: "2"),
        ShutterItem(name: "volet3salon", label: "Volet 3 Salon", openIndex: 617, closeIndex: 620, value: "4"),
        ShutterItem(name: "volet1salleamanger", label: "Volet 1 Salle à Manger", openIndex: 617, closeIndex: 620, value: "8"),
        ShutterItem(name: "volet2salleamanger", label: "Volet 2 Salle à Manger", openIndex: 617, closeIndex: 620, value: "16"),
        ShutterItem(name: "volet1cuisine", label: "Volet 1 Cuisine", openIndex: 619, closeIndex: 622, value: "1"),
        ShutterItem(name: "volet2cuisine", label: "Volet 2 Cuisine", openIndex: 619, closeIndex: 622, value: "2"),
        ShutterItem(name: "voletsdb", label: "Volet Salle de Bain 1", openIndex: 619, closeIndex: 622, value: "4"),
        ShutterItem(name: "volet1gdchamb", label: "Volet 1 Grande Chambre", openIndex: 618, closeIndex: 621, value: "1"),
        ShutterItem(name: "volet2gdchamb", label: "Volet 2 Grande Chambre", openIndex: 618, closeIndex: 621, value: "2"),
        ShutterItem(name: "volet1ptchamb", label: "Volet Petite Chambre 1", openIndex: 618, closeIndex: 621, value: "4"),
        ShutterItem(name: "volet2ptchamb", label: "Volet Petite Chambre 2", openIndex: 618, closeIndex: 621, value: "8"),
        ShutterItem(name: "volet3ptchamb", label: "Volet Petite Chambre 3", openIndex: 618, closeIndex: 621, value: "16"),
        ShutterItem(name: "voletbureau", label: "Volet Bureau", openIndex: 617, closeIndex: 620, value: "32")
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Bannière d'information
                InfoBanner()
                    .padding()
                
                // Contrôles globaux
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
                
                List(shutters) { shutter in
                    HStack {
                        Text(shutter.label)
                            .font(.body)
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            Button(action: {
                                moveShutter(shutter, open: true)
                            }) {
                                Image(systemName: "arrow.up")
                                    .padding(8)
                                    .background(Color.green.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            
                            Button(action: {
                                moveShutter(shutter, open: false)
                            }) {
                                Image(systemName: "arrow.down")
                                    .padding(8)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.vertical, 4)
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
    
    private func moveShutter(_ shutter: ShutterItem, open: Bool) {
        let k = open ? shutter.openIndex : shutter.closeIndex
        let v = shutter.value
        
        EssensysAPI.shared.sendInjection(k: k, v: v) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    break
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    // Helper pour tout ouvrir/fermer (injections séquentielles pour ne pas saturer)
    private func openAll() {
        let group = DispatchGroup()
        for shutter in shutters {
            group.enter()
            EssensysAPI.shared.sendInjection(k: shutter.openIndex, v: shutter.value) { _ in
                group.leave()
            }
        }
    }
    
    private func closeAll() {
        let group = DispatchGroup()
        for shutter in shutters {
            group.enter()
            EssensysAPI.shared.sendInjection(k: shutter.closeIndex, v: shutter.value) { _ in
                group.leave()
            }
        }
    }
}
