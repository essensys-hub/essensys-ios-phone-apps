//
//  AuthScreens.swift
//  Connexion (Cloud / Réseau local), changement de mot de passe obligatoire, liaison de l'armoire.
//

import SwiftUI

struct LoginScreen: View {
    @Bindable var model: SessionModel
    @State private var email = ""
    @State private var password = ""
    @State private var lanHost = ""
    @Environment(\.essensys) private var colors

    var body: some View {
        ScreenColumn {
            Text("Essensys").font(.largeTitle.weight(.semibold)).foregroundStyle(colors.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            EssensysCard(title: "Connexion", description: "Choisissez comment joindre votre installation") {
                Picker("Mode", selection: Binding(get: { model.session.mode }, set: { model.setMode($0) })) {
                    Text("Cloud").tag(ConnectionMode.cloud)
                    Text("Réseau local").tag(ConnectionMode.lan)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("mode")
                if model.session.mode == .lan {
                    TextField("Adresse de la gateway", text: $lanHost)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                        .textFieldStyle(.roundedBorder).accessibilityIdentifier("lan-host")
                } else {
                    Text("Serveur : mon.essensys.fr").font(.caption).foregroundStyle(colors.textMuted)
                }
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.emailAddress)
                    .textContentType(.username).textFieldStyle(.roundedBorder).accessibilityIdentifier("email")
                SecureField("Mot de passe", text: $password)
                    .textContentType(.password).textFieldStyle(.roundedBorder).accessibilityIdentifier("password")
                FeedbackBanner(feedback: model.error.map { Feedback(text: $0, kind: .error) }
                    ?? model.info.map { Feedback(text: $0, kind: .info) })
                ActionButton(label: "Se connecter", loading: model.busy, enabled: !email.isEmpty && !password.isEmpty) {
                    if model.session.mode == .cloud || model.setLanHost(lanHost) {
                        Task { await model.login(email: email, password: password) }
                    }
                }
                .accessibilityIdentifier("login")
                if model.session.mode == .lan, model.session.pinnedLanCertificate != nil {
                    Button("Oublier le certificat de la gateway") { model.forgetLanCertificate() }.font(.footnote)
                }
            }
        }
        .onAppear { lanHost = model.session.lanHost }
        .alert("Confirmer la gateway", isPresented: Binding(
            get: { model.pendingCertificate != nil }, set: { if !$0 { model.confirmCertificate(false) } }
        ), presenting: model.pendingCertificate) { _ in
            Button("Elle est identique") { model.confirmCertificate(true) }
            Button("Refuser", role: .cancel) { model.confirmCertificate(false) }
        } message: { cert in
            Text("Première connexion à \(cert.host). Vérifiez que cette empreinte est identique à celle de votre installateur :\n\n\(cert.fingerprint)\n\nSi elle diffère, refusez.")
        }
    }
}

struct PasswordChangeScreen: View {
    @Bindable var model: SessionModel
    @State private var current = ""
    @State private var new = ""

    var body: some View {
        ScreenColumn {
            EssensysCard(title: "Changer votre mot de passe", description: "Obligatoire avant de continuer (8 caractères minimum)") {
                SecureField("Mot de passe actuel", text: $current).textFieldStyle(.roundedBorder).accessibilityIdentifier("current-password")
                SecureField("Nouveau mot de passe", text: $new).textContentType(.newPassword)
                    .textFieldStyle(.roundedBorder).accessibilityIdentifier("new-password")
                FeedbackBanner(feedback: model.error.map { Feedback(text: $0, kind: .error) })
                ActionButton(label: "Valider", loading: model.busy) { Task { await model.changePassword(current: current, new: new) } }
                    .accessibilityIdentifier("change-password")
                ActionButton(label: "Se déconnecter", tone: .secondary) { Task { await model.logout() } }
            }
        }
    }
}

struct LinkScreen: View {
    @Bindable var model: SessionModel
    let state: LinkState
    @State private var serial = ""
    @State private var message = ""

    var body: some View {
        ScreenColumn {
            EssensysCard(title: "Liaison de votre armoire", description: "Aucune armoire n'est encore liée à ce compte") {
                if case let .requested(status, machine) = state {
                    let label = switch status {
                    case "pending": "Demande en cours d'examen"
                    case "rejected": "Demande refusée"
                    case "revoked": "Liaison révoquée"
                    default: "Demande : \(status)"
                    }
                    Text("\(label)\(machine.map { " (armoire \($0))" } ?? "").").accessibilityIdentifier("link-status")
                    if status == "pending" {
                        ActionButton(label: "Actualiser", tone: .secondary) { Task { await model.refreshLink() } }
                    }
                } else {
                    Text("Indiquez le numéro de série de votre armoire pour demander la liaison.")
                }
                if !isPending {
                    TextField("Numéro de série", text: $serial).textFieldStyle(.roundedBorder).accessibilityIdentifier("serial")
                    TextField("Message (facultatif)", text: $message).textFieldStyle(.roundedBorder)
                    ActionButton(label: "Demander la liaison") { Task { await model.requestLink(serial: serial, message: message) } }
                        .accessibilityIdentifier("request-link")
                }
                FeedbackBanner(feedback: model.error.map { Feedback(text: $0, kind: .error) })
                ActionButton(label: "Se déconnecter", tone: .secondary) { Task { await model.logout() } }
            }
        }
    }

    private var isPending: Bool {
        if case let .requested(status, _) = state { return status == "pending" }
        return false
    }
}
