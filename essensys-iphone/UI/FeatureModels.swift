//
//  FeatureModels.swift
//  Modèles observables des écrans Chauffage, Scénarios et Confort (jumeaux de HeatingViewModel.kt,
//  ScenariosViewModel.kt et ComfortViewModel.kt). Anti-rebond : une action en vol par clé.
//

import Foundation
import Observation

/// Retour utilisateur commun aux commandes (même texte qu'Android et que le portail).
func commandFeedback(_ label: String, _ result: Result<InjectOutcome, APIError>) -> Feedback {
    switch result {
    case .success(.dryRunOK): Feedback(text: "\(label) : commande validée (test, non exécutée)", kind: .info)
    case .success(.sent): Feedback(text: "\(label) : commande envoyée — l'armoire exécute sous ~5 s", kind: .success)
    case let .failure(error): Feedback(text: "\(label) : \(error.userMessage)", kind: .error)
    }
}

// MARK: - Chauffage (spec heating-control)

@MainActor @Observable
final class HeatingModel {
    private(set) var zone = IndexTable.heatingZones[0]
    private(set) var grid = ScheduleGrid.empty
    private(set) var baseline = ScheduleGrid.empty
    private(set) var loaded = false
    private(set) var stale = false
    private(set) var saving = false
    private(set) var syncing = false
    private(set) var progress: String?
    private(set) var modeInFlight: IndexTable.ImmediateMode?
    private(set) var feedback: Feedback?
    var day = 0
    var brush = IndexTable.HeatingSlot.confort

    private let heating: HeatingRepository
    private var loadTask: Task<Void, Never>?
    init(heating: HeatingRepository) { self.heating = heating }

    var changes: [Injection] { ScheduleCodec.diff(grid, baseline: baseline, scheduleStart: zone.scheduleStart) }
    var dirty: Bool { grid != baseline }

    /// « N octets · K envois armoire » (formatInjectionLimitHint).
    var pendingHint: String? {
        let count = changes.count
        guard count > 0 else { return nil }
        let chunks = IndexTable.chunk(changes).count
        return chunks <= 1 ? "\(count) octet\(count > 1 ? "s" : "") · 1 envoi armoire"
            : "\(count) octets · \(chunks) envois armoire (max \(IndexTable.maxParamsPerAction)/envoi)"
    }

    func load(_ zone: IndexTable.HeatingZone? = nil) {
        guard !saving, !syncing else { return }
        let target = zone ?? self.zone
        self.zone = target
        feedback = nil
        progress = nil
        loadTask?.cancel()
        loadTask = Task {
            switch await heating.readSchedule(target) {
            case let .success(read):
                guard target == self.zone else { return }
                grid = read.grid; baseline = read.grid; stale = read.stale; loaded = true
            case let .failure(error):
                feedback = Feedback(text: "Lecture du planning : \(error.userMessage)", kind: .error)
            }
        }
    }

    func paint(hour: Int) {
        guard !saving else { return }
        grid = grid.with(day: day, hour: hour, value: brush.rawValue)
        progress = nil
    }

    func copyDayToAll() { if !saving { grid = grid.copyDayToAll(day) } }
    func revert() { if !saving { grid = baseline; progress = nil; feedback = nil } }

    func save() {
        guard !saving, dirty else { return }
        let zone = self.zone, sentGrid = grid, changes = self.changes
        saving = true
        feedback = nil
        Task {
            for await event in heating.save(changes) {
                switch event {
                case let .start(_, count): progress = progressLabel(0, count)
                case let .sending(index, count, _, _): progress = progressLabel(index, count)
                case .chunkSent: break
                case let .failed(index, count, error, sent, _):
                    saving = false
                    baseline = ScheduleCodec.acceptSent(baseline: baseline, grid: sentGrid, scheduleStart: zone.scheduleStart, sent: sent)
                    progress = "Échec à l'envoi \(index)/\(count)"
                    let note = sent.isEmpty ? "" : " \(sent.count) octets déjà envoyés."
                    feedback = Feedback(text: "\(error.userMessage)\(note) Enregistrez de nouveau pour envoyer le reste.", kind: .error)
                case let .done(outcome):
                    saving = false
                    baseline = sentGrid
                    progress = nil
                    feedback = outcome == .dryRunOK
                        ? Feedback(text: "Planning validé (test, non exécuté)", kind: .info)
                        : Feedback(text: "Planning envoyé — comptez environ 20 s par envoi armoire", kind: .success)
                }
            }
            saving = false
        }
    }

