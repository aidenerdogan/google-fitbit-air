import AuthenticationServices
import CryptoKit
import Foundation
import HealthPassportKit
import Security

#if os(iOS) && canImport(UIKit)
import UIKit
#elseif os(macOS) && canImport(AppKit)
import AppKit
#endif

struct GoogleHealthOAuthConfiguration: Hashable {
    let clientId: String
    let redirectScheme: String
    let redirectPath: String
    let scopes: [String]

    static func fromBundle(_ bundle: Bundle = .main) -> GoogleHealthOAuthConfiguration {
        GoogleHealthOAuthConfiguration(
            clientId: bundle.object(forInfoDictionaryKey: "GoogleHealthOAuthClientID") as? String ?? "",
            redirectScheme: bundle.object(forInfoDictionaryKey: "GoogleHealthOAuthRedirectScheme") as? String ?? "",
            redirectPath: bundle.object(forInfoDictionaryKey: "GoogleHealthOAuthRedirectPath") as? String ?? "/oauth2redirect",
            scopes: [
                "https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly",
                "https://www.googleapis.com/auth/googlehealth.health_metrics_and_measurements.readonly",
                "https://www.googleapis.com/auth/googlehealth.profile.readonly",
                "https://www.googleapis.com/auth/googlehealth.sleep.readonly"
            ]
        )
    }

    var isConfigured: Bool {
        !clientId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !clientId.contains("REPLACE_ME") &&
            !clientId.contains("$(") &&
            !redirectScheme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !redirectScheme.contains("REPLACE_ME") &&
            !redirectScheme.contains("$(")
    }

    var redirectURI: String {
        "\(redirectScheme):\(redirectPath.hasPrefix("/") ? redirectPath : "/\(redirectPath)")"
    }
}

enum ProviderOAuthConnectionStatus: Hashable {
    case notConfigured
    case ready
    case connected(Date, [String])
    case failed(String)

    var title: String {
        switch self {
        case .notConfigured:
            return "Google connection needs local config"
        case .ready:
            return "Google Health ready to connect"
        case .connected:
            return "Google Health connected"
        case .failed:
            return "Google connection failed"
        }
    }

    var detail: String {
        switch self {
        case .notConfigured:
            return "Add the iOS OAuth client ID and redirect scheme from Google Cloud before connecting."
        case .ready:
            return "Connect your test Google account to save read-only tokens in Keychain."
        case .connected(let date, let scopes):
            return "Connected at \(date.formatted(date: .omitted, time: .shortened)) with \(scopes.count) read-only scopes."
        case .failed(let message):
            return message
        }
    }
}

@MainActor
final class GoogleHealthOAuthClient: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let configuration: GoogleHealthOAuthConfiguration
    private let tokenStore: ProviderTokenStoring
    private var activeSession: ASWebAuthenticationSession?

    init(
        configuration: GoogleHealthOAuthConfiguration = .fromBundle(),
        tokenStore: ProviderTokenStoring
    ) {
        self.configuration = configuration
        self.tokenStore = tokenStore
    }

    var isConfigured: Bool {
        configuration.isConfigured
    }

    func connect() async throws -> ProviderOAuthTokenSet {
        guard configuration.isConfigured else {
            throw GoogleHealthOAuthError.missingConfiguration
        }

        let verifier = PKCE.makeVerifier()
        let challenge = PKCE.makeChallenge(for: verifier)
        let state = PKCE.makeVerifier(byteCount: 24)
        let callbackURL = try await authorize(challenge: challenge, state: state)
        let authorizationCode = try Self.authorizationCode(from: callbackURL, expectedState: state)
        let tokenResponse = try await exchangeCode(authorizationCode, verifier: verifier)
        let tokenSet = tokenResponse.tokenSet(providerId: .googleHealth, requestedScopes: configuration.scopes)
        try tokenStore.save(tokenSet)
        return tokenSet
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(iOS) && canImport(UIKit)
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? ASPresentationAnchor()
        #elseif os(macOS) && canImport(AppKit)
        return NSApplication.shared.windows.first ?? ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }

    private func authorize(challenge: String, state: String) async throws -> URL {
        let authURL = try makeAuthorizationURL(challenge: challenge, state: state)

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: configuration.redirectScheme
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: GoogleHealthOAuthError.authorizationFailed(error.localizedDescription))
                    return
                }

                guard let callbackURL else {
                    continuation.resume(throwing: GoogleHealthOAuthError.missingCallback)
                    return
                }

                continuation.resume(returning: callbackURL)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            activeSession = session

            if !session.start() {
                continuation.resume(throwing: GoogleHealthOAuthError.authorizationFailed("Could not start the system browser authorization session."))
            }
        }
    }

    private func makeAuthorizationURL(challenge: String, state: String) throws -> URL {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: configuration.clientId),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: configuration.scopes.joined(separator: " ")),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        guard let url = components?.url else {
            throw GoogleHealthOAuthError.invalidAuthorizationURL
        }

        return url
    }

    private func exchangeCode(_ code: String, verifier: String) async throws -> GoogleOAuthTokenResponse {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let form = [
            URLQueryItem(name: "client_id", value: configuration.clientId),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "code_verifier", value: verifier),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI)
        ]

        var body = URLComponents()
        body.queryItems = form
        request.httpBody = body.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleHealthOAuthError.tokenExchangeFailed("Google token response was not HTTP.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw GoogleHealthOAuthError.tokenExchangeFailed(message)
        }

        return try JSONDecoder().decode(GoogleOAuthTokenResponse.self, from: data)
    }

    private static func authorizationCode(from callbackURL: URL, expectedState: String) throws -> String {
        let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        if let error = queryItems.first(where: { $0.name == "error" })?.value {
            throw GoogleHealthOAuthError.authorizationFailed(error)
        }

        guard queryItems.first(where: { $0.name == "state" })?.value == expectedState else {
            throw GoogleHealthOAuthError.stateMismatch
        }

        guard let code = queryItems.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw GoogleHealthOAuthError.missingAuthorizationCode
        }

        return code
    }
}

private struct GoogleOAuthTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let tokenType: String
    let expiresIn: TimeInterval
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case scope
    }

    func tokenSet(providerId: ProviderOAuthProviderID, requestedScopes: [String]) -> ProviderOAuthTokenSet {
        let scopes = scope?.split(separator: " ").map(String.init) ?? requestedScopes
        return ProviderOAuthTokenSet(
            providerId: providerId,
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenType: tokenType,
            expiresAt: Date().addingTimeInterval(expiresIn),
            scopes: scopes
        )
    }
}

enum GoogleHealthOAuthError: LocalizedError {
    case missingConfiguration
    case invalidAuthorizationURL
    case authorizationFailed(String)
    case missingCallback
    case stateMismatch
    case missingAuthorizationCode
    case tokenExchangeFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Google Health OAuth is missing the iOS client ID or redirect scheme."
        case .invalidAuthorizationURL:
            return "Google authorization URL could not be created."
        case .authorizationFailed(let message):
            return "Authorization failed: \(message)"
        case .missingCallback:
            return "Google did not return a callback URL."
        case .stateMismatch:
            return "Google callback state did not match the current request."
        case .missingAuthorizationCode:
            return "Google callback did not include an authorization code."
        case .tokenExchangeFailed(let message):
            return "Token exchange failed: \(message)"
        }
    }
}

private enum PKCE {
    private static let allowedCharacters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")

    static func makeVerifier(byteCount: Int = 64) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return String(bytes.map { allowedCharacters[Int($0) % allowedCharacters.count] })
    }

    static func makeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
