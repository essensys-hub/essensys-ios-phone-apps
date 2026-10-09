//
//  IndexTable.swift
//  Référentiel unique des commandes Éclairage / Volets (spec domotic-controls, design D3).
//  Copie fidèle de essensys-user-portal-frontend (LightingPage.tsx, ShuttersPage.tsx), identique à
//  IndexTable.kt Android. Indices legacy de la table d'échange : NE PAS les modifier ici seul.
//  Verrouillé par les tests NR-ios-5 / NR-ios-6. Valeur `v` envoyée = mask en chaîne.
//

import Foundation

/// Une écriture dans la table d'échange : {"k": <int>, "v": "<string>"}.
struct Injection: Equatable, Hashable, Sendable {
    let k: Int
    let v: String
}

enum IndexTable {
    enum Group: Sendable { case main, indirect, special }

    struct Light: Identifiable, Sendable {
        let id: String
        let name: String
        let group: Group
        let mask: Int
        let onIndex: Int
        let offIndex: Int
        func command(on: Bool) -> Injection { Injection(k: on ? onIndex : offIndex, v: String(mask)) }
    }

    struct Shutter: Identifiable, Sendable {
        let id: String
        let name: String
        let group: Group
        let mask: Int
        let openIndex: Int
        let closeIndex: Int
        let travelTimeIndex: Int
        func command(open: Bool) -> Injection { Injection(k: open ? openIndex : closeIndex, v: String(mask)) }
    }

    static let lights: [Light] = [
        Light(id: "terrasse", name: "Terrasse", group: .main, mask: 4, onIndex: 616, offIndex: 610),
        Light(id: "entree", name: "Entrée", group: .main, mask: 1, onIndex: 611, offIndex: 605),
        Light(id: "escalier", name: "Escalier", group: .main, mask: 1, onIndex: 613, offIndex: 607),
        Light(id: "deg1", name: "Dégagement 1", group: .main, mask: 1, onIndex: 616, offIndex: 610),
        Light(id: "deg2", name: "Dégagement 2", group: .main, mask: 2, onIndex: 616, offIndex: 610),
        Light(id: "pieceserv", name: "Pièce de service", group: .main, mask: 128, onIndex: 615, offIndex: 609),
        Light(id: "ann1", name: "Annexe 1", group: .main, mask: 8, onIndex: 616, offIndex: 610),
        Light(id: "ann2", name: "Annexe 2", group: .main, mask: 16, onIndex: 616, offIndex: 610),
        Light(id: "salon", name: "Salon", group: .main, mask: 128, onIndex: 612, offIndex: 606),
        Light(id: "sam", name: "Salle à Manger", group: .main, mask: 64, onIndex: 612, offIndex: 606),
        Light(id: "cuisine", name: "Cuisine", group: .main, mask: 1, onIndex: 615, offIndex: 609),
        Light(id: "sdb1", name: "Salle de Bain 1", group: .main, mask: 128, onIndex: 616, offIndex: 610),
        Light(id: "sdb2", name: "Salle de Bain 2", group: .main, mask: 8, onIndex: 615, offIndex: 609),
        Light(id: "wc1", name: "WC 1", group: .main, mask: 32, onIndex: 615, offIndex: 609),
        Light(id: "wc2", name: "WC 2", group: .main, mask: 64, onIndex: 615, offIndex: 609),
        Light(id: "bureau", name: "Bureau", group: .main, mask: 32, onIndex: 612, offIndex: 606),
        Light(id: "gdchamb", name: "Grande Chambre", group: .main, mask: 128, onIndex: 614, offIndex: 608),
        Light(id: "ptchamb1", name: "Petite Chambre 1", group: .main, mask: 64, onIndex: 614, offIndex: 608),
        Light(id: "ptchamb2", name: "Petite Chambre 2", group: .main, mask: 32, onIndex: 614, offIndex: 608),
        Light(id: "ptchamb3", name: "Petite Chambre 3", group: .main, mask: 16, onIndex: 614, offIndex: 608),
        Light(id: "dressing", name: "Dressing", group: .main, mask: 8, onIndex: 611, offIndex: 605),
        Light(id: "isalonind", name: "Salon (indirect 1)", group: .indirect, mask: 2, onIndex: 611, offIndex: 605),
        Light(id: "isalonind2", name: "Salon (indirect 2)", group: .indirect, mask: 4, onIndex: 611, offIndex: 605),
        Light(id: "icuisine", name: "Cuisine (plans de travail)", group: .indirect, mask: 2, onIndex: 615, offIndex: 609),
        Light(id: "isdb1", name: "Salle de Bain 1 (miroir)", group: .indirect, mask: 4, onIndex: 615, offIndex: 609),
        Light(id: "isdb2", name: "Salle de Bain 2 (miroir)", group: .indirect, mask: 16, onIndex: 615, offIndex: 609),
        Light(id: "igdchamb1", name: "Grande Chambre (chevet 1)", group: .indirect, mask: 2, onIndex: 613, offIndex: 607),
        Light(id: "igdchamb2", name: "Grande Chambre (chevet 2)", group: .indirect, mask: 4, onIndex: 613, offIndex: 607),
        Light(id: "iptchamb1", name: "Petite Chambre 1 (chevet 1)", group: .indirect, mask: 8, onIndex: 613, offIndex: 607),
        Light(id: "iptchamb2", name: "Petite Chambre 1 (chevet 2)", group: .indirect, mask: 16, onIndex: 613, offIndex: 607),
        Light(id: "iptchamb22", name: "Petite Chambre 2 (chevet)", group: .indirect, mask: 32, onIndex: 613, offIndex: 607),
        Light(id: "iptchamb3", name: "Petite Chambre 3 (chevet)", group: .indirect, mask: 64, onIndex: 613, offIndex: 607),
        Light(id: "idressing", name: "Dressing (placards)", group: .indirect, mask: 16, onIndex: 611, offIndex: 605),
    ]

