//
//  ControlModel.swift
//  Envoi des commandes avec anti-rebond (spec domotic-controls « Retour et anti-rebond ») :
//  une seule commande en vol par cible ; les autres appuis sur la même cible sont ignorés.
//

import Foundation
import Observation

@MainActor @Observable
final class ControlModel {
    private(set) var inFlight: Set<String> = []
    private(set) var feedback: Feedback?
    private(set) var travelTimes: [Int: String] = [:]

    private let control: ControlRepository
    init(control: ControlRepository) { self.control = control }

    /// - Returns: false si la commande a été ignorée (déjà en vol).
    @discardableResult
    func send(key: String, label: String, injections: [Injection]) -> Bool {
        guard !inFlight.contains(key) else { return false }
        inFlight.insert(key)
        feedback = nil
        Task {
            let result = injections.count == 1
                ? await control.inject(injections[0])
                : await control.injectAll(injections)
            switch result {
            case .success(.dryRunOK):
                feedback = Feedback(text: "\(label) : commande validée (test, non exécutée)", kind: .info)
            case .success(.sent):
                feedback = Feedback(text: "\(label) : commande envoyée — l'armoire exécute sous ~5 s", kind: .success)
            case let .failure(error):
                feedback = Feedback(text: "\(label) : \(error.userMessage)", kind: .error)
            }
            inFlight.remove(key)
        }
        return true
    }

    /// Réglage du temps de course (spec shutter-travel-time) : saisie validée (1–255), puis injection
    /// unique ; la valeur affichée devient celle envoyée si le serveur l'accepte.
    /// - Returns: false si la saisie est refusée ou la commande déjà en vol.
    @discardableResult
    func saveTravelTime(_ shutter: IndexTable.Shutter, raw: String) -> Bool {
        guard let seconds = Int(raw.trimmingCharacters(in: .whitespaces)),
              let command = shutter.travelTimeCommand(seconds: seconds) else {
            feedback = Feedback(text: "\(shutter.name) : entre 1 et 255 secondes", kind: .error)
            return false
        }
        let key = "time-\(shutter.id)"
        guard !inFlight.contains(key) else { return false }
        inFlight.insert(key)
        feedback = nil
        Task {
            switch await control.inject(command) {
            case .success(.dryRunOK):
                travelTimes[command.k] = command.v
                feedback = Feedback(text: "\(shutter.name) : temps de course validé (test, non exécuté)", kind: .info)
            case .success(.sent):
                travelTimes[command.k] = command.v
                feedback = Feedback(text: "\(shutter.name) : temps de course réglé à \(command.v) s", kind: .success)
            case let .failure(error):
                feedback = Feedback(text: "\(shutter.name) : \(error.userMessage)", kind: .error)
            }
            inFlight.remove(key)
        }
        return true
    }

    func loadTravelTimes() async {
        if case let .success(values) = await control.readExchange(keys: IndexTable.shutters.map(\.travelTimeIndex)) {
            travelTimes = values
        }
    }
}
