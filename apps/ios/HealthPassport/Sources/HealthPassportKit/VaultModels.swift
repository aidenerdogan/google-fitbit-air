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
    public let skippedWriteback: Int
    public let skippedDuplicates: Int
    public let gapsDetected: Int
    public let failedToAppleHealth: Int
    public let unsupportedMetrics: [VaultMetric]

    public init(
        id: String,
        sourceId: String,
        startedAt: Date,
        finishedAt: Date,
        imported: Int,
        writtenToAppleHealth: Int,
        skippedWriteback: Int = 0,
        skippedDuplicates: Int = 0,
        gapsDetected: Int = 0,
        failedToAppleHealth: Int = 0,
        unsupportedMetrics: [VaultMetric] = []
    ) {
        self.id = id
        self.sourceId = sourceId
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.imported = imported
        self.writtenToAppleHealth = writtenToAppleHealth
        self.skippedWriteback = skippedWriteback
        self.skippedDuplicates = skippedDuplicates
        self.gapsDetected = gapsDetected
        self.failedToAppleHealth = failedToAppleHealth
        self.unsupportedMetrics = Array(Set(unsupportedMetrics)).sorted { $0.rawValue < $1.rawValue }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case sourceId
        case startedAt
        case finishedAt
        case imported
        case writtenToAppleHealth
        case skippedWriteback
        case skippedDuplicates
        case gapsDetected
        case failedToAppleHealth
        case unsupportedMetrics
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.sourceId = try container.decode(String.self, forKey: .sourceId)
        self.startedAt = try container.decode(Date.self, forKey: .startedAt)
        self.finishedAt = try container.decode(Date.self, forKey: .finishedAt)
        self.imported = try container.decode(Int.self, forKey: .imported)
        self.writtenToAppleHealth = try container.decode(Int.self, forKey: .writtenToAppleHealth)
        self.skippedWriteback = try container.decodeIfPresent(Int.self, forKey: .skippedWriteback) ?? 0
        self.skippedDuplicates = try container.decodeIfPresent(Int.self, forKey: .skippedDuplicates) ?? 0
        self.gapsDetected = try container.decodeIfPresent(Int.self, forKey: .gapsDetected) ?? 0
        self.failedToAppleHealth = try container.decodeIfPresent(Int.self, forKey: .failedToAppleHealth) ?? 0
        let unsupportedMetrics = try container.decodeIfPresent([VaultMetric].self, forKey: .unsupportedMetrics) ?? []
        self.unsupportedMetrics = Array(Set(unsupportedMetrics)).sorted { $0.rawValue < $1.rawValue }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(sourceId, forKey: .sourceId)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(finishedAt, forKey: .finishedAt)
        try container.encode(imported, forKey: .imported)
        try container.encode(writtenToAppleHealth, forKey: .writtenToAppleHealth)
        try container.encode(skippedWriteback, forKey: .skippedWriteback)
        try container.encode(skippedDuplicates, forKey: .skippedDuplicates)
        try container.encode(gapsDetected, forKey: .gapsDetected)
        try container.encode(failedToAppleHealth, forKey: .failedToAppleHealth)
        try container.encode(unsupportedMetrics, forKey: .unsupportedMetrics)
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

public enum PassportMetricCoverageStatus: String, Codable, Sendable {
    case ready
    case gap
    case blocked
    case passportOnly
}

public struct PassportMetricCoverage: Identifiable, Hashable, Sendable {
    public var id: String { metric.rawValue }

    public let metric: VaultMetric
    public let status: PassportMetricCoverageStatus
    public let sampleCount: Int
    public let sourceProviders: [String]
    public let firstSampleAt: Date?
    public let lastSampleAt: Date?
    public let missingDays: [Date]

    public init(
        metric: VaultMetric,
        status: PassportMetricCoverageStatus,
        sampleCount: Int,
        sourceProviders: [String],
        firstSampleAt: Date?,
        lastSampleAt: Date?,
        missingDays: [Date]
    ) {
        self.metric = metric
        self.status = status
        self.sampleCount = sampleCount
        self.sourceProviders = sourceProviders
        self.firstSampleAt = firstSampleAt
        self.lastSampleAt = lastSampleAt
        self.missingDays = missingDays
    }
}

public struct PassportGapAnalysis: Hashable, Sendable {
    public let windowStart: Date
    public let windowEnd: Date
    public let metrics: [PassportMetricCoverage]

    public init(windowStart: Date, windowEnd: Date, metrics: [PassportMetricCoverage]) {
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.metrics = metrics
    }

    public var totalMissingDays: Int {
        metrics.reduce(0) { $0 + $1.missingDays.count }
    }

    public var readyMetricCount: Int {
        metrics.filter { $0.status == .ready || $0.status == .passportOnly }.count
    }

    public var continuityScore: Int {
        guard !metrics.isEmpty else { return 0 }
        return Int((Double(readyMetricCount) / Double(metrics.count) * 100).rounded())
    }
}

public enum PassportGapAnalyzer {
    public static let defaultMetrics: [VaultMetric] = [
        .steps,
        .workout,
        .sleep,
        .heartRate,
        .restingHeartRate,
        .activeEnergy,
        .distance,
        .hrvRmssd
    ]

    public static func analyze(
        snapshot: VaultSnapshot,
        metrics: [VaultMetric] = defaultMetrics,
        windowStart: Date? = nil,
        windowEnd: Date? = nil,
        calendar: Calendar = utcCalendar
    ) -> PassportGapAnalysis {
        let inferredStart = windowStart ?? snapshot.samples.map(\.startAt).min() ?? calendar.startOfDay(for: windowEnd ?? Date())
        let inferredEnd = windowEnd ?? snapshot.samples.map { $0.endAt ?? $0.startAt }.max() ?? inferredStart
        let dayStarts = dayStartsBetween(inferredStart, and: inferredEnd, calendar: calendar)

        let coverages = metrics.map { metric in
            let metricSamples = snapshot.samples
                .filter { $0.metric == metric }
                .sorted { $0.startAt < $1.startAt }
            let missingDays = dayStarts.filter { dayStart in
                !metricSamples.contains { sample in
                    sampleOverlaps(sample, dayStart: dayStart, calendar: calendar)
                }
            }
            let sourceProviders = Array(Set(metricSamples.map(\.source.provider))).sorted()
            let status = coverageStatus(for: metric, sampleCount: metricSamples.count, missingDayCount: missingDays.count)

            return PassportMetricCoverage(
                metric: metric,
                status: status,
                sampleCount: metricSamples.count,
                sourceProviders: sourceProviders,
                firstSampleAt: metricSamples.first?.startAt,
                lastSampleAt: metricSamples.last.map { $0.endAt ?? $0.startAt },
                missingDays: missingDays
            )
        }

        return PassportGapAnalysis(windowStart: inferredStart, windowEnd: inferredEnd, metrics: coverages)
    }

    public static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }()

    private static func coverageStatus(
        for metric: VaultMetric,
        sampleCount: Int,
        missingDayCount: Int
    ) -> PassportMetricCoverageStatus {
        if metric == .hrvRmssd || metric == .hrvSdnn {
            return sampleCount > 0 ? .passportOnly : .blocked
        }
        if sampleCount == 0 {
            return .blocked
        }
        return missingDayCount > 0 ? .gap : .ready
    }

    private static func dayStartsBetween(_ start: Date, and end: Date, calendar: Calendar) -> [Date] {
        var days: [Date] = []
        var cursor = calendar.startOfDay(for: start)
        let finalDay = calendar.startOfDay(for: end)

        while cursor <= finalDay {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        return days
    }

    private static func sampleOverlaps(_ sample: VaultSample, dayStart: Date, calendar: Calendar) -> Bool {
        guard let dayEnd = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: dayStart) else {
            return false
        }

        let sampleEnd = sample.endAt ?? sample.startAt
        return sample.startAt <= dayEnd && sampleEnd >= dayStart
    }
}
