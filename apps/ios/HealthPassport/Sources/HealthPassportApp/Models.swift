import Foundation
import HealthPassportKit
import Security
import SwiftUI

struct PassportMetric: Identifiable, Hashable {
    let id: String
    let name: String
    let source: String
    let status: MetricStatus
    let detail: String
}

enum MetricStatus: String {
    case ready = "Ready"
    case gap = "Gap"
    case blocked = "Blocked"
    case unsupported = "Unsupported"
}

struct SyncReceiptSummary: Identifiable, Hashable {
    let id: String
    let source: String
    let imported: Int
    let written: Int
    let skipped: Int
    let unsupported: Int
    let failed: Int
    let status: String
    let finishedAt: Date?
}

struct ContinuitySummary: Hashable {
    let score: Int
    let status: String
    let gapsDetected: Int
}

struct PassportFilterOption: Identifiable, Hashable {
    let id: String
    let label: String
    let metric: VaultMetric?
    let sourceProvider: String?
}

struct PassportTimelineDay: Identifiable, Hashable {
    let id: String
    let date: Date
    let items: [PassportTimelineItem]
}

struct PassportTimelineItem: Identifiable, Hashable {
    let id: String
    let date: Date
    let title: String
    let source: String
    let confidence: String
    let value: String
    let status: String
    let statusKind: MetricStatus
}

struct ConnectedSourceSummary: Identifiable, Hashable {
    let id: String
    let name: String
    let provider: String
    let connectedAt: Date
    let lastSyncAt: Date?
    let detail: String?
    let sampleCount: Int
    let receiptCount: Int
}

private enum GoogleHealthSource {
    static let id = "google-health"
    static let provider = "google_health"
    static let displayName = "Google Health"
}

struct CoachContextPreview: Hashable {
    let title: String
    let summaryLines: [String]
    let gapLines: [String]
    let receiptLines: [String]
    let footer: String

    var isEmpty: Bool {
        summaryLines.isEmpty && gapLines.isEmpty && receiptLines.isEmpty
    }
}

enum CoachConsentStatus: Hashable {
    case notReviewed
    case approved(Date)
    case cancelled

    var title: String {
        switch self {
        case .notReviewed:
            return "Preview not approved"
        case .approved:
            return "Preview approved locally"
        case .cancelled:
            return "Approval cancelled"
        }
    }

    var detail: String {
        switch self {
        case .notReviewed:
            return "Review the local summary before any future AI request."
        case .approved(let date):
            return "Approved at \(date.formatted(date: .omitted, time: .shortened)). No network request has been made."
        case .cancelled:
            return "Nothing will be sent unless you approve a preview later."
        }
    }
}

enum DemoData {
    static let metrics: [PassportMetric] = [
        PassportMetric(
            id: "steps",
            name: "Steps",
            source: "Fitbit/Google",
            status: .ready,
            detail: "Ready for Apple Health writeback"
        ),
        PassportMetric(
            id: "sleep",
            name: "Sleep",
            source: "Fitbit/Google",
            status: .gap,
            detail: "Will show missing nights after first sync"
        ),
        PassportMetric(
            id: "hrv",
            name: "HRV",
            source: "Fitbit/Google",
            status: .unsupported,
            detail: "Kept Passport-only until metric mapping is confirmed"
        )
    ]

    static let receipts: [SyncReceiptSummary] = [
        SyncReceiptSummary(
            id: "placeholder",
            source: "No sync yet",
            imported: 0,
            written: 0,
            skipped: 0,
            unsupported: 0,
            failed: 0,
            status: "Connect a source to create the first receipt",
            finishedAt: nil
        )
    ]

    static let onboardingSteps: [OnboardingStep] = [
        OnboardingStep(
            title: "Connect your source",
            detail: "Fitbit/Google will be the first wearable connection. No account tokens are stored in plain app files."
        ),
        OnboardingStep(
            title: "Review Apple Health permissions",
            detail: "Health Passport asks only for the data types needed for writeback and keeps working when some access is denied."
        ),
        OnboardingStep(
            title: "Keep a private vault",
            detail: "Imported records are normalized into an encrypted local vault before any optional backup or AI feature."
        )
    ]

    static let vaultPreview = VaultSnapshot(
        sources: [
            VaultSource(
                id: "local-vault",
                displayName: "Encrypted Local Vault",
                provider: "health_passport",
                connectedAt: Date(timeIntervalSince1970: 1_771_200_000)
            )
        ]
    )
}

struct OnboardingStep: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let detail: String
}

