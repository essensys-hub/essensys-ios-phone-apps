import Testing
@testable import essensys_iphone

/// Non-régression des couples (k, v) : copie figée IDENTIQUE à IndexTableTest.kt (Android) et au portail.
/// Toute divergence entre iOS, Android et portail doit être une décision explicite (ticket).
struct IndexTableTests {
    private let goldenLights: [String: (Int, Int, String)] = [
        "terrasse": (616, 610, "4"),
        "entree": (611, 605, "1"),
        "escalier": (613, 607, "1"),
        "deg1": (616, 610, "1"),
        "deg2": (616, 610, "2"),
        "pieceserv": (615, 609, "128"),
        "ann1": (616, 610, "8"),
        "ann2": (616, 610, "16"),
        "salon": (612, 606, "128"),
        "sam": (612, 606, "64"),
        "cuisine": (615, 609, "1"),
        "sdb1": (616, 610, "128"),
        "sdb2": (615, 609, "8"),
        "wc1": (615, 609, "32"),
        "wc2": (615, 609, "64"),
        "bureau": (612, 606, "32"),
        "gdchamb": (614, 608, "128"),
        "ptchamb1": (614, 608, "64"),
        "ptchamb2": (614, 608, "32"),
        "ptchamb3": (614, 608, "16"),
        "dressing": (611, 605, "8"),
        "isalonind": (611, 605, "2"),
        "isalonind2": (611, 605, "4"),
        "icuisine": (615, 609, "2"),
        "isdb1": (615, 609, "4"),
        "isdb2": (615, 609, "16"),
        "igdchamb1": (613, 607, "2"),
        "igdchamb2": (613, 607, "4"),
        "iptchamb1": (613, 607, "8"),
        "iptchamb2": (613, 607, "16"),
        "iptchamb22": (613, 607, "32"),
        "iptchamb3": (613, 607, "64"),
        "idressing": (611, 605, "16"),
    ]

    private let goldenShutters: [String: (Int, Int, String)] = [
        "volet1salon": (617, 620, "1"),
        "volet2salon": (617, 620, "2"),
        "volet3salon": (617, 620, "4"),
        "volet1salleamanger": (617, 620, "8"),
        "volet2salleamanger": (617, 620, "16"),
        "volet1cuisine": (619, 622, "1"),
        "volet2cuisine": (619, 622, "2"),
        "voletsdb": (619, 622, "4"),
        "volet1gdchamb": (618, 621, "1"),
        "volet2gdchamb": (618, 621, "2"),
        "volet1ptchamb": (618, 621, "4"),
        "volet2ptchamb": (618, 621, "8"),
        "volet3ptchamb": (618, 621, "16"),
        "voletbureau": (617, 620, "32"),
        "voletstore": (617, 620, "64"),
        "store": (619, 622, "8"),
    ]

    // NR: NR-ios-5 essensys-hub/essensys-ios-phone-apps#4
    @Test func lighting_sends_portal_index_and_mask_NR_ios_5() {
        #expect(Set(goldenLights.keys) == Set(IndexTable.lights.map(\.id)))
        for light in IndexTable.lights {
            let (on, off, mask) = goldenLights[light.id]!
            #expect(light.command(on: true) == Injection(k: on, v: mask), "\(light.id)")
            #expect(light.command(on: false) == Injection(k: off, v: mask), "\(light.id)")
        }
        #expect(IndexTable.lights.first { $0.id == "salon" }!.command(on: true) == Injection(k: 612, v: "128"))
    }

    // NR: NR-ios-6 essensys-hub/essensys-ios-phone-apps#4
    @Test func shutters_send_portal_index_and_mask_NR_ios_6() {
        #expect(Set(goldenShutters.keys) == Set(IndexTable.shutters.map(\.id)))
        for shutter in IndexTable.shutters {
            let (open, close, mask) = goldenShutters[shutter.id]!
            #expect(shutter.command(open: true) == Injection(k: open, v: mask), "\(shutter.id)")
            #expect(shutter.command(open: false) == Injection(k: close, v: mask), "\(shutter.id)")
        }
        #expect(IndexTable.shutters.first { $0.id == "volet1cuisine" }!.command(open: false) == Injection(k: 622, v: "1"))
    }

