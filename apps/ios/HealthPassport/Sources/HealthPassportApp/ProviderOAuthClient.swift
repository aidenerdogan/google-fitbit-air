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
                "https://www.googleapis.com/auth/googlehealth.settings.readonly",
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
        case .connected(let expiresAt, let scopes):
            return "Token saved with \(scopes.count) read-only scopes. Expires at \(expiresAt.formatted(date: .abbreviated, time: .shortened))."
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

struct GoogleHealthMetadataSummary: Hashable {
    let profileReachable: Bool
    let pairedDeviceCount: Int?

    var sourceDetail: String {
        if let pairedDeviceCount {
            let deviceText = pairedDeviceCount == 1 ? "1 paired device" : "\(pairedDeviceCount) paired devices"
            return "Profile checked. \(deviceText) found."
        }

        return "Profile checked. Reconnect to add paired device metadata."
    }
}

struct GoogleHealthAPIClient {
    private static let profileScope = "https://www.googleapis.com/auth/googlehealth.profile.readonly"
    private static let settingsScope = "https://www.googleapis.com/auth/googlehealth.settings.readonly"

    func fetchMetadata(tokens: ProviderOAuthTokenSet) async throws -> GoogleHealthMetadataSummary {
        guard tokens.scopes.contains(Self.profileScope) else {
            throw GoogleHealthAPIError.missingScope("profile")
        }

        guard tokens.expiresAt > Date() else {
            throw GoogleHealthAPIError.expiredToken
        }

        _ = try await fetchJSON(path: "/v4/users/me/profile", tokens: tokens)

        guard tokens.scopes.contains(Self.settingsScope) else {
            return GoogleHealthMetadataSummary(profileReachable: true, pairedDeviceCount: nil)
        }

        let pairedDevices = try await fetchPairedDevices(tokens: tokens)
        return GoogleHealthMetadataSummary(profileReachable: true, pairedDeviceCount: pairedDevices.count)
    }

    func fetchDailyRollupSamples(tokens: ProviderOAuthTokenSet, days: Int = 7, now: Date = Date()) async throws -> [VaultSample] {
        guard tokens.expiresAt > Date() else {
            throw GoogleHealthAPIError.expiredToken
        }

        let window = GoogleHealthRollupWindow(days: days, now: now)
        var samples: [VaultSample] = []

        for plan in GoogleHealthDailyRollupPlan.readyPlans {
            guard tokens.scopes.contains(plan.requiredScope) else {
                throw GoogleHealthAPIError.missingScope(plan.metric.rawValue)
            }

            let response = try await fetchDailyRollup(plan: plan, window: window, tokens: tokens)
            samples.append(contentsOf: response.samples(for: plan, importedAt: now))
        }

        return samples
    }

    private func fetchPairedDevices(tokens: ProviderOAuthTokenSet) async throws -> [GoogleHealthPairedDevice] {
        let data = try await fetchJSON(path: "/v4/users/me/pairedDevices?pageSize=100", tokens: tokens)
        let response = try JSONDecoder().decode(GoogleHealthPairedDevicesResponse.self, from: data)
        return response.pairedDevices ?? []
    }

    private func fetchDailyRollup(
        plan: GoogleHealthDailyRollupPlan,
        window: GoogleHealthRollupWindow,
        tokens: ProviderOAuthTokenSet
    ) async throws -> GoogleHealthDailyRollupResponse {
        let body = GoogleHealthDailyRollupRequest(
            range: GoogleHealthCivilTimeInterval(start: window.start, end: window.end),
            windowSizeDays: 1,
            pageSize: daysPageSize(window.days),
            dataSourceFamily: "users/me/dataSourceFamilies/google-wearables"
        )
        let data = try await postJSON(
            path: "/v4/users/me/dataTypes/\(plan.dataTypeID)/dataPoints:dailyRollUp",
            tokens: tokens,
            body: body
        )
        return try JSONDecoder().decode(GoogleHealthDailyRollupResponse.self, from: data)
    }

    private func daysPageSize(_ days: Int) -> Int {
        max(1, min(days, 90))
    }