enum ProviderOAuthProviderID: String, Codable, CaseIterable, Hashable {
    case googleHealth = "google_health"
    case fitbitWebApiLegacy = "fitbit_web_api_legacy"
}

struct ProviderOAuthTokenSet: Codable, Equatable, Hashable {
    let providerId: ProviderOAuthProviderID
    let accessToken: String
    let refreshToken: String?
    let tokenType: String
    let expiresAt: Date
    let scopes: [String]

    init(
        providerId: ProviderOAuthProviderID,
        accessToken: String,
        refreshToken: String? = nil,
        tokenType: String = "Bearer",
        expiresAt: Date,
        scopes: [String]
    ) {
        self.providerId = providerId
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.expiresAt = expiresAt
        self.scopes = scopes.sorted()
    }
}

protocol ProviderTokenStoring {
    func save(_ tokens: ProviderOAuthTokenSet) throws
    func load(providerId: ProviderOAuthProviderID) throws -> ProviderOAuthTokenSet?
    func delete(providerId: ProviderOAuthProviderID) throws
}

@MainActor
final class HealthPassportAppState: ObservableObject {
    @Published private(set) var vaultSnapshot: VaultSnapshot = .empty
    @Published var permissionSnapshot = HealthPermissionSnapshot.notRequested
    @Published var isRequestingAppleHealth = false
    @Published var isRunningWritebackLoop = false
    @Published var isImportingFitbitFixture = false
    @Published var isConnectingGoogleHealth = false
    @Published var isRefreshingGoogleMetadata = false
    @Published var loopStatusMessage = "No writeback loop has run yet."
    @Published var fitbitImportStatusMessage = "No Fitbit fixture has been imported yet."
    @Published var googleMetadataStatusMessage = "Metadata has not been refreshed yet."
    @Published var googleConnectionStatus: ProviderOAuthConnectionStatus
    @Published var passportMetricFilter: VaultMetric?
    @Published var passportSourceFilter: String?
    @Published private(set) var coachConsentStatus: CoachConsentStatus = .notReviewed

    private let vaultStore: EncryptedVaultStore?
    private let healthClient: HealthWritebackClient
    private let providerTokenStore: ProviderTokenStoring
    private let googleHealthOAuthClient: GoogleHealthOAuthClient
    private let googleHealthAPIClient: GoogleHealthAPIClient
    private let startupError: String?

    init(
        vaultStore: EncryptedVaultStore?,
        healthClient: HealthWritebackClient,
        providerTokenStore: ProviderTokenStoring = KeychainProviderTokenStore(),
        googleHealthOAuthClient: GoogleHealthOAuthClient? = nil,
        googleHealthAPIClient: GoogleHealthAPIClient = GoogleHealthAPIClient(),
        startupError: String? = nil
    ) {
        self.vaultStore = vaultStore
        self.healthClient = healthClient
        self.providerTokenStore = providerTokenStore
        let oauthClient = googleHealthOAuthClient ?? GoogleHealthOAuthClient(tokenStore: providerTokenStore)
        self.googleHealthOAuthClient = oauthClient
        self.googleHealthAPIClient = googleHealthAPIClient
        self.googleConnectionStatus = oauthClient.isConfigured ? .ready : .notConfigured
        self.startupError = startupError
        loadVault()
        refreshGoogleConnectionStatus()
    }

    static func live() -> HealthPassportAppState {
        do {
            let store = try EncryptedVaultStore.live()
            return HealthPassportAppState(vaultStore: store, healthClient: HealthKitWritebackClient())
        } catch {
            return HealthPassportAppState(
                vaultStore: nil,
                healthClient: HealthKitWritebackClient(),
                startupError: error.localizedDescription
            )
        }
    }

    var receiptSummaries: [SyncReceiptSummary] {
        let sourceNames = Dictionary(uniqueKeysWithValues: vaultSnapshot.sources.map { ($0.id, $0.displayName) })
        let summaries = vaultSnapshot.receipts
            .sorted { $0.finishedAt > $1.finishedAt }
            .map { receipt in
                let skipped = receipt.skippedDuplicates + receipt.skippedWriteback
                let source = sourceNames[receipt.sourceId] ?? receipt.sourceId
                let unsupportedCount = receipt.unsupportedMetrics.count
                let status = "\(receipt.writtenToAppleHealth) written, \(skipped) skipped, \(unsupportedCount) unsupported, \(receipt.failedToAppleHealth) failed"

                return SyncReceiptSummary(
                    id: receipt.id,
                    source: source,
                    imported: receipt.imported,
                    written: receipt.writtenToAppleHealth,
                    skipped: skipped,
                    unsupported: unsupportedCount,
                    failed: receipt.failedToAppleHealth,
                    status: status,
                    finishedAt: receipt.finishedAt
                )
            }

        return summaries.isEmpty ? DemoData.receipts : summaries
    }