    func syncFromArmoire() {
        guard !saving, !syncing else { return }
        syncing = true
        feedback = nil
        progress = "Synchronisation…"
        let zone = self.zone
        Task {
            for await event in heating.syncFromArmoire(zone) {
                switch event {
                case let .progress(received, total): progress = "Lecture de l'armoire : \(received)/\(total) octets"
                case .busy: feedback = Feedback(text: "Synchronisation déjà en cours", kind: .info)
                case let .cacheOnly(read):
                    grid = read.grid; baseline = read.grid; stale = read.stale
                    feedback = Feedback(text: "Dernières valeurs reçues de l'armoire", kind: .info)
                case let .done(read, complete):
                    grid = read.grid; baseline = read.grid; stale = false
                    feedback = complete ? Feedback(text: "Planning relu depuis l'armoire", kind: .success)
                        : Feedback(text: "Lecture partielle : l'armoire n'a pas tout renvoyé à temps", kind: .error)
                case let .failed(error): feedback = Feedback(text: "Synchronisation : \(error.userMessage)", kind: .error)
                }
            }
            syncing = false
            progress = nil
        }
    }

    func setMode(_ mode: IndexTable.ImmediateMode) {
        guard modeInFlight == nil else { return }
        modeInFlight = mode
        feedback = nil
        let zone = self.zone
        Task {
            feedback = commandFeedback(mode.label, await heating.setMode(zone, mode))
            modeInFlight = nil
        }
    }

    private func progressLabel(_ current: Int, _ total: Int) -> String {
        total <= 1 ? "Envoi vers l'armoire…" : "Envoi \(current)/\(total) — max \(IndexTable.maxParamsPerAction) octets/envoi"
    }
}

// MARK: - Scénarios (spec scenarios)

struct ScenarioEditor: Equatable {
    let slot: ScenarioSlot
    var definition: ScenarioDefinition?
    var fields: [BitmaskField] = []
    var loading = true
    var incomplete = false
    var saving = false
}

@MainActor @Observable
final class ScenariosModel {
    private(set) var slots: [ScenarioSlot] = []
    private(set) var inFlight: Set<String> = []
    private(set) var feedback: Feedback?
    var confirmRestore: ScenarioSlot?
    private(set) var editor: ScenarioEditor?

    private let scenarios: ScenarioRepository
    init(scenarios: ScenarioRepository) { self.scenarios = scenarios }

    func load() async {
        switch await scenarios.list() {
        case let .success(list): slots = list
        case let .failure(error): feedback = Feedback(text: "Scénarios : \(error.userMessage)", kind: .error)
        }
    }

    /// Lancement, aussi utilisé par les scénarios rapides de l'accueil.
    func launch(_ slot: Int, label: String) {
        run("launch-\(slot)", label) { [scenarios] in
            let result = await scenarios.launch(slot)
            if case .success = result {
                await MainActor.run { self.slots = self.slots.map { var s = $0; s.lastLaunched = $0.slot == slot ? slot : nil; return s } }
            }
            return result
        }
    }

    func confirmRestoreNow() {
        guard let slot = confirmRestore else { return }
        confirmRestore = nil
        run("restore-\(slot.slot)", "\(slot.label) (réglages d'usine)") { [scenarios] in await scenarios.restore(slot.slot) }
    }

    func openEditor(_ slot: ScenarioSlot) {
        editor = ScenarioEditor(slot: slot)
        feedback = nil
        Task {
            async let definition = scenarios.definition(slot.slot)
            async let fields = scenarios.bitmasks()
            let (d, f) = await (definition, fields)
            guard editor?.slot.slot == slot.slot else { return }
            switch (d, f) {
            case let (.failure(error), _), let (_, .failure(error)):
                editor = nil
                feedback = Feedback(text: "\(slot.label) : \(error.userMessage)", kind: .error)
            case let (.success(def), .success(meta)):
                editor?.definition = def.complete ? def : nil
                editor?.fields = meta
                editor?.loading = false
                editor?.incomplete = !def.complete
            }
        }
    }

    func toggle(metaIndex: Int, bitValue: Int, on: Bool) {
        guard let def = editor?.definition else { return }
        editor?.definition = def.toggled(metaIndex: metaIndex, bitValue: bitValue, on: on)
    }

    func setSecurity(_ choice: IndexTable.ScenarioSecurity) {
        guard let def = editor?.definition else { return }
        editor?.definition = def.withSecurity(choice)
    }