    private func fetchJSON(path: String, tokens: ProviderOAuthTokenSet) async throws -> Data {
        guard let url = URL(string: "https://health.googleapis.com\(path)") else {
            throw GoogleHealthAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("\(tokens.tokenType) \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleHealthAPIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw GoogleHealthAPIError.requestFailed(httpResponse.statusCode)
        }

        return data
    }

    private func postJSON<Body: Encodable>(path: String, tokens: ProviderOAuthTokenSet, body: Body) async throws -> Data {
        guard let url = URL(string: "https://health.googleapis.com\(path)") else {
            throw GoogleHealthAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("\(tokens.tokenType) \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleHealthAPIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw GoogleHealthAPIError.requestFailed(httpResponse.statusCode)
        }

        return data
    }
}

private struct GoogleHealthPairedDevicesResponse: Decodable {
    let pairedDevices: [GoogleHealthPairedDevice]?
}

private struct GoogleHealthPairedDevice: Decodable, Hashable {}

enum GoogleHealthAPIError: LocalizedError {
    case expiredToken
    case invalidURL
    case invalidResponse
    case missingScope(String)
    case requestFailed(Int)

    var errorDescription: String? {
        switch self {
        case .expiredToken:
            return "Google token is expired. Reconnect Google Health before refreshing metadata."
        case .invalidURL:
            return "Google Health metadata URL could not be created."
        case .invalidResponse:
            return "Google Health metadata response was not HTTP."
        case .missingScope(let scope):
            return "Google token is missing \(scope) metadata scope. Reconnect Google Health."
        case .requestFailed(let status):
            return "Google Health metadata request failed with HTTP \(status)."
        }
    }
}

private struct GoogleHealthDailyRollupPlan: Sendable {
    let metric: VaultMetric
    let dataTypeID: String
    let requiredScope: String
    let valueUnit: String
    let value: @Sendable (GoogleHealthDailyRollupDataPoint) -> Double?

    static let activityScope = "https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly"
    static let metricsScope = "https://www.googleapis.com/auth/googlehealth.health_metrics_and_measurements.readonly"

    static let readyPlans: [GoogleHealthDailyRollupPlan] = [
        GoogleHealthDailyRollupPlan(
            metric: .steps,
            dataTypeID: "steps",
            requiredScope: activityScope,
            valueUnit: "count"
        ) { point in
            point.steps?.countSum.flatMap(Double.init)
        },
        GoogleHealthDailyRollupPlan(
            metric: .distance,
            dataTypeID: "distance",
            requiredScope: activityScope,
            valueUnit: "m"
        ) { point in
            point.distance?.millimetersSum.flatMap(Double.init).map { $0 / 1_000 }
        },
        GoogleHealthDailyRollupPlan(
            metric: .activeEnergy,
            dataTypeID: "active-energy-burned",
            requiredScope: activityScope,
            valueUnit: "kcal"
        ) { point in
            point.activeEnergyBurned?.kcalSum
        },
        GoogleHealthDailyRollupPlan(
            metric: .heartRate,
            dataTypeID: "heart-rate",
            requiredScope: metricsScope,
            valueUnit: "count/min"
        ) { point in
            point.heartRate?.beatsPerMinuteAvg
        }
    ]
}

private struct GoogleHealthRollupWindow {
    let days: Int
    let start: GoogleHealthCivilDateTime
    let end: GoogleHealthCivilDateTime

    init(days: Int, now: Date, calendar: Calendar = PassportGapAnalyzer.utcCalendar) {
        self.days = max(1, min(days, 14))
        let today = calendar.startOfDay(for: now)
        let startDate = calendar.date(byAdding: .day, value: -(self.days - 1), to: today) ?? today
        let endDate = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        self.start = GoogleHealthCivilDateTime(date: GoogleHealthCivilDate(date: startDate, calendar: calendar))
        self.end = GoogleHealthCivilDateTime(date: GoogleHealthCivilDate(date: endDate, calendar: calendar))
    }
}

private struct GoogleHealthDailyRollupRequest: Encodable {
    let range: GoogleHealthCivilTimeInterval
    let windowSizeDays: Int
    let pageSize: Int
    let dataSourceFamily: String
}

private struct GoogleHealthCivilTimeInterval: Encodable {
    let start: GoogleHealthCivilDateTime
    let end: GoogleHealthCivilDateTime
}

private struct GoogleHealthCivilDateTime: Codable, Hashable {
    let date: GoogleHealthCivilDate
}

private struct GoogleHealthCivilDate: Codable, Hashable {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(date: Date, calendar: Calendar) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.year = components.year ?? 1970
        self.month = components.month ?? 1
        self.day = components.day ?? 1
    }

    func date(calendar: Calendar = PassportGapAnalyzer.utcCalendar) -> Date? {
        DateComponents(calendar: calendar, year: year, month: month, day: day).date
    }

    var stableID: String {
        "\(year)-\(String(format: "%02d", month))-\(String(format: "%02d", day))"
    }
}

private struct GoogleHealthDailyRollupResponse: Decodable {
    let rollupDataPoints: [GoogleHealthDailyRollupDataPoint]

    func samples(for plan: GoogleHealthDailyRollupPlan, importedAt: Date) -> [VaultSample] {
        rollupDataPoints.compactMap { point in
            guard let startAt = point.civilStartTime.date.date(),
                  let endAt = point.civilEndTime.date.date(),
                  let numericValue = plan.value(point)
            else {
                return nil
            }

            let dateID = point.civilStartTime.date.stableID
            return VaultSample(
                id: "google-health-\(plan.dataTypeID)-\(dateID)",
                metric: plan.metric,
                startAt: startAt,
                endAt: endAt,
                numericValue: numericValue,
                unit: plan.valueUnit,
                source: SourceReference(provider: "google_health", deviceModel: "Google wearable", appName: "Google Health"),
                externalId: "google-health:daily-rollup:\(plan.dataTypeID):\(dateID)",
                confidence: .medium,
                importedAt: importedAt
            )
        }
    }
}

private struct GoogleHealthDailyRollupDataPoint: Decodable {
    let civilStartTime: GoogleHealthCivilDateTime
    let civilEndTime: GoogleHealthCivilDateTime
    let steps: Steps?
    let distance: Distance?
    let activeEnergyBurned: ActiveEnergyBurned?
    let heartRate: HeartRate?

    struct Steps: Decodable {
        let countSum: String?
    }

    struct Distance: Decodable {
        let millimetersSum: String?
    }

    struct ActiveEnergyBurned: Decodable {
        let kcalSum: Double?
    }

    struct HeartRate: Decodable {
        let beatsPerMinuteAvg: Double?
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