    var continuitySummary: ContinuitySummary {
        let analysis = passportGapAnalysis

        if vaultSnapshot.samples.isEmpty {
            return ContinuitySummary(score: 0, status: "No local samples yet", gapsDetected: analysis.totalMissingDays)
        }

        let gapText = analysis.totalMissingDays == 1 ? "1 missing metric day" : "\(analysis.totalMissingDays) missing metric days"
        return ContinuitySummary(
            score: analysis.continuityScore,
            status: "\(vaultSnapshot.samples.count) local samples, \(gapText)",
            gapsDetected: analysis.totalMissingDays
        )
    }

    var passportMetricSummaries: [PassportMetric] {
        passportGapAnalysis.metrics.map { coverage in
            PassportMetric(
                id: coverage.metric.rawValue,
                name: coverage.metric.passportDisplayName,
                source: sourceLabel(for: coverage),
                status: metricStatus(for: coverage.status),
                detail: detailLabel(for: coverage)
            )
        }
    }

    var passportMetricFilterOptions: [PassportFilterOption] {
        let presentMetrics = Array(Set(vaultSnapshot.samples.map(\.metric)))
            .sorted { $0.passportDisplayName < $1.passportDisplayName }
        return presentMetrics.map { metric in
            PassportFilterOption(
                id: metric.rawValue,
                label: metric.passportDisplayName,
                metric: metric,
                sourceProvider: nil
            )
        }
    }

    var passportSourceFilterOptions: [PassportFilterOption] {
        let providers = Array(Set(vaultSnapshot.samples.map(\.source.provider)))
            .sorted { $0.passportSourceDisplayName < $1.passportSourceDisplayName }
        return providers.map { provider in
            PassportFilterOption(
                id: provider,
                label: provider.passportSourceDisplayName,
                metric: nil,
                sourceProvider: provider
            )
        }
    }

    var selectedPassportMetricFilterLabel: String {
        passportMetricFilter?.passportDisplayName ?? "All metrics"
    }

    var selectedPassportSourceFilterLabel: String {
        passportSourceFilter?.passportSourceDisplayName ?? "All sources"
    }

    var passportTimelineDays: [PassportTimelineDay] {
        let filteredSamples = vaultSnapshot.samples
            .filter { sample in
                (passportMetricFilter == nil || sample.metric == passportMetricFilter) &&
                    (passportSourceFilter == nil || sample.source.provider == passportSourceFilter)
            }
            .sorted { $0.startAt > $1.startAt }

        let grouped = Dictionary(grouping: filteredSamples) { sample in
            PassportGapAnalyzer.utcCalendar.startOfDay(for: sample.startAt)
        }

        return grouped.keys
            .sorted(by: >)
            .map { day in
                let items = (grouped[day] ?? [])
                    .sorted { $0.startAt > $1.startAt }
                    .map(timelineItem(for:))
                return PassportTimelineDay(
                    id: String(Int(day.timeIntervalSince1970)),
                    date: day,
                    items: items
                )
            }
    }

    var coachContextPreview: CoachContextPreview {
        let contextPack = CoachContextPackBuilder.make(snapshot: vaultSnapshot)
        let footer = contextPack.rawHealthSamplesIncluded
            ? "Raw sample sharing is blocked."
            : "Raw samples stay in the local vault."

        return CoachContextPreview(
            title: contextPack.title,
            summaryLines: contextPack.summaryLines,
            gapLines: contextPack.gapLines,
            receiptLines: contextPack.receiptLines,
            footer: footer
        )
    }

    var canApproveCoachContext: Bool {
        !vaultSnapshot.samples.isEmpty && !coachContextPreview.isEmpty
    }

    var vaultSourceCount: Int {
        vaultSnapshot.sources.count
    }

    var connectedSourceSummaries: [ConnectedSourceSummary] {
        vaultSnapshot.sources
            .sorted { $0.connectedAt > $1.connectedAt }
            .map { source in
                let samples = vaultSnapshot.samples.filter { $0.source.provider == source.provider || $0.source.provider == source.id }
                let receipts = vaultSnapshot.receipts.filter { $0.sourceId == source.id }
                let latestReceiptDate = receipts.map(\.finishedAt).max()

                return ConnectedSourceSummary(
                    id: source.id,
                    name: source.displayName,
                    provider: source.provider.passportSourceDisplayName,
                    connectedAt: source.connectedAt,
                    lastSyncAt: source.lastSyncAt ?? latestReceiptDate,
                    detail: source.detail,
                    sampleCount: samples.count,
                    receiptCount: receipts.count
                )
            }
    }

