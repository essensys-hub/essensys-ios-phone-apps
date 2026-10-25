import Testing
@testable import essensys_iphone

/// Mêmes données que ScheduleCodecTest.kt (Android).
struct ScheduleCodecTests {
    private let jour = IndexTable.heatingZones.first { $0.id == "jour" }!

    // NR: NR-ios-13 essensys-hub/essensys-ios-phone-apps#12
    @Test func schedule_byte_encodes_even_and_odd_hour_NR_ios_13() {
        // Exemple de la spec : lundi 6 h Confort + 7 h Éco en Zone Jour → k=16, v="33" (0x21).
        let grid = ScheduleGrid.empty
            .with(day: 0, hour: 6, value: IndexTable.HeatingSlot.confort.rawValue)
            .with(day: 0, hour: 7, value: IndexTable.HeatingSlot.eco.rawValue)
        #expect(ScheduleCodec.diff(grid, baseline: .empty, scheduleStart: jour.scheduleStart) == [Injection(k: 16, v: "33")])
        #expect(ScheduleCodec.index(scheduleStart: jour.scheduleStart, day: 0, hour: 7) == 16)
        #expect(ScheduleCodec.index(scheduleStart: jour.scheduleStart, day: 6, hour: 23) == 96)
        #expect(ScheduleCodec.decodeByte(0x21) == (1, 2))
        #expect(ScheduleCodec.encodeByte(even: 3, odd: 4) == 0x43)
    }

    @Test func decode_reads_each_byte_and_defaults_missing_to_off() {
        let grid = ScheduleCodec.decode([13: "33", 96: "65", 50: "abc"], scheduleStart: jour.scheduleStart)
        #expect(grid[0, 0] == 1)
        #expect(grid[0, 1] == 2)
        #expect(grid[6, 22] == 1) // 65 = 0x41
        #expect(grid[6, 23] == 4)
        #expect(grid[3, 2] == 0) // octet illisible → OFF
        #expect(grid[1, 5] == 0) // octet absent → OFF
    }

    @Test func diff_only_emits_changed_bytes_and_keeps_untouched_frost_slot() {
        // Octet 20 lu = hors gel (5) en heure paire, Confort en impaire : modifier l'impaire garde le 5.
        let baseline = ScheduleCodec.decode([20: "21"], scheduleStart: jour.scheduleStart) // 0x15
        let grid = baseline.with(day: 0, hour: 15, value: IndexTable.HeatingSlot.eco.rawValue)
        #expect(ScheduleCodec.diff(grid, baseline: baseline, scheduleStart: jour.scheduleStart) == [Injection(k: 20, v: "37")]) // 0x25
        #expect(ScheduleCodec.diff(baseline, baseline: baseline, scheduleStart: jour.scheduleStart).isEmpty)
    }

    @Test func copy_day_to_all_repeats_source_day() {
        let week = ScheduleGrid.empty.with(day: 0, hour: 8, value: 1).with(day: 0, hour: 9, value: 1).copyDayToAll(0)
        for day in 0..<7 { #expect(week[day, 8] == 1 && week[day, 9] == 1) }
        // 8 h–9 h = 5e octet de chaque jour : un octet modifié par jour.
        #expect(ScheduleCodec.diff(week, baseline: .empty, scheduleStart: jour.scheduleStart).map(\.k) == (0..<7).map { 13 + $0 * 12 + 4 })
    }

    @Test func accept_sent_moves_only_sent_bytes_into_baseline() {
        let grid = ScheduleGrid.empty.with(day: 0, hour: 0, value: 1).with(day: 0, hour: 2, value: 2)
        let partial = ScheduleCodec.acceptSent(baseline: .empty, grid: grid, scheduleStart: 13, sent: [Injection(k: 13, v: "1")])
        #expect(ScheduleCodec.diff(grid, baseline: partial, scheduleStart: 13) == [Injection(k: 14, v: "2")])
    }
}
