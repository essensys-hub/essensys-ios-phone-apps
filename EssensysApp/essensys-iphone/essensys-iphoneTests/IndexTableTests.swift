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
}