    private var passportGapAnalysis: PassportGapAnalysis {
        PassportGapAnalyzer.analyze(snapshot: vaultSnapshot)
    }

    func clearPassportFilters() {
        passportMetricFilter = nil
        passportSourceFilter = nil
    }

    func approveCoachContextPreview() {
        guard canApproveCoachContext else {
            coachConsentStatus = .cancelled
            return
        }

        coachConsentStatus = .approved(Date())
    }

    func cancelCoachContextPreview() {
        coachConsentStatus = .cancelled
    }

    func connectGoogleHealth() async {
        guard googleHealthOAuthClient.isConfigured else {
            googleConnectionStatus = .notConfigured
            return
        }

        isConnectingGoogleHealth = true
        googleConnectionStatus = .ready
        defer { isConnectingGoogleHealth = false }

        do {
            let tokens = try await googleHealthOAuthClient.connect()
            try saveGoogleHealthConnection(tokens: tokens)
            googleConnectionStatus = .connected(tokens.expiresAt, tokens.scopes)
            googleMetadataStatusMessage = "Google Health token saved. Refresh metadata when ready."
        } catch {
            googleConnectionStatus = .failed(error.localizedDescription)
        }
    }

    func refreshGoogleHealthMetadata() async {
        guard let vaultStore else {
            googleMetadataStatusMessage = startupError ?? "Local vault is unavailable."
            return
        }

        isRefreshingGoogleMetadata = true
        googleMetadataStatusMessage = "Checking Google Health metadata."
        defer { isRefreshingGoogleMetadata = false }

        do {
            guard let tokens = try providerTokenStore.load(providerId: .googleHealth) else {
                googleMetadataStatusMessage = "Connect Google Health before refreshing metadata."
                return
            }

            let metadata = try await googleHealthAPIClient.fetchMetadata(tokens: tokens)
            var snapshot = try vaultStore.load()
            let now = Date()
            let existing = snapshot.sources.first { $0.id == GoogleHealthSource.id }
            let source = VaultSource(
                id: GoogleHealthSource.id,
                displayName: GoogleHealthSource.displayName,
                provider: GoogleHealthSource.provider,
                connectedAt: existing?.connectedAt ?? now,
                lastSyncAt: now,
                detail: metadata.sourceDetail
            )

            if let index = snapshot.sources.firstIndex(where: { $0.id == GoogleHealthSource.id }) {
                snapshot.sources[index] = source
            } else {
                snapshot.sources.append(source)
            }

            try vaultStore.save(snapshot)
            replaceVaultSnapshot(try vaultStore.load())
            googleMetadataStatusMessage = metadata.sourceDetail
        } catch {
            googleMetadataStatusMessage = "Metadata refresh failed: \(error.localizedDescription)"
        }
    }

    func refreshGoogleConnectionStatus() {
        guard googleHealthOAuthClient.isConfigured else {
            googleConnectionStatus = .notConfigured
            return
        }

        do {
            if let tokens = try providerTokenStore.load(providerId: .googleHealth) {
                googleConnectionStatus = .connected(tokens.expiresAt, tokens.scopes)
            } else {
                googleConnectionStatus = .ready
            }
        } catch {
            googleConnectionStatus = .failed("Reconnect Google Health to refresh the saved token status.")
        }
    }

    func loadVault() {
        guard let vaultStore else {
            loopStatusMessage = startupError ?? "Local vault is unavailable."
            return
        }

        do {
            replaceVaultSnapshot(try vaultStore.load())
        } catch {
            loopStatusMessage = "Local vault could not be loaded: \(error.localizedDescription)"
        }
    }

    private func saveGoogleHealthConnection(tokens: ProviderOAuthTokenSet) throws {
        guard let vaultStore else {
            throw AppVaultError.localVaultUnavailable(startupError ?? "Local vault is unavailable.")
        }

        var snapshot = try vaultStore.load()
        let now = Date()
        let source = VaultSource(
            id: GoogleHealthSource.id,
            displayName: GoogleHealthSource.displayName,
            provider: GoogleHealthSource.provider,
            connectedAt: snapshot.sources.first { $0.id == GoogleHealthSource.id }?.connectedAt ?? now,
            lastSyncAt: now,
            detail: snapshot.sources.first { $0.id == GoogleHealthSource.id }?.detail ?? "OAuth token saved. Metadata not refreshed yet."
        )

        if let index = snapshot.sources.firstIndex(where: { $0.id == GoogleHealthSource.id }) {
            snapshot.sources[index] = source
        } else {
            snapshot.sources.append(source)
        }

        try vaultStore.save(snapshot)
        replaceVaultSnapshot(try vaultStore.load())
        googleConnectionStatus = .connected(tokens.expiresAt, tokens.scopes)
    }

