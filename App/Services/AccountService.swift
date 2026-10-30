import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import Observation
import UIKit

/// Sign in with Apple or Google through Firebase Auth. Accounts are optional: the app works the same
/// signed out, and signing in only adds a copy of the sky in the cloud (see `CloudSync`).
///
/// Firebase is configured only when the build carries `GoogleService-Info.plist` (the TestFlight
/// workflow writes it from a secret). Without it `isAvailable` is false and the account UI says so.
@MainActor @Observable
final class AccountService {
    enum Provider: String { case apple = "apple.com", google = "google.com" }

    struct Account: Equatable {
        var uid: String
        var name: String?
        var email: String?
        var provider: Provider?
    }

    private(set) var account: Account?
    private(set) var busy: Provider?
    var errorText: String?

    /// Called after every sign-in, so the caller can merge this phone's sky with the account's.
    @ObservationIgnored var onSignIn: (@MainActor () -> Void)?
    @ObservationIgnored private var listener: AuthStateDidChangeListenerHandle?
    @ObservationIgnored private let apple = AppleSignIn()

    static let isAvailable: Bool = {
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else { return false }
        if FirebaseApp.app() == nil { FirebaseApp.configure() }
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
        return true
    }()

    init() {
        guard Self.isAvailable else { return }
        account = Auth.auth().currentUser.map(Self.account(for:))
        listener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            MainActor.assumeIsolated { self?.account = user.map(Self.account(for:)) }
        }
    }

    // MARK: Signing in

    func signInWithApple() async {
        await run(.apple) {
            let result = try await self.apple.request()
            _ = try await Auth.auth().signIn(with: result.credential)
            // Apple shares the name only the first time; keep it on the Firebase profile.
            if let name = result.fullName, let user = Auth.auth().currentUser, user.displayName == nil {
                let change = user.createProfileChangeRequest()
                change.displayName = name
                try? await change.commitChanges()
                self.account = Self.account(for: user)
            }
        }
    }

    func signInWithGoogle() async {
        await run(.google) {
            let credential = try await self.googleCredential()
            _ = try await Auth.auth().signIn(with: credential)
        }
    }

    private func run(_ provider: Provider, _ work: @escaping () async throws -> Void) async {
        guard Self.isAvailable, busy == nil else { return }
        busy = provider
        errorText = nil
        defer { busy = nil }
        do {
            try await work()
            account = Auth.auth().currentUser.map(Self.account(for:))
            onSignIn?()
        } catch {
            errorText = Self.message(for: error)
        }
    }

    private func googleCredential() async throws -> AuthCredential {
        guard let presenter = UIApplication.shared.topViewController else { throw AccountError.noWindow }
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        guard let idToken = result.user.idToken?.tokenString else { throw AccountError.missingToken }
        return GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString)
    }

    // MARK: Signing out and deleting

    func signOut() {
        try? Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }

    /// Asks the user to confirm with their provider once more (Firebase requires a recent sign-in to
    /// delete), revokes Sign in with Apple, then deletes the Firebase user. `beforeDelete` removes the
    /// account's data while the user can still write it.
    func deleteAccount(beforeDelete: @escaping (String) async throws -> Void) async -> Bool {
        guard let user = Auth.auth().currentUser else { return false }
        let provider = account?.provider ?? .apple
        busy = provider
        errorText = nil
        defer { busy = nil }
        do {
            switch provider {
            case .apple:
                let result = try await apple.request()
                _ = try await user.reauthenticate(with: result.credential)
                if let code = result.authorizationCode {
                    try? await Auth.auth().revokeToken(withAuthorizationCode: code)
                }
            case .google:
                _ = try await user.reauthenticate(with: googleCredential())
            }
            try await beforeDelete(user.uid)
            try await user.delete()
            GIDSignIn.sharedInstance.signOut()
            return true
        } catch {
            errorText = Self.message(for: error)
            return false
        }
    }

    // MARK: Helpers

    private static func account(for user: User) -> Account {
        let provider = user.providerData.lazy.compactMap { Provider(rawValue: $0.providerID) }.first
        let email = user.email ?? user.providerData.lazy.compactMap(\.email).first
        return Account(uid: user.uid, name: user.displayName, email: email, provider: provider)
    }

    private static func message(for error: Error) -> String? {
        if (error as? ASAuthorizationError)?.code == .canceled || (error as? GIDSignInError)?.code == .canceled { return nil }
        let ns = error as NSError
        if ns.domain == "FIRAuthErrorDomain", let code = AuthErrorCode(rawValue: ns.code) {
            switch code {
            case .networkError: return String(localized: "İnternet bağlantısı yok gibi. Bağlanınca tekrar dene.")
            case .accountExistsWithDifferentCredential:
                return String(localized: "Bu e-posta başka bir giriş yöntemiyle kayıtlı. O yöntemle giriş yap.")
            default: break
            }
        }
        return String(localized: "Giriş yapılamadı. Biraz sonra tekrar dene.")
    }
}

enum AccountError: Error { case noWindow, missingToken }

// MARK: - Sign in with Apple

/// One Sign in with Apple request as an async call, with the nonce Firebase needs.
@MainActor
private final class AppleSignIn: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    struct Result {
        var credential: AuthCredential
        var fullName: String?
        var authorizationCode: String?
    }

    private var continuation: CheckedContinuation<Result, Error>?
    private var nonce = ""

    func request() async throws -> Result {
        continuation?.resume(throwing: CancellationError())
        nonce = Self.randomNonce()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = SHA256.hash(data: Data(nonce.utf8)).map { String(format: "%02x", $0) }.joined()
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        return try await withCheckedThrowingContinuation { c in
            continuation = c
            controller.performRequests()
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        MainActor.assumeIsolated {
            guard let apple = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let token = apple.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
                finish(.failure(AccountError.missingToken))
                return
            }
            let name = apple.fullName.flatMap { PersonNameComponentsFormatter.localizedString(from: $0, style: .default) }
            let credential = OAuthProvider.appleCredential(withIDToken: token, rawNonce: nonce, fullName: apple.fullName)
            finish(.success(Result(credential: credential, fullName: name?.isEmpty == false ? name : nil,
                                   authorizationCode: apple.authorizationCode.flatMap { String(data: $0, encoding: .utf8) })))
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        MainActor.assumeIsolated { finish(.failure(error)) }
    }

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated { UIApplication.shared.frontWindow ?? ASPresentationAnchor() }
    }

    private func finish(_ result: Swift.Result<Result, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in charset.randomElement(using: &generator)! })
    }
}

// MARK: - Presenting from SwiftUI

extension UIApplication {
    var frontWindow: UIWindow? {
        connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first(where: \.isKeyWindow)
    }

    /// The view controller on top, so Google's sign-in sheet can present over our own sheets.
    var topViewController: UIViewController? {
        var top = frontWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
