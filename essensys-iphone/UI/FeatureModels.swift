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

// MARK: - Temporisations des lumières (spec light-timers-clients)

/// Un seul modèle partagé par l'écran « Temporisations » et par les lumières concernées : même valeur partout.
@MainActor @Observable
final class LightTimersModel {
    private(set) var timers: [String: LightTimerState] = [:]
    private(set) var loaded = false
    private(set) var sending: Set<String> = []
    /// Lumières dont la valeur est relue après un envoi (5, 10 puis 20 s).
    private(set) var waiting: Set<String> = []
    private(set) var feedback: Feedback?
    private var rechecks: [String: Task<Void, Never>] = [:]

    /// Relectures : 5, 10 puis 20 s après l'envoi, comme les prises de sécurité.
    static let recheckPauses: [Duration] = [.seconds(5), .seconds(5), .seconds(10)]

    private let comfort: ComfortRepository
    private let pauses: [Duration]

    init(comfort: ComfortRepository, pauses: [Duration] = LightTimersModel.recheckPauses) {
        self.comfort = comfort
        self.pauses = pauses
    }

    func state(_ id: String) -> LightTimerState? { timers[id] }

    func load() async { await refresh() }

    /// Choix d'un raccourci ou d'une valeur déjà validée (0 = Jamais).
    /// `name` : nom affiché de la lumière (nom personnalisé), à défaut le nom d'origine.
    func set(_ id: String, minutes: Int, name: String? = nil) {
        guard !sending.contains(id), let timer = IndexTable.lightTimer(id: id) else { return }
        sending.insert(id)
        feedback = nil
        Task {
            let result = await comfort.setLightTimer(id: id, minutes: minutes)
            let label = "Temporisation \(name ?? timer.name)"
            switch result {
            case .success(.dryRunOK): feedback = Feedback(text: "\(label) : commande validée (test, non exécutée)", kind: .info)
            case .success(.sent): feedback = Feedback(text: "\(label) : \(LightTimerFormat.label(minutes: minutes)) envoyé, l'armoire confirme sous ~20 s", kind: .success)
            case let .failure(error): feedback = Feedback(text: "\(label) : \(error.userMessage)", kind: .error)
            }
            sending.remove(id)
            if case .success(.sent) = result { waitFor(id, expected: minutes) }
        }
    }

    private func waitFor(_ id: String, expected: Int) {
        rechecks[id]?.cancel()
        waiting.insert(id)
        rechecks[id] = Task {
            for pause in pauses {
                try? await Task.sleep(for: pause)
                if Task.isCancelled { return }
                await refresh()
                if timers[id]?.minutes == expected { break }
            }
            waiting.remove(id)
        }
    }

    private func refresh() async {
        guard case let .success(states) = await comfort.readLightTimers() else { return }
        timers = Dictionary(uniqueKeysWithValues: states.map { ($0.id, $0) })
        loaded = true
    }
}

// MARK: - Noms des lumières (spec light-names-clients)

/// Un seul modèle partagé par les listes, la fiche, l'écran Temporisations et l'éditeur de scénarios.
/// Si la lecture échoue, les noms d'origine restent affichés (aucun message bloquant).
@MainActor @Observable
final class LightNamesModel {
    private(set) var names: [String: LightName] = [:]
    private(set) var loaded = false
    private(set) var sending: Set<String> = []
    private(set) var feedback: Feedback?

    private let comfort: ComfortRepository
    init(comfort: ComfortRepository) { self.comfort = comfort }

    /// Nom à afficher pour une lumière du catalogue : nom personnalisé, sinon nom d'origine.
    func displayName(_ light: IndexTable.Light) -> String { names[light.id]?.displayName ?? light.name }

    func displayName(id: String) -> String {
        if let known = names[id] { return known.displayName }
        return IndexTable.lights.first { $0.id == id }?.name ?? id
    }

    /// Nom personnalisé courant (nil : aucun).
    func customName(_ id: String) -> String? { names[id]?.name }

    func load() async {
        guard case let .success(list) = await comfort.readLightNames() else { return }
        names = Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        loaded = true
    }

    /// Réinitialise l'état (changement de compte ou de mode) : retour aux noms d'origine.
    func reset() { names = [:]; loaded = false; feedback = nil }

    /// Enregistre un nom (validé avant l'envoi). - Returns: true si le serveur a accepté.
    @discardableResult
    func rename(_ id: String, to text: String) async -> Bool {
        guard LightNameFormat.validate(text) != nil else {
            feedback = Feedback(text: LightNameFormat.invalidMessage, kind: .error)
            return false
        }
        return await write(id, name: text)
    }

    /// « Nom d'origine » : `name` remis à null.
    @discardableResult
    func restoreDefault(_ id: String) async -> Bool { await write(id, name: nil) }

    private func write(_ id: String, name: String?) async -> Bool {
        guard !sending.contains(id) else { return false }
        sending.insert(id)
        feedback = nil
        defer { sending.remove(id) }
        switch await comfort.setLightName(id: id, name: name) {
        case let .success(reply):
            if reply.status == "dry_run" {
                feedback = Feedback(text: "Nom validé (test, non enregistré)", kind: .info)
                return true
            }
            names[id] = reply.light
            feedback = Feedback(text: "Nom enregistré : \(reply.light.displayName)", kind: .success)
            return true
        case let .failure(error):
            feedback = Feedback(text: LightNameFormat.message(for: error), kind: .error)
            return false
        }
    }
}

// MARK: - Noms des volets et stores (spec shutter-names-clients)