    func requestAppleHealthAccess() async {
        isRequestingAppleHealth = true
        defer { isRequestingAppleHealth = false }

        do {
            permissionSnapshot = try await healthClient.requestWritePermissions()
        } catch {
            permissionSnapshot = HealthPermissionSnapshot(
                status: .denied,
                message: error.localizedDescription,
                requestedTypes: permissionSnapshot.requestedTypes
            )
        }
    }

    func runDevelopmentWritebackLoop() async {
        guard let vaultStore else {
            loopStatusMessage = startupError ?? "Local vault is unavailable."
            return
        }

        isRunningWritebackLoop = true
        loopStatusMessage = "Preparing development samples."
        defer { isRunningWritebackLoop = false }

        do {
            if permissionSnapshot.status != .granted {
                permissionSnapshot = try await healthClient.requestWritePermissions()
            }

            var snapshot = try vaultStore.load()
            let source = DevelopmentHealthSamples.source
            if !snapshot.sources.contains(where: { $0.id == source.id }) {
                snapshot.sources.append(source)
            }

            let samples = DevelopmentHealthSamples.makeSamples()
            snapshot.samples.append(contentsOf: samples)
            loopStatusMessage = "Writing supported samples to Apple Health."

            let writebackReceipt = await healthClient.write(samples)
            let vaultReceipt = AppleHealthWritebackReceiptMapper.makeVaultReceipt(
                sourceId: source.id,
                importedSamples: samples,
                writebackReceipt: writebackReceipt
            )

            snapshot.receipts.append(vaultReceipt)
            try vaultStore.save(snapshot)
            replaceVaultSnapshot(try vaultStore.load())
            loopStatusMessage = "Writeback receipt saved."
        } catch {
            loopStatusMessage = "Writeback loop failed: \(error.localizedDescription)"
        }
    }

    func importFitbitFixture() async {
        guard let vaultStore else {
            fitbitImportStatusMessage = startupError ?? "Local vault is unavailable."
            return
        }

        isImportingFitbitFixture = true
        fitbitImportStatusMessage = "Importing Fitbit fixture."
        defer { isImportingFitbitFixture = false }

        do {
            var snapshot = try vaultStore.load()
            let source = FitbitFixtureImport.source
            if !snapshot.sources.contains(where: { $0.id == source.id }) {
                snapshot.sources.append(source)
            }

            let samples = FitbitFixtureImport.makeSamples()
            let dedupeResult = FitbitFixtureImport.dedupe(samples, against: snapshot.samples)
            snapshot.samples.append(contentsOf: dedupeResult.accepted)
            let receipt = VaultReceipt(
                id: UUID().uuidString,
                sourceId: source.id,
                startedAt: Date(),
                finishedAt: Date(),
                imported: dedupeResult.accepted.count,
                writtenToAppleHealth: 0,
                skippedDuplicates: dedupeResult.duplicates.count,
                gapsDetected: PassportGapAnalyzer.analyze(snapshot: snapshot).totalMissingDays,
                unsupportedMetrics: [.hrvRmssd]
            )
            snapshot.receipts.append(receipt)

            try vaultStore.save(snapshot)
            replaceVaultSnapshot(try vaultStore.load())
            fitbitImportStatusMessage = "\(dedupeResult.accepted.count) Fitbit fixture samples imported, \(dedupeResult.duplicates.count) duplicates skipped."
        } catch {
            fitbitImportStatusMessage = "Fitbit fixture import failed: \(error.localizedDescription)"
        }
    }

    private func replaceVaultSnapshot(_ snapshot: VaultSnapshot) {
        vaultSnapshot = snapshot
        coachConsentStatus = .notReviewed
    }

    private func metricStatus(for coverageStatus: PassportMetricCoverageStatus) -> MetricStatus {
        switch coverageStatus {
        case .ready:
            return .ready
        case .gap:
            return .gap
        case .blocked:
            return .blocked
        case .passportOnly:
            return .unsupported
        }
    }

    private func sourceLabel(for coverage: PassportMetricCoverage) -> String {
        if coverage.sourceProviders.isEmpty {
            return "No source yet"
        }

        return coverage.sourceProviders.map(\.passportSourceDisplayName).joined(separator: ", ")
    }