    func closeEditor() { editor = nil }

    func saveEditor() {
        guard let current = editor, let def = current.definition, !current.saving else { return }
        editor?.saving = true
        Task {
            let result = await scenarios.save(def)
            if case .success = result { editor = nil } else { editor?.saving = false }
            feedback = commandFeedback("\(current.slot.label) (enregistrement)", result)
        }
    }

    private func run(_ key: String, _ label: String, _ action: @escaping @Sendable () async -> Result<InjectOutcome, APIError>) {
        guard !inFlight.contains(key) else { return }
        inFlight.insert(key)
        feedback = nil
        Task {
            feedback = commandFeedback(label, await action())
            inFlight.remove(key)
        }
    }
}

// MARK: - Chauffe-eau, arrosage, prises de sécurité, alarme (specs comfort-controls, security-outlets, alarm-control)

/// Le code d'alarme ne transite que par alarm(on:code:) : il n'est jamais gardé dans ce modèle.
@MainActor @Observable
final class ComfortModel {
    private(set) var modes: ComfortModes?
    private(set) var inFlight: Set<String> = []
    private(set) var feedback: Feedback?
    private(set) var outlets: IndexTable.SecurityOutletsState = .unknown
    /// Commande des prises envoyée : état relu jusqu'à recevoir la nouvelle valeur.
    private(set) var outletsWaiting = false
    private(set) var outletsSending: IndexTable.SecurityOutletsAction?
    private var outletsRecheck: Task<Void, Never>?

    /// Relectures de l'état 440 : 5, 10 puis 20 s après l'envoi (l'armoire exécute en ~5 s).
    private static let outletsRecheckPauses: [Duration] = [.seconds(5), .seconds(5), .seconds(10)]

    private let comfort: ComfortRepository
    init(comfort: ComfortRepository) { self.comfort = comfort }

    func loadModes() async {
        if case let .success(value) = await comfort.readModes() { modes = value }
    }

    func setWaterHeater(_ mode: IndexTable.WaterHeaterMode) {
        run("heater-\(mode.name)", mode.label) { [comfort] in await comfort.setWaterHeater(mode) }
    }

    func setSprinkler(_ mode: IndexTable.SprinklerMode) {
        run("sprinkler-\(mode.name)", "Arrosage \(mode.label.lowercased())") { [comfort] in await comfort.setSprinkler(mode) }
    }

    func loadSecurityOutlets() async { await refreshOutlets() }

    /// Une seule commande des prises en vol à la fois ; après un envoi réel, l'état est relu.
    func securityOutlets(_ action: IndexTable.SecurityOutletsAction) {
        guard outletsSending == nil else { return }
        outletsSending = action
        feedback = nil
        Task {
            let result = await comfort.securityOutlets(action)
            feedback = commandFeedback(action.label, result)
            outletsSending = nil
            if case .success(.sent) = result { waitForOutlets(action.expectedState) }
        }
    }

    private func waitForOutlets(_ expected: IndexTable.SecurityOutletsState) {
        outletsRecheck?.cancel()
        outletsWaiting = true
        outletsRecheck = Task {
            for pause in Self.outletsRecheckPauses {
                try? await Task.sleep(for: pause)
                if Task.isCancelled { return }
                if await refreshOutlets() == expected { break }
            }
            outletsWaiting = false
        }
    }

    @discardableResult
    private func refreshOutlets() async -> IndexTable.SecurityOutletsState? {
        guard case let .success(value) = await comfort.readSecurityOutlets() else { return nil }
        outlets = value
        return value
    }

    func alarm(on: Bool, code: String) {
        run(on ? "alarm-on" : "alarm-off", on ? "Mise en service de l'alarme" : "Arrêt de l'alarme") { [comfort] in
            await comfort.alarm(on: on, code: code)
        }
    }

    private func run(_ key: String, _ label: String, _ action: @escaping @Sendable () async -> Result<InjectOutcome, APIError>) {
        guard !inFlight.contains(key) else { return }
        inFlight.insert(key)
        feedback = nil
        Task {
            feedback = commandFeedback(label, await action())
            inFlight.remove(key)
        }
    }
}

/// Alarme masquée en Release tant qu'une mise en service n'a pas été validée sur le banc BP
/// (design mobile-portal-parity-2026-10-010, risque « encodage du code d'alarme »).
enum FeatureFlags {
    #if DEBUG
    static let alarmEnabled = true
    #else
    static let alarmEnabled = false
    #endif
}
