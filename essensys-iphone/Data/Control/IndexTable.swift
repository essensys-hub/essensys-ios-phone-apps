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

// MARK: - Chauffage (spec heating-control) : essensys-user-portal-frontend/src/heating/constants.ts

extension IndexTable {
    /// Valeur d'un créneau horaire du planning (3 bits). Hors gel (5) peut être lu dans l'armoire mais
    /// n'est pas proposé à l'édition, comme dans le portail : la grille garde la valeur brute pour ne
    /// jamais réécrire un créneau que l'utilisateur n'a pas touché.
    enum HeatingSlot: Int, CaseIterable, Sendable {
        case off = 0, confort = 1, eco = 2, ecoPlus = 3, ecoPlusPlus = 4, frost = 5

        var label: String {
            switch self {
            case .off: "OFF"
            case .confort: "Confort"
            case .eco: "Éco"
            case .ecoPlus: "Éco+"
            case .ecoPlusPlus: "Éco++"
            case .frost: "Hors gel"
            }
        }

        var inPalette: Bool { self != .frost }
        static let palette = allCases.filter(\.inPalette)
    }

    /// 7 jours × 12 octets (2 heures par octet).
    static let scheduleBytes = 84
    static let scheduleBytesPerDay = 12

    /// Mode immédiat (`Chauf_*_Mode`) : b0–b3 consigne, b4–b5 automatique / forcé / anticipé.
    enum ImmediateMode: Int, CaseIterable, Sendable {
        case auto = 1, anticipated = 32, forceConfort = 17, forceEco = 18, forceEcoPlus = 19,
             forceEcoPlusPlus = 20, frost = 21, off = 16

        var label: String {
            switch self {
            case .auto: "Automatique (planning)"
            case .anticipated: "Anticipé"
            case .forceConfort: "Forçage confort"
            case .forceEco: "Forçage éco"
            case .forceEcoPlus: "Forçage éco+"
            case .forceEcoPlusPlus: "Forçage éco++"
            case .frost: "Forçage hors gel"
            case .off: "OFF"
            }
        }

        /// Nom stable, identique à l'enum Kotlin (identifiants d'accessibilité et tests).
        var name: String {
            switch self {
            case .auto: "AUTO"
            case .anticipated: "ANTICIPATED"
            case .forceConfort: "FORCE_CONFORT"
            case .forceEco: "FORCE_ECO"
            case .forceEcoPlus: "FORCE_ECO_PLUS"
            case .forceEcoPlusPlus: "FORCE_ECO_PLUS_PLUS"
            case .frost: "FROST"
            case .off: "OFF"
            }
        }
    }

    struct HeatingZone: Identifiable, Equatable, Sendable {
        let id: String
        let name: String
        let scheduleStart: Int
        let modeIndex: Int
        let allowsAnticipated: Bool

        var scheduleIndices: Range<Int> { scheduleStart..<(scheduleStart + IndexTable.scheduleBytes) }
        var immediateModes: [ImmediateMode] { ImmediateMode.allCases.filter { allowsAnticipated || $0 != .anticipated } }

        /// nil si le mode n'est pas proposé pour la zone (Anticipé en salle de bain).
        func command(_ mode: ImmediateMode) -> Injection? {
            immediateModes.contains(mode) ? Injection(k: modeIndex, v: String(mode.rawValue)) : nil
        }
    }

    static let heatingZones: [HeatingZone] = [
        HeatingZone(id: "jour", name: "Zone Jour", scheduleStart: 13, modeIndex: 349, allowsAnticipated: true),
        HeatingZone(id: "nuit", name: "Zone Nuit", scheduleStart: 97, modeIndex: 350, allowsAnticipated: true),
        HeatingZone(id: "sdb1", name: "Salle de bain 1", scheduleStart: 181, modeIndex: 351, allowsAnticipated: false),
        HeatingZone(id: "sdb2", name: "Salle de bain 2", scheduleStart: 265, modeIndex: 352, allowsAnticipated: false),
    ]
}

// MARK: - Chauffe-eau et arrosage (spec comfort-controls) : indices du firmware TableEchange.h
// Le portail envoie 400–402 et 500–504 (absents du firmware) : NE PAS les reprendre (design D3).

extension IndexTable {
    static let waterHeaterIndex = 353 // Cumulus_Mode
    static let sprinklerIndex = 363 // Arrose_Mode

    enum WaterHeaterMode: Int, CaseIterable, Sendable {
        case autonomous = 0, offPeak = 1, off = 2

        var label: String {
            switch self {
            case .autonomous: "Autonome (marche permanente)"
            case .offPeak: "Heures creuses"
            case .off: "Arrêt"
            }
        }

        var name: String {
            switch self {
            case .autonomous: "AUTONOMOUS"
            case .offPeak: "OFF_PEAK"
            case .off: "OFF"
            }
        }

        var command: Injection { Injection(k: IndexTable.waterHeaterIndex, v: String(rawValue)) }
    }

    enum SprinklerMode: Int, CaseIterable, Sendable {
        case auto = 255, minutes15 = 15, minutes30 = 30, minutes60 = 60, off = 0

        var label: String {
            switch self {
            case .auto: "Automatique"
            case .minutes15: "15 minutes"
            case .minutes30: "30 minutes"
            case .minutes60: "60 minutes"
            case .off: "Arrêt"
            }
        }

        var name: String {
            switch self {
            case .auto: "AUTO"
            case .minutes15: "MINUTES_15"
            case .minutes30: "MINUTES_30"
            case .minutes60: "MINUTES_60"
            case .off: "OFF"
            }
        }

        var command: Injection { Injection(k: IndexTable.sprinklerIndex, v: String(rawValue)) }
    }
}

// MARK: - Scénarios (spec scenarios) : essensys-user-portal-backend/internal/domain/scenario/indices.go

extension IndexTable {
    static let scenarioFirstBase = 592
    static let scenarioSize = 41
    static let scenarioSlots = 2...8
    static let restorableScenarioSlots = 2...6

    static func scenarioBlock(_ slot: Int) -> ClosedRange<Int> {
        let base = scenarioFirstBase + (slot - 1) * scenarioSize
        return base...(base + scenarioSize - 1)
    }

    /// Les métadonnées `meta/bitmasks` décrivent les indices du scénario 1 (605, 606…) : on les
    /// transpose dans le bloc du scénario édité (design D6). nil si l'indice n'appartient pas au bloc 1.
    static func shiftIntoScenario(_ metaIndex: Int, slot: Int) -> Int? {
        let block = scenarioBlock(slot)
        if block.contains(metaIndex) { return metaIndex }
        let offset = metaIndex - scenarioFirstBase
        guard (0..<scenarioSize).contains(offset) else { return nil }
        return block.lowerBound + offset
    }

    /// Limite firmware : 30 paramètres au plus par action (heating/injectLimits.ts).
    static let maxParamsPerAction = 30

    static func chunk<T>(_ params: [T], size: Int = maxParamsPerAction) -> [[T]] {
        stride(from: 0, to: params.count, by: size).map { Array(params[$0..<min($0 + size, params.count)]) }
    }
}