    private func detailLabel(for coverage: PassportMetricCoverage) -> String {
        switch coverage.status {
        case .ready:
            return "\(coverage.sampleCount) sample\(coverage.sampleCount == 1 ? "" : "s") preserved and ready for writeback review."
        case .gap:
            let dayText = coverage.missingDays.count == 1 ? "1 missing day" : "\(coverage.missingDays.count) missing days"
            return "\(dayText) detected in the current vault window."
        case .blocked:
            return "No local samples yet. Connect or import a source to start coverage."
        case .passportOnly:
            return "Preserved in Passport, not written to Apple Health until mapping is reviewed."
        }
    }

    private func timelineItem(for sample: VaultSample) -> PassportTimelineItem {
        let decision = AppleHealthWritebackPolicy.decision(for: sample)
        return PassportTimelineItem(
            id: sample.id,
            date: sample.startAt,
            title: sample.metric.passportDisplayName,
            source: sample.source.provider.passportSourceDisplayName,
            confidence: sample.confidence.passportDisplayName,
            value: valueLabel(for: sample),
            status: timelineStatusLabel(for: decision),
            statusKind: timelineStatusKind(for: decision)
        )
    }

    private func valueLabel(for sample: VaultSample) -> String {
        if let numericValue = sample.numericValue {
            let value: String
            if numericValue.rounded() == numericValue {
                value = "\(Int(numericValue))"
            } else {
                value = numericValue.formatted(.number.precision(.fractionLength(1)))
            }

            if let unit = sample.unit {
                return "\(value) \(unit)"
            }

            return value
        }

        if let textValue = sample.textValue {
            return textValue.capitalized
        }

        return "No value"
    }

    private func timelineStatusLabel(for decision: AppleHealthWritebackDecision) -> String {
        switch decision.readiness {
        case .writeable:
            return "Ready for writeback"
        case .passportOnly:
            return "Passport only"
        case .invalid:
            return "Needs value"
        }
    }

    private func timelineStatusKind(for decision: AppleHealthWritebackDecision) -> MetricStatus {
        switch decision.readiness {
        case .writeable:
            return .ready
        case .passportOnly:
            return .unsupported
        case .invalid:
            return .blocked
        }
    }
}

private extension VaultMetric {
    var passportDisplayName: String {
        switch self {
        case .steps:
            return "Steps"
        case .workout:
            return "Workouts"
        case .sleep:
            return "Sleep"
        case .heartRate:
            return "Heart Rate"
        case .restingHeartRate:
            return "Resting Heart Rate"
        case .activeEnergy:
            return "Active Energy"
        case .distance:
            return "Distance"
        case .hrvSdnn:
            return "HRV SDNN"
        case .hrvRmssd:
            return "HRV RMSSD"
        }
    }
}

private extension String {
    var passportSourceDisplayName: String {
        switch self {
        case "fitbit":
            return "Fitbit"
        case "fitbit_fixture":
            return "Development Fixture"
        case "google_health":
            return "Google Health"
        case "health_passport":
            return "Health Passport"
        default:
            return self
        }
    }
}

private extension SampleConfidence {
    var passportDisplayName: String {
        switch self {
        case .high:
            return "High confidence"
        case .medium:
            return "Medium confidence"
        case .low:
            return "Low confidence"
        }
    }
}

private enum DevelopmentHealthSamples {
    static let source = VaultSource(
        id: "dev-fitbit-fixture",
        displayName: "Development Fitbit Fixture",
        provider: "fitbit_fixture",
        connectedAt: Date(timeIntervalSince1970: 1_771_200_000)
    )

    static func makeSamples(now: Date = Date()) -> [VaultSample] {
        let runId = UUID().uuidString
        let start = now.addingTimeInterval(-3_600)
        let end = now.addingTimeInterval(-1_800)
        let sourceReference = SourceReference(provider: source.provider, deviceModel: "Development Fixture", appName: "Health Passport")

        return [
            VaultSample(
                id: "dev-steps-\(runId)",
                metric: .steps,
                startAt: start,
                endAt: end,
                numericValue: 1_240,
                unit: "count",
                source: sourceReference,
                externalId: "dev-steps-\(runId)",
                confidence: .high,
                importedAt: now
            ),
            VaultSample(
                id: "dev-energy-\(runId)",
                metric: .activeEnergy,
                startAt: start,
                endAt: end,
                numericValue: 82,
                unit: "kcal",
                source: sourceReference,
                externalId: "dev-energy-\(runId)",
                confidence: .high,
                importedAt: now
            ),
            VaultSample(
                id: "dev-hrv-\(runId)",
                metric: .hrvRmssd,
                startAt: end,
                numericValue: 43,
                unit: "ms",
                source: sourceReference,
                externalId: "dev-hrv-\(runId)",
                confidence: .medium,
                importedAt: now
            ),
            VaultSample(
                id: "dev-distance-invalid-\(runId)",
                metric: .distance,
                startAt: start,
                endAt: end,
                unit: "m",
                source: sourceReference,
                externalId: "dev-distance-invalid-\(runId)",
                confidence: .low,
                importedAt: now
            )
        ]
    }
}

