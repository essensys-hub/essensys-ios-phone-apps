//
//  LanTrust.swift
//  TLS en réseau local (design D4) : chaque gateway a sa propre CA. Première connexion : on lit
//  le certificat présenté et l'utilisateur confirme son empreinte SHA-256 ; ensuite seul ce
//  certificat sert d'ancre, avec vérification du nom d'hôte (jamais de « trust all »).
//

import CryptoKit
import Foundation
import Security

enum LanTrust {
    static func sha256(_ der: Data) -> String {
        SHA256.hash(data: der).map { String(format: "%02X", $0) }.joined(separator: ":")
    }

    /// Dernier certificat de la chaîne présentée (la CA si la gateway l'envoie, sinon le certificat serveur).
    static func anchorCandidate(of trust: SecTrust) -> Data? {
        guard let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate], let last = chain.last else { return nil }
        return SecCertificateCopyData(last) as Data
    }

    /// Évalue la chaîne présentée avec le certificat épinglé comme unique ancre et la politique SSL (nom d'hôte).
    static func evaluate(_ trust: SecTrust, host: String, pinned: Data) -> Bool {
        guard let anchor = SecCertificateCreateWithData(nil, pinned as CFData) else { return false }
        SecTrustSetPolicies(trust, SecPolicyCreateSSL(true, host as CFString))
        SecTrustSetAnchorCertificates(trust, [anchor] as CFArray)
        SecTrustSetAnchorCertificatesOnly(trust, true)
        return SecTrustEvaluateWithError(trust, nil)
    }
}

/// Délégué URLSession du client LAN : n'accepte que la chaîne ancrée sur le certificat épinglé.
final class PinnedLanDelegate: NSObject, URLSessionDelegate, Sendable {
    private let store: SessionStore
    init(store: SessionStore) { self.store = store }

    func urlSession(
        _ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil); return
        }
        guard let pinned = store.state.pinnedLanCertificate,
              LanTrust.evaluate(trust, host: challenge.protectionSpace.host, pinned: pinned) else {
            completionHandler(.cancelAuthenticationChallenge, nil); return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}

/// Délégué de sondage : capture le certificat présenté sans envoyer de donnée applicative.
final class ProbeDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    private(set) var captured: Data?
    func urlSession(
        _ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if let trust = challenge.protectionSpace.serverTrust { captured = LanTrust.anchorCandidate(of: trust) }
        completionHandler(.cancelAuthenticationChallenge, nil)
    }
}
