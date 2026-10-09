//
//  PortalRepository.swift
//  Liaison armoire, état gateway et dernière action (cloud) ; validité de session (LAN).
//  Jumeau de PortalRepository.kt.
//

import Foundation

enum LinkState: Equatable, Sendable {
    case linked
    case none
    case requested(status: String, machineSerial: String?)
}

final class PortalRepository: Sendable {
    private let api: APIClient
    private let auth: AuthRepository

    init(api: APIClient, auth: AuthRepository) {
        self.api = api
        self.auth = auth
    }

    func linkState() async -> Result<LinkState, APIError> {
        await get("/api/portal/link-request/status", as: LinkStatusResponse.self) { status in
            if status.portalAccess == true { return .linked }
            if let request = status.linkRequest {
                return .requested(status: request.status ?? "pending", machineSerial: request.machineSerial)
            }
            return LinkState.none
        }
    }

    func requestLink(serial: String, message: String) async -> Result<Void, APIError> {
        let body = LinkRequestBody(machineSerial: serial.trimmingCharacters(in: .whitespaces),
                                   message: message.trimmingCharacters(in: .whitespaces))
        switch await api.send("POST", "/api/portal/link-request", body: body) {
        case let .failure(error): auth.handle(error); return .failure(error)
        case .success: return .success(())
        }
    }

    func gatewayOnline() async -> Result<Bool, APIError> {
        await get("/api/portal/session", as: PortalSession.self) { $0.gateway?.online == true }
    }

    func lastAction() async -> Result<LastAction?, APIError> {
        await get("/api/portal/history/latest", as: HistoryLatest.self) { $0.lastAction }
    }

    /// LAN : la gateway n'expose ni état ni historique ; on vérifie seulement la session.
    func lanSessionValid() async -> Result<Bool, APIError> {
        await get("/api/user/me", as: LanUserResponse.self) { $0.user != nil }
    }

    private func get<T: Decodable, R>(_ path: String, as type: T.Type, map: (T) -> R) async -> Result<R, APIError> {
        switch await api.get(path) {
        case let .failure(error):
            auth.handle(error)
            return .failure(error)
        case let .success(response):
            guard let decoded = try? JSONDecoder().decode(T.self, from: response.body) else {
                return .failure(.http(status: response.status, code: "decode", text: "Réponse du serveur illisible."))
            }
            return .success(map(decoded))
        }
    }
}