private enum FitbitFixtureImport {
    struct DedupeResult {
        let accepted: [VaultSample]
        let duplicates: [VaultSample]
    }

    static let source = VaultSource(
        id: "fitbit-fixture",
        displayName: "Fitbit Fixture",
        provider: "fitbit",
        connectedAt: Date(timeIntervalSince1970: 1_771_200_000)
    )

    static func makeSamples(now: Date = Date()) -> [VaultSample] {
        let sourceReference = SourceReference(provider: source.provider, deviceModel: "Fitbit Fixture", appName: "Health Passport")
        let morningStart = Date(timeIntervalSince1970: 1_781_342_000)
        let morningEnd = Date(timeIntervalSince1970: 1_781_345_600)
        let sleepStart = Date(timeIntervalSince1970: 1_781_311_400)
        let sleepEnd = Date(timeIntervalSince1970: 1_781_337_600)

        return [
            VaultSample(
                id: "fitbit-fixture-steps-1",
                metric: .steps,
                startAt: morningStart,
                endAt: morningEnd,
                numericValue: 1_280,
                unit: "count",
                source: sourceReference,
                externalId: "fitbit-fixture-steps-1",
                confidence: .high,
                importedAt: now
            ),
            VaultSample(
                id: "fitbit-fixture-sleep-1",
                metric: .sleep,
                startAt: sleepStart,
                endAt: sleepEnd,
                textValue: "asleep",
                source: sourceReference,
                externalId: "fitbit-fixture-sleep-1",
                confidence: .medium,
                importedAt: now
            ),
            VaultSample(
                id: "fitbit-fixture-hr-1",
                metric: .heartRate,
                startAt: morningEnd,
                numericValue: 72,
                unit: "count/min",
                source: sourceReference,
                externalId: "fitbit-fixture-hr-1",
                confidence: .high,
                importedAt: now
            ),
            VaultSample(
                id: "fitbit-fixture-rhr-1",
                metric: .restingHeartRate,
                startAt: sleepEnd,
                numericValue: 58,
                unit: "count/min",
                source: sourceReference,
                externalId: "fitbit-fixture-rhr-1",
                confidence: .medium,
                importedAt: now
            ),
            VaultSample(
                id: "fitbit-fixture-energy-1",
                metric: .activeEnergy,
                startAt: morningStart,
                endAt: morningEnd,
                numericValue: 86,
                unit: "kcal",
                source: sourceReference,
                externalId: "fitbit-fixture-energy-1",
                confidence: .high,
                importedAt: now
            ),
            VaultSample(
                id: "fitbit-fixture-distance-1",
                metric: .distance,
                startAt: morningStart,
                endAt: morningEnd,
                numericValue: 920,
                unit: "m",
                source: sourceReference,
                externalId: "fitbit-fixture-distance-1",
                confidence: .high,
                importedAt: now
            ),
            VaultSample(
                id: "fitbit-fixture-hrv-rmssd-1",
                metric: .hrvRmssd,
                startAt: sleepEnd,
                numericValue: 44,
                unit: "ms",
                source: sourceReference,
                externalId: "fitbit-fixture-hrv-rmssd-1",
                confidence: .low,
                importedAt: now
            )
        ]
    }

    static func dedupe(_ incoming: [VaultSample], against existing: [VaultSample]) -> DedupeResult {
        var seen = Set(existing.map { dedupeKey(for: $0) })
        var accepted: [VaultSample] = []
        var duplicates: [VaultSample] = []

        for sample in incoming {
            let key = dedupeKey(for: sample)
            if seen.contains(key) {
                duplicates.append(sample)
            } else {
                seen.insert(key)
                accepted.append(sample)
            }
        }

        return DedupeResult(accepted: accepted, duplicates: duplicates)
    }

    private static func dedupeKey(for sample: VaultSample) -> String {
        if let externalId = sample.externalId {
            return "\(sample.source.provider):\(sample.metric.rawValue):\(externalId)"
        }

        let end = sample.endAt?.timeIntervalSince1970.description ?? ""
        let numeric = sample.numericValue?.description ?? ""
        let text = sample.textValue ?? ""
        return "\(sample.source.provider):\(sample.metric.rawValue):\(sample.startAt.timeIntervalSince1970):\(end):\(numeric):\(text)"
    }
}

