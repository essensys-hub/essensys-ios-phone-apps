//
//  AlarmView.swift
//  EssensysApp
//
//  Vue de contrôle de l'alarme
//

import SwiftUI

struct AlarmView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Bannière d'information
                    //InfoBanner()
                    
                    Text("Fonctionnalité d'alarme à venir")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding()
                }
                .padding()
            }
            .navigationTitle("Alarme")
        }
    }
}

