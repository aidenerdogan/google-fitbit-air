import Foundation

public enum VaultMetric: String, Codable, CaseIterable, Sendable {
    case steps
    case workout
    case sleep
    case heartRate
    case restingHeartRate
    case activeEnergy
    case distance
    case hrvSdnn
    case hrvRmssd
}

public enum SampleConfidence: String, Codable, Sendable {
    case high
    case medium
    case low
}

public struct SourceReference: Codable, Hashable, Sendable {
    public let provider: String
    public let deviceModel: String?
    public let appName: String?

    public init(provider: String, deviceModel: String? = nil, appName: String? = nil) {
        self.provider = provider
        self.deviceModel = deviceModel
        self.appName = appName
    }
}

public struct VaultSample: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let metric: VaultMetric
    public let startAt: Date
    public let endAt: Date?
    public let numericValue: Double?
    public let textValue: String?
    public let unit: String?
    public let source: SourceReference
    public let externalId: String?
    public let confidence: SampleConfidence
    public let importedAt: Date

    public init(
        id: String,
        metric: VaultMetric,
        startAt: Date,
        endAt: Date? = nil,
        numericValue: Double? = nil,
        textValue: String? = nil,
        unit: String? = nil,
        source: SourceReference,
        externalId: String? = nil,
        confidence: SampleConfidence = .medium,
        importedAt: Date = Date()
    ) {
        self.id = id
        self.metric = metric
        self.startAt = startAt
        self.endAt = endAt
        self.numericValue = numericValue
        self.textValue = textValue
        self.unit = unit
        self.source = source
        self.externalId = externalId
        self.confidence = confidence
        self.importedAt = importedAt
    }
}

public struct VaultSource: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let provider: String
    public let connectedAt: Date
    public let lastSyncAt: Date?

    public init(id: String, displayName: String, provider: String, connectedAt: Date, lastSyncAt: Date? = nil) {
        self.id = id
        self.displayName = displayName
        self.provider = provider
        self.connectedAt = connectedAt
        self.lastSyncAt = lastSyncAt
    }
}

public struct VaultReceipt: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let sourceId: String
    public let startedAt: Date
    public let finishedAt: Date
    public let imported: Int
    public let writtenToAppleHealth: Int
    public let skippedDuplicates: Int
    public let gapsDetected: Int
    public let unsupportedMetrics: [VaultMetric]

    public init(
        id: String,
        sourceId: String,
        startedAt: Date,
        finishedAt: Date,
        imported: Int,
        writtenToAppleHealth: Int,
        skippedDuplicates: Int = 0,
        gapsDetected: Int = 0,
        unsupportedMetrics: [VaultMetric] = []
    ) {
        self.id = id
        self.sourceId = sourceId
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.imported = imported
        self.writtenToAppleHealth = writtenToAppleHealth
        self.skippedDuplicates = skippedDuplicates
        self.gapsDetected = gapsDetected
        self.unsupportedMetrics = Array(Set(unsupportedMetrics)).sorted { $0.rawValue < $1.rawValue }
    }
}

public struct VaultSnapshot: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var createdAt: Date
    public var updatedAt: Date
    public var sources: [VaultSource]
    public var samples: [VaultSample]
    public var receipts: [VaultReceipt]

    public init(
        schemaVersion: Int = 1,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sources: [VaultSource] = [],
        samples: [VaultSample] = [],
        receipts: [VaultReceipt] = []
    ) {
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sources = sources
        self.samples = samples
        self.receipts = receipts
    }

    public static var empty: VaultSnapshot {
        VaultSnapshot()
    }
}
