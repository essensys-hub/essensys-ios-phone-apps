//
//  ScheduleCodec.swift
//  Planning de chauffage, porté de essensys-user-portal-frontend/src/heating/scheduleCodec.ts et
//  jumeau de ScheduleCodec.kt : un octet = 2 heures, heure paire en bits 0–2, impaire en bits 4–6.
//  Verrouillé par NR-ios-13.
//

import Foundation

/// Planning hebdomadaire d'une zone : 7 jours × 24 heures, valeurs brutes sur 3 bits. Lundi = jour 0.
struct ScheduleGrid: Equatable, Sendable {
    static let days = 7
    static let hours = 24
    static let dayLabels = ["Lu", "Ma", "Me", "Je", "Ve", "Sa", "Di"]
    static let empty = ScheduleGrid(slots: Array(repeating: 0, count: days * hours))

    private(set) var slots: [Int]

    init(slots: [Int]) {
        precondition(slots.count == Self.days * Self.hours, "grille de \(slots.count) créneaux")
        self.slots = slots
    }

    subscript(day: Int, hour: Int) -> Int { slots[day * Self.hours + hour] }

    func with(day: Int, hour: Int, value: Int) -> ScheduleGrid {
        var copy = self
        copy.slots[day * Self.hours + hour] = value
        return copy
    }

    /// « Appliquer [jour] à toute la semaine » (copyDayToAll).
    func copyDayToAll(_ sourceDay: Int) -> ScheduleGrid {
        let row = Array(slots[(sourceDay * Self.hours)..<((sourceDay + 1) * Self.hours)])
        return ScheduleGrid(slots: Array((0..<Self.days).map { _ in row }.joined()))
    }
}

enum ScheduleCodec {
    static func decodeByte(_ byte: Int) -> (even: Int, odd: Int) { (byte & 0x07, (byte >> 4) & 0x07) }

    static func encodeByte(even: Int, odd: Int) -> Int { (even & 0x07) | ((odd & 0x07) << 4) }

    /// Indice de l'octet qui porte le créneau (jour, heure) d'une zone.
    static func index(scheduleStart: Int, day: Int, hour: Int) -> Int {
        scheduleStart + day * IndexTable.scheduleBytesPerDay + hour / 2
    }

    /// Grille depuis les valeurs lues ; un octet absent ou illisible est décodé OFF.
    static func decode(_ values: [Int: String], scheduleStart: Int) -> ScheduleGrid {
        var slots = Array(repeating: 0, count: ScheduleGrid.days * ScheduleGrid.hours)
        for byteIndex in 0..<IndexTable.scheduleBytes {
            let raw = values[scheduleStart + byteIndex].flatMap { Int($0.trimmingCharacters(in: .whitespaces)) } ?? 0
            let (even, odd) = decodeByte(raw)
            slots[byteIndex * 2] = even
            slots[byteIndex * 2 + 1] = odd
        }
        return ScheduleGrid(slots: slots)
    }

    /// Injections des seuls octets dont l'un des deux créneaux a changé, dans l'ordre des indices.
    static func diff(_ grid: ScheduleGrid, baseline: ScheduleGrid, scheduleStart: Int) -> [Injection] {
        (0..<IndexTable.scheduleBytes).compactMap { byteIndex in
            let even = grid.slots[byteIndex * 2], odd = grid.slots[byteIndex * 2 + 1]
            guard even != baseline.slots[byteIndex * 2] || odd != baseline.slots[byteIndex * 2 + 1] else { return nil }
            return Injection(k: scheduleStart + byteIndex, v: String(encodeByte(even: even, odd: odd)))
        }
    }

    /// Référence après un envoi partiel : les octets envoyés prennent la valeur de la grille, les autres
    /// gardent celle de la référence (ils restent « modifiés » et seront renvoyés).
    static func acceptSent(baseline: ScheduleGrid, grid: ScheduleGrid, scheduleStart: Int, sent: [Injection]) -> ScheduleGrid {
        var slots = baseline.slots
        for injection in sent {
            let byteIndex = injection.k - scheduleStart
            guard (0..<IndexTable.scheduleBytes).contains(byteIndex) else { continue }
            slots[byteIndex * 2] = grid.slots[byteIndex * 2]
            slots[byteIndex * 2 + 1] = grid.slots[byteIndex * 2 + 1]
        }
        return ScheduleGrid(slots: slots)
    }
}