/// Un seul modèle partagé par les listes, la fiche et la carte « Temps de course ».
/// Si la lecture échoue, les noms d'origine restent affichés (aucun message bloquant).
@MainActor @Observable
final class ShutterNamesModel {
    private(set) var names: [String: ShutterName] = [:]
    private(set) var loaded = false
    private(set) var sending: Set<String> = []
    private(set) var feedback: Feedback?

    private let comfort: ComfortRepository
    init(comfort: ComfortRepository) { self.comfort = comfort }

    /// Nom à afficher pour un volet du catalogue : nom personnalisé, sinon nom d'origine.
    func displayName(_ shutter: IndexTable.Shutter) -> String { names[shutter.id]?.displayName ?? shutter.name }

    func displayName(id: String) -> String {
        if let known = names[id] { return known.displayName }
        return IndexTable.shutters.first { $0.id == id }?.name ?? id
    }

    /// Nom personnalisé courant (nil : aucun).
    func customName(_ id: String) -> String? { names[id]?.name }

    func load() async {
        guard case let .success(list) = await comfort.readShutterNames() else { return }
        names = Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        loaded = true
    }

    /// Réinitialise l'état (changement de compte ou de mode) : retour aux noms d'origine.
    func reset() { names = [:]; loaded = false; feedback = nil }

    /// Enregistre un nom (validé avant l'envoi). - Returns: true si le serveur a accepté.
    @discardableResult
    func rename(_ id: String, to text: String) async -> Bool {
        guard ShutterNameFormat.validate(text) != nil else {
            feedback = Feedback(text: ShutterNameFormat.invalidMessage, kind: .error)
            return false
        }
        return await write(id, name: text)
    }

    /// « Nom d'origine » : `name` remis à null.
    @discardableResult
    func restoreDefault(_ id: String) async -> Bool { await write(id, name: nil) }

    private func write(_ id: String, name: String?) async -> Bool {
        guard !sending.contains(id) else { return false }
        sending.insert(id)
        feedback = nil
        defer { sending.remove(id) }
        switch await comfort.setShutterName(id: id, name: name) {
        case let .success(reply):
            if reply.status == "dry_run" {
                feedback = Feedback(text: "Nom validé (test, non enregistré)", kind: .info)
                return true
            }
            names[id] = reply.shutter
            feedback = Feedback(text: "Nom enregistré : \(reply.shutter.displayName)", kind: .success)
            return true
        case let .failure(error):
            feedback = Feedback(text: ShutterNameFormat.message(for: error), kind: .error)
            return false
        }
    }
}

// MARK: - Affichage des lumières et des volets (spec object-layout-clients)

/// Disposition d'un genre (`LightLayoutModel` pour les lumières, `ShutterLayoutModel` pour les volets : même classe,
/// `kind` différent). Un seul modèle par genre alimente les listes, les commandes de groupe, l'écran Temporisations
/// et la carte « Temps de course » : un objet désactivé ne peut pas être commandé par un groupe.
/// Lecture impossible ou ancien serveur (404) : catalogue complet dans l'ordre d'origine, sans message bloquant ;
/// après une lecture réussie, une coupure passagère conserve la dernière disposition lue.
@MainActor @Observable
final class ObjectLayoutModel {
    let kind: LayoutKind
    private(set) var layout: ObjectLayout = .original
    private(set) var loaded = false
    private(set) var saving = false
    private(set) var feedback: Feedback?

    private let comfort: ComfortRepository
    init(kind: LayoutKind, comfort: ComfortRepository) {
        self.kind = kind
        self.comfort = comfort
    }

    /// Identifiants du genre dans l'ordre effectif (désactivés compris).
    var orderedIDs: [String] { layout.orderedIDs(catalogue: kind.catalogue) }
    var disabledIDs: Set<String> { layout.disabledIDs(catalogue: kind.catalogue) }
    func isDisabled(_ id: String) -> Bool { disabledIDs.contains(id) }

    /// Éléments actifs dans l'ordre global (les groupes filtrent ensuite : un objet ne change jamais de groupe).
    func visible<T: Identifiable>(_ items: [T]) -> [T] where T.ID == String {
        let rank = Dictionary(orderedIDs.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        let off = disabledIDs
        return items.filter { rank[$0.id] != nil && !off.contains($0.id) }.sorted { rank[$0.id]! < rank[$1.id]! }
    }

    /// Signature de la disposition : relance les lectures qui en dépendent (temps de course).
    var signature: String { "\(orderedIDs.joined(separator: ","))|\(disabledIDs.sorted().joined(separator: ","))" }

    func load() async {
        guard case let .success(read) = await comfort.readObjectLayout(kind) else { return }
        layout = read
        loaded = true
    }

    /// Réinitialise l'état (changement de compte ou de mode) : retour au catalogue complet.
    func reset() { layout = .original; loaded = false; feedback = nil }

    func clearFeedback() { feedback = nil }

    /// Enregistre le brouillon en une seule écriture. - Returns: true si le serveur a accepté.
    @discardableResult
    func save(_ draft: ObjectLayoutDraft) async -> Bool {
        guard !saving else { return false }
        saving = true
        feedback = nil
        defer { saving = false }
        let result = draft.isReset
            ? await comfort.writeObjectLayout(kind, order: [], disabled: [], reset: true)
            : await comfort.writeObjectLayout(kind, order: draft.order, disabled: draft.order.filter { draft.isDisabled($0) })
        switch result {
        case let .success(reply):
            if reply.status == "dry_run" {
                feedback = Feedback(text: "Affichage validé (test, non enregistré)", kind: .info)
                return true
            }
            layout = reply.layout
            loaded = true
            feedback = Feedback(text: "Affichage enregistré", kind: .success)
            return true
        case let .failure(error):
            feedback = Feedback(text: ObjectLayoutFormat.message(for: error, kind: kind), kind: .error)
            return false
        }
    }
}
