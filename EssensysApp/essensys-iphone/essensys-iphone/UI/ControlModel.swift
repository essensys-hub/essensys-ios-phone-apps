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

    func loadTravelTimes() async {
        if case let .success(values) = await control.readExchange(keys: IndexTable.shutters.map(\.travelTimeIndex)) {
            travelTimes = values
        }
    }
}