private enum AppVaultError: LocalizedError {
    case applicationSupportDirectoryUnavailable
    case keychainReadFailed(OSStatus)
    case keychainWriteFailed(OSStatus)
    case randomKeyGenerationFailed(OSStatus)
    case localVaultUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .applicationSupportDirectoryUnavailable:
            return "Application Support directory is unavailable."
        case .keychainReadFailed(let status):
            return "Could not read the vault key from Keychain: \(status)."
        case .keychainWriteFailed(let status):
            return "Could not save the vault key to Keychain: \(status)."
        case .randomKeyGenerationFailed(let status):
            return "Could not create a local vault key: \(status)."
        case .localVaultUnavailable(let message):
            return message
        }
    }
}

private enum ProviderTokenStoreError: LocalizedError {
    case keychainReadFailed(OSStatus)
    case keychainWriteFailed(OSStatus)
    case keychainDeleteFailed(OSStatus)
    case unreadableTokenSet

    var errorDescription: String? {
        switch self {
        case .keychainReadFailed(let status):
            return "Could not read provider tokens from Keychain: \(status)."
        case .keychainWriteFailed(let status):
            return "Could not save provider tokens to Keychain: \(status)."
        case .keychainDeleteFailed(let status):
            return "Could not delete provider tokens from Keychain: \(status)."
        case .unreadableTokenSet:
            return "Provider tokens in Keychain could not be decoded."
        }
    }
}

struct KeychainProviderTokenStore: ProviderTokenStoring {
    private let service = "com.healthpassport.provider-tokens"

    func save(_ tokens: ProviderOAuthTokenSet) throws {
        let data = try encoder().encode(tokens)
        var addQuery = baseQuery(providerId: tokens.providerId)
        addQuery[kSecValueData as String] = data
        #if os(iOS)
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        #endif

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecSuccess {
            return
        }

        guard addStatus == errSecDuplicateItem else {
            throw ProviderTokenStoreError.keychainWriteFailed(addStatus)
        }

        let updateStatus = SecItemUpdate(
            baseQuery(providerId: tokens.providerId) as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        guard updateStatus == errSecSuccess else {
            throw ProviderTokenStoreError.keychainWriteFailed(updateStatus)
        }
    }

    func load(providerId: ProviderOAuthProviderID) throws -> ProviderOAuthTokenSet? {
        var query = baseQuery(providerId: providerId)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = item as? Data else {
            throw ProviderTokenStoreError.keychainReadFailed(status)
        }

        do {
            return try decoder().decode(ProviderOAuthTokenSet.self, from: data)
        } catch {
            throw ProviderTokenStoreError.unreadableTokenSet
        }
    }

    func delete(providerId: ProviderOAuthProviderID) throws {
        let status = SecItemDelete(baseQuery(providerId: providerId) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ProviderTokenStoreError.keychainDeleteFailed(status)
        }
    }

    private func baseQuery(providerId: ProviderOAuthProviderID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: providerId.rawValue
        ]
    }

    private func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private struct KeychainVaultKeyProvider: VaultKeyProviding {
    private let service = "com.healthpassport.local-vault"
    private let account = "vault-key-v1"

    func vaultKeyData() throws -> Data {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let readStatus = SecItemCopyMatching(query as CFDictionary, &item)
        if readStatus == errSecSuccess, let data = item as? Data {
            return data
        }
        guard readStatus == errSecItemNotFound else {
            throw AppVaultError.keychainReadFailed(readStatus)
        }

        var bytes = [UInt8](repeating: 0, count: 32)
        let randomStatus = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard randomStatus == errSecSuccess else {
            throw AppVaultError.randomKeyGenerationFailed(randomStatus)
        }

        let keyData = Data(bytes)
        var addQuery = baseQuery()
        addQuery[kSecValueData as String] = keyData
        #if os(iOS)
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        #endif

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw AppVaultError.keychainWriteFailed(addStatus)
        }

        return keyData
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

private extension EncryptedVaultStore {
    static func live() throws -> EncryptedVaultStore {
        guard let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw AppVaultError.applicationSupportDirectoryUnavailable
        }

        let fileURL = applicationSupportURL
            .appendingPathComponent("HealthPassport", isDirectory: true)
            .appendingPathComponent("vault.hpdata")

        return EncryptedVaultStore(fileURL: fileURL, keyProvider: KeychainVaultKeyProvider())
    }
}