    @Test func travel_time_indices_are_in_legacy_range() {
        for shutter in IndexTable.shutters { #expect((566...589).contains(shutter.travelTimeIndex), "\(shutter.id)") }
    }

    // NR: NR-ios-10 essensys-hub/essensys-ios-phone-apps#11
    @Test func heating_zones_use_portal_indices_NR_ios_10() {
        let golden: [(String, Int, Int)] = [("jour", 13, 349), ("nuit", 97, 350), ("sdb1", 181, 351), ("sdb2", 265, 352)]
        #expect(IndexTable.heatingZones.map(\.id) == golden.map(\.0))
        for (zone, (_, start, mode)) in zip(IndexTable.heatingZones, golden) {
            #expect(zone.scheduleIndices == start..<(start + 84), "\(zone.id)")
            #expect(zone.modeIndex == mode, "\(zone.id)")
        }
        // Les 4 plannings se suivent sans trou ni chevauchement (13–348), puis les modes 349–352.
        #expect(IndexTable.heatingZones.flatMap { Array($0.scheduleIndices) } == Array(13...348))
        let goldenModes = ["AUTO": 1, "ANTICIPATED": 32, "FORCE_CONFORT": 17, "FORCE_ECO": 18,
                           "FORCE_ECO_PLUS": 19, "FORCE_ECO_PLUS_PLUS": 20, "FROST": 21, "OFF": 16]
        #expect(Dictionary(uniqueKeysWithValues: IndexTable.ImmediateMode.allCases.map { ($0.name, $0.rawValue) }) == goldenModes)
        #expect(IndexTable.heatingZones.map(\.allowsAnticipated) == [true, true, false, false])
    }

    // NR: NR-ios-11 essensys-hub/essensys-ios-phone-apps#11
    @Test func water_heater_and_sprinkler_use_firmware_indices_NR_ios_11() {
        #expect(IndexTable.WaterHeaterMode.allCases.map(\.command) == [
            Injection(k: 353, v: "0"), Injection(k: 353, v: "1"), Injection(k: 353, v: "2"),
        ])
        #expect(IndexTable.SprinklerMode.allCases.map(\.command) == [
            Injection(k: 363, v: "255"), Injection(k: 363, v: "15"), Injection(k: 363, v: "30"),
            Injection(k: 363, v: "60"), Injection(k: 363, v: "0"),
        ])
        // Les indices du portail (400–402, 500–504) sont absents du firmware : jamais envoyés.
        let sent = IndexTable.WaterHeaterMode.allCases.map(\.command.k) + IndexTable.SprinklerMode.allCases.map(\.command.k)
        #expect(!sent.contains { (400...402).contains($0) || (500...504).contains($0) })
    }

    // NR: NR-ios-17 essensys-hub/essensys-ios-phone-apps#18
    @Test func travel_time_command_uses_shutter_index_and_range_NR_ios_17() {
        let salon1 = IndexTable.shutters.first { $0.id == "volet1salon" }!
        #expect(salon1.travelTimeCommand(seconds: 30) == Injection(k: 566, v: "30"))
        #expect(IndexTable.shutters.first { $0.id == "store" }!.travelTimeCommand(seconds: 255) == Injection(k: 585, v: "255"))
        #expect(salon1.travelTimeCommand(seconds: 1) == Injection(k: 566, v: "1"))
        #expect(salon1.travelTimeCommand(seconds: 0) == nil)
        #expect(salon1.travelTimeCommand(seconds: 256) == nil)
        // Mêmes indices que le portail (ShuttersPage.tsx, timeIndex) et qu'IndexTableTest.kt.
        let golden = [
            "volet1salon": 566, "volet2salon": 567, "volet3salon": 568, "volet1salleamanger": 569,
            "volet2salleamanger": 570, "voletbureau": 571, "voletstore": 572, "volet1gdchamb": 574,
            "volet2gdchamb": 575, "volet1ptchamb": 576, "volet2ptchamb": 577, "volet3ptchamb": 578,
            "volet1cuisine": 582, "volet2cuisine": 583, "voletsdb": 584, "store": 585,
        ]
        #expect(Dictionary(uniqueKeysWithValues: IndexTable.shutters.map { ($0.id, $0.travelTimeCommand(seconds: 30)!.k) }) == golden)
    }

    @Test func scenario_blocks_follow_backend_layout() {
        #expect(IndexTable.scenarioBlock(1) == 592...632)
        #expect(IndexTable.scenarioBlock(4) == 715...755)
        #expect(IndexTable.scenarioBlock(8) == 879...919)
    }

    @Test func anticipated_mode_is_refused_for_bathrooms() {
        let sdb2 = IndexTable.heatingZones.first { $0.id == "sdb2" }!
        #expect(!sdb2.immediateModes.contains(.anticipated))
        #expect(sdb2.command(.anticipated) == nil)
    }
}
