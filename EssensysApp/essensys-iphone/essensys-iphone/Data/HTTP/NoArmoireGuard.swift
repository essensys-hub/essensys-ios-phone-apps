//
//  NoArmoireGuard.swift
//  Garde no-armoire (portage de essensys-plugin-framework/ts/src/noArmoire.ts, jumeau de
//  NoArmoireInterceptor.kt) : bloque toute mutation domotique vers un hôte réel en test.
//

import Foundation

struct NoArmoireGuard: Sendable {
    static let testModeHeader = "X-Essensys-Test-Mode"
    static let dryRun = "dry-run"

    var allowedHosts: Set<String> = ["127.0.0.1", "localhost", "essensys.uitest"]

    private static let mutations = [
        "/api/admin/inject", "/api/portal/inject", "/api/web/actions", "/api/portal/web/actions",
    ]
    private static let mutatingMethods: Set<String> = ["POST", "PUT", "PATCH", "DELETE"]

    static func isArmoireMutation(method: String, path: String) -> Bool {
        guard mutatingMethods.contains(method.uppercased()) else { return false }
        if mutations.contains(where: { path.contains($0) }) { return true }
        return path.range(of: "/scenarios/[^/]+/launch", options: .regularExpression) != nil
    }

    func shouldBlock(_ request: URLRequest) -> Bool {
        guard let url = request.url else { return false }
        let dryRun = request.value(forHTTPHeaderField: Self.testModeHeader)?.lowercased() == Self.dryRun
            || URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
                .contains(where: { $0.name == "test_mode" && $0.value == "dry_run" }) == true
        let host = url.host ?? ""
        // `.test` est réservé (RFC 2606) : les backends simulés des tests n'existent jamais sur le réseau.
        let simulated = allowedHosts.contains(host) || host.hasSuffix(".essensys.test")
        return Self.isArmoireMutation(method: request.httpMethod ?? "GET", path: url.path) && !dryRun && !simulated
    }
}

struct ArmoireMutationBlocked: Error, CustomStringConvertible {
    let request: String
    var description: String { "no-armoire : mutation réelle interdite (\(request))" }
}