    static let shutters: [Shutter] = [
        Shutter(id: "volet1salon", name: "Volet 1 Salon", group: .main, mask: 1, openIndex: 617, closeIndex: 620, travelTimeIndex: 566),
        Shutter(id: "volet2salon", name: "Volet 2 Salon", group: .main, mask: 2, openIndex: 617, closeIndex: 620, travelTimeIndex: 567),
        Shutter(id: "volet3salon", name: "Volet 3 Salon", group: .main, mask: 4, openIndex: 617, closeIndex: 620, travelTimeIndex: 568),
        Shutter(id: "volet1salleamanger", name: "Volet 1 Salle à Manger", group: .main, mask: 8, openIndex: 617, closeIndex: 620, travelTimeIndex: 569),
        Shutter(id: "volet2salleamanger", name: "Volet 2 Salle à Manger", group: .main, mask: 16, openIndex: 617, closeIndex: 620, travelTimeIndex: 570),
        Shutter(id: "volet1cuisine", name: "Volet 1 Cuisine", group: .main, mask: 1, openIndex: 619, closeIndex: 622, travelTimeIndex: 582),
        Shutter(id: "volet2cuisine", name: "Volet 2 Cuisine", group: .main, mask: 2, openIndex: 619, closeIndex: 622, travelTimeIndex: 583),
        Shutter(id: "voletsdb", name: "Volet Salle de Bain 1", group: .main, mask: 4, openIndex: 619, closeIndex: 622, travelTimeIndex: 584),
        Shutter(id: "volet1gdchamb", name: "Volet 1 Grande Chambre", group: .main, mask: 1, openIndex: 618, closeIndex: 621, travelTimeIndex: 574),
        Shutter(id: "volet2gdchamb", name: "Volet 2 Grande Chambre", group: .main, mask: 2, openIndex: 618, closeIndex: 621, travelTimeIndex: 575),
        Shutter(id: "volet1ptchamb", name: "Volet Petite Chambre 1", group: .main, mask: 4, openIndex: 618, closeIndex: 621, travelTimeIndex: 576),
        Shutter(id: "volet2ptchamb", name: "Volet Petite Chambre 2", group: .main, mask: 8, openIndex: 618, closeIndex: 621, travelTimeIndex: 577),
        Shutter(id: "volet3ptchamb", name: "Volet Petite Chambre 3", group: .main, mask: 16, openIndex: 618, closeIndex: 621, travelTimeIndex: 578),
        Shutter(id: "voletbureau", name: "Volet Bureau", group: .main, mask: 32, openIndex: 617, closeIndex: 620, travelTimeIndex: 571),
        Shutter(id: "voletstore", name: "Volet \"Store\"", group: .special, mask: 64, openIndex: 617, closeIndex: 620, travelTimeIndex: 572),
        Shutter(id: "store", name: "Store (banne)", group: .special, mask: 8, openIndex: 619, closeIndex: 622, travelTimeIndex: 585),
    ]
}
