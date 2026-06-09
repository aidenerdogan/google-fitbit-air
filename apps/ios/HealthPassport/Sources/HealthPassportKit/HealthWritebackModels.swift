import Foundation

public enum AppleHealthWritebackReadiness: String, Codable, Sendable {
    case writeable
    case passportOnly
    case invalid
}

public struct AppleHealthWritebackDecision: Codable, Hashable, Sendable {
    public let metric: VaultMetric
    public let readiness: AppleHealthWritebackReadiness
    public let reason: String

    public init(metric: VaultMetric, readiness: AppleHealthWritebackReadiness, reason: String) {
        self.metric = metric
        self.readiness = readiness
        self.reason = reason
    }
}

public enum AppleHealthWritebackResultStatus: String, Codable, Sendable {
    case written
    case skipped
    case unsupported
    case failed
}

public struct AppleHealthWritebackResult: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let sampleId: String
    public let metric: VaultMetric
    public let status: AppleHealthWritebackResultStatus
    public let message: String

    public init(sampleId: String, metric: VaultMetric, status: AppleHealthWritebackResultStatus, message: String) {
        self.id = sampleId
        self.sampleId = sampleId
        self.metric = metric
        self.status = status
        self.message = message
    }
}

public struct AppleHealthWritebackReceipt: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let startedAt: Date
    public let finishedAt: Date
    public let results: [AppleHealthWritebackResult]

    public init(id: String = UUID().uuidString, startedAt: Date, finishedAt: Date, results: [AppleHealthWritebackResult]) {
        self.id = id
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.results = results
    }

    public var writtenCount: Int {
        results.filter { $0.status == .written }.count
    }

    public var skippedCount: Int {
        results.filter { $0.status == .skipped }.count
    }

    public var unsupportedCount: Int {
        results.filter { $0.status == .unsupported }.count
    }

    public var failedCount: Int {
        results.filter { $0.status == .failed }.count
    }
}

public enum AppleHealthWritebackPolicy {
    public static func decision(for sample: VaultSample) -> AppleHealthWritebackDecision {
        switch sample.metric {
        case .steps, .heartRate, .restingHeartRate, .activeEnergy, .distance:
            guard sample.numericValue != nil else {
                return AppleHealthWritebackDecision(
                    metric: sample.metric,
                    readiness: .invalid,
                    reason: "A numeric value is required before this metric can be written."
                )
            }
            return AppleHealthWritebackDecision(
                metric: sample.metric,
                readiness: .writeable,
                reason: "This metric maps to a supported Apple Health quantity type."
            )
        case .sleep:
            guard sample.textValue != nil || sample.numericValue != nil else {
                return AppleHealthWritebackDecision(
                    metric: sample.metric,
                    readiness: .invalid,
                    reason: "A sleep stage or duration value is required before sleep can be written."
                )
            }
            return AppleHealthWritebackDecision(
                metric: sample.metric,
                readiness: .writeable,
                reason: "Sleep can be written as an Apple Health sleep analysis category."
            )
        case .workout:
            return AppleHealthWritebackDecision(
                metric: sample.metric,
                readiness: .passportOnly,
                reason: "Workout writeback needs a dedicated workout mapper before it is safe to enable."
            )
        case .hrvSdnn, .hrvRmssd:
            return AppleHealthWritebackDecision(
                metric: sample.metric,
                readiness: .passportOnly,
                reason: "HRV stays Passport-only until semantic mapping and review wording are confirmed."
            )
        }
    }
}
