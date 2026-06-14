import HealthPassportKit
import SwiftUI

#if os(iOS) && canImport(UIKit)
import UIKit
#endif

struct PassportView: View {
    @ObservedObject var appState: HealthPassportAppState

    var body: some View {
        NavigationStack {
            List {
                if appState.vaultSnapshot.samples.isEmpty {
                    Section {
                        OnboardingPanel()
                            .healthPanelRow()
                    }
                }

                Section {
                    PassportOverviewPanel(
                        summary: appState.continuitySummary,
                        sampleCount: appState.vaultSnapshot.samples.count,
                        sourceCount: appState.vaultSourceCount,
                        receiptCount: appState.vaultSnapshot.receipts.count
                    )
                    .healthPanelRow()
                }

                if !appState.passportMetricSummaries.isEmpty {
                    Section("Readiness") {
                        MetricReadinessPanel(metrics: appState.passportMetricSummaries)
                            .healthPanelRow()
                    }
                }

                Section("Timeline") {
                    PassportFilterPanel(appState: appState)
                        .healthPanelRow()

                    if appState.passportTimelineDays.isEmpty {
                        EmptyStatePanel(
                            title: "No samples match these filters",
                            detail: "Import a source or clear filters to see preserved records."
                        )
                        .healthPanelRow()
                    } else {
                        ForEach(appState.passportTimelineDays) { day in
                            TimelineDayPanel(day: day)
                                .healthPanelRow()
                        }
                    }
                }
            }
            .navigationTitle("Health Passport")
            .healthNavigationTitleMode()
            .healthListChrome()
        }
    }
}

private struct PassportFilterPanel: View {
    @ObservedObject var appState: HealthPassportAppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits {
                HStack(spacing: 8) {
                    filterMenus
                }
                VStack(alignment: .leading, spacing: 8) {
                    filterMenus
                }
            }

            if appState.passportMetricFilter != nil || appState.passportSourceFilter != nil {
                Button("Clear filters") {
                    appState.clearPassportFilters()
                }
                .buttonStyle(.borderless)
                .font(.footnote.weight(.semibold))
            }
        }
    }

    private var filterMenus: some View {
        Group {
            metricMenu
            sourceMenu
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 8))
        .controlSize(.small)
    }

    private var metricMenu: some View {
        Menu {
            Button("All metrics") {
                appState.passportMetricFilter = nil
            }

            ForEach(appState.passportMetricFilterOptions) { option in
                Button(option.label) {
                    appState.passportMetricFilter = option.metric
                }
            }
        } label: {
            Text(appState.selectedPassportMetricFilterLabel)
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
    }

    private var sourceMenu: some View {
        Menu {
            Button("All sources") {
                appState.passportSourceFilter = nil
            }

            ForEach(appState.passportSourceFilterOptions) { option in
                Button(option.label) {
                    appState.passportSourceFilter = option.sourceProvider
                }
            }
        } label: {
            Text(appState.selectedPassportSourceFilterLabel)
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
    }
}

private struct TimelineDayPanel: View {
    let day: PassportTimelineDay

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(day.date, format: .dateTime.weekday(.wide).month().day())
                .font(.headline)

            ForEach(day.items) { item in
                TimelineItemRow(item: item)
            }
        }
    }
}

private struct TimelineItemRow: View {
    let item: PassportTimelineItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(item.date, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    timelineBadges
                }
                VStack(alignment: .leading, spacing: 6) {
                    timelineBadges
                }
            }

            Text(item.value)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }

    private var timelineBadges: some View {
        Group {
            TimelineBadge(text: item.source, color: .teal)
            TimelineBadge(text: item.confidence, color: confidenceColor)
            TimelineBadge(text: item.status, color: statusColor)
        }
    }

    private var confidenceColor: Color {
        switch item.confidence {
        case "High confidence":
            return .green
        case "Medium confidence":
            return .orange
        default:
            return .gray
        }
    }

    private var statusColor: Color {
        switch item.statusKind {
        case .ready:
            return .green
        case .gap:
            return .orange
        case .blocked:
            return .red
        case .unsupported:
            return .gray
        }
    }
}

private struct TimelineBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 7))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
    }
}

struct SourcesView: View {
    @ObservedObject var appState: HealthPassportAppState

    var body: some View {
        NavigationStack {
            List {
                if appState.connectedSourceSummaries.isEmpty {
                    Section {
                        EmptyStatePanel(
                            title: "No source connected yet",
                            detail: "Start with Fitbit/Google, then choose which data types should be preserved before Apple Health writeback."
                        )
                        .healthPanelRow()
                    }
                } else {
                    Section("Connected sources") {
                        ForEach(appState.connectedSourceSummaries) { source in
                            ConnectedSourceRow(source: source)
                                .healthPanelRow()
                        }
                    }
                }

                Section("Google Health") {
                    GoogleHealthConnectionPanel(
                        status: appState.googleConnectionStatus,
                        isConnecting: appState.isConnectingGoogleHealth,
                        connectAction: {
                            Task { await appState.connectGoogleHealth() }
                        }
                    )
                    .healthPanelRow()
                }

                Section("Apple Health") {
                    HealthPermissionPanel(
                        snapshot: appState.permissionSnapshot,
                        isRequesting: appState.isRequestingAppleHealth,
                        requestAction: {
                            Task { await appState.requestAppleHealthAccess() }
                        }
                    )
                    .healthPanelRow()
                }

                Section("Developer tools") {
                    WritebackLoopPanel(
                        statusMessage: appState.loopStatusMessage,
                        isRunning: appState.isRunningWritebackLoop,
                        runAction: {
                            Task { await appState.runDevelopmentWritebackLoop() }
                        }
                    )
                    .healthPanelRow()

                    FixtureImportPanel(
                        statusMessage: appState.fitbitImportStatusMessage,
                        isImporting: appState.isImportingFitbitFixture,
                        importAction: {
                            Task { await appState.importFitbitFixture() }
                        }
                    )
                    .healthPanelRow()
                }

                Section("Planned sources") {
                    SourceRow(name: "Fitbit/Google", status: "First connector")
                        .healthPanelRow()
                    SourceRow(name: "Apple Health", status: "Writeback target")
                        .healthPanelRow()
                }

                Section("Later") {
                    SourceRow(name: "Garmin", status: "Not in MVP")
                        .healthPanelRow()
                    SourceRow(name: "Oura", status: "Not in MVP")
                        .healthPanelRow()
                    SourceRow(name: "WHOOP", status: "Not in MVP")
                        .healthPanelRow()
                }
            }
            .navigationTitle("Sources")
            .healthNavigationTitleMode()
            .healthListChrome()
        }
    }
}

struct ReceiptsView: View {
    @ObservedObject var appState: HealthPassportAppState

    var body: some View {
        NavigationStack {
            List {
                if appState.vaultSnapshot.receipts.isEmpty {
                    Section {
                        EmptyStatePanel(
                            title: "Receipts will appear after first sync",
                            detail: "Each receipt will show imported, written, skipped, unsupported, and failed records."
                        )
                        .healthPanelRow()
                    }
                }

                Section("Latest") {
                    ForEach(appState.receiptSummaries) { receipt in
                        ReceiptSummaryRow(receipt: receipt)
                            .healthPanelRow()
                    }
                }
            }
            .navigationTitle("Receipts")
            .healthNavigationTitleMode()
            .healthListChrome()
        }
    }
}

struct CoachView: View {
    @ObservedObject var appState: HealthPassportAppState

    var body: some View {
        NavigationStack {
            List {
                if appState.vaultSnapshot.samples.isEmpty {
                    Section {
                        EmptyStatePanel(
                            title: "Coach is off by default",
                            detail: "Later, you will preview the exact trend summary before anything is sent to an AI provider."
                        )
                        .healthPanelRow()
                    }
                }

                Section {
                    EmptyStatePanel(
                        title: "Local-only preview",
                        detail: "This screen summarizes vault coverage and gaps without sending raw samples anywhere."
                    )
                    .healthPanelRow()
                }

                Section("Local preview") {
                    CoachContextPanel(preview: appState.coachContextPreview)
                        .healthPanelRow()
                }

                Section("Consent") {
                    CoachConsentPanel(
                        status: appState.coachConsentStatus,
                        canApprove: appState.canApproveCoachContext,
                        approve: appState.approveCoachContextPreview,
                        cancel: appState.cancelCoachContextPreview
                    )
                    .healthPanelRow()
                }
            }
            .navigationTitle("Coach")
            .healthNavigationTitleMode()
            .healthListChrome()
        }
    }
}

private struct CoachContextPanel: View {
    let preview: CoachContextPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(preview.title)
                .font(.headline)

            CoachLineGroup(title: "Summary", lines: preview.summaryLines)
            CoachLineGroup(title: "Gaps", lines: preview.gapLines)
            CoachLineGroup(title: "Receipts", lines: preview.receiptLines)

            Text(preview.footer)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct CoachLineGroup: View {
    let title: String
    let lines: [String]

    var body: some View {
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct CoachConsentPanel: View {
    let status: CoachConsentStatus
    let canApprove: Bool
    let approve: () -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(status.title)
                .font(.headline)
            Text(status.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)

            ViewThatFits {
                HStack(spacing: 10) {
                    consentButtons
                }
                VStack(alignment: .leading, spacing: 8) {
                    consentButtons
                }
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: 8))
            .controlSize(.regular)

            Text(canApprove ? "Approval only unlocks a future send step." : "Import local source data before approving a coach context.")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var consentButtons: some View {
        Group {
            Button("Approve Preview", action: approve)
                .disabled(!canApprove)
            Button("Cancel", role: .cancel, action: cancel)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var appState: HealthPassportAppState

    var body: some View {
        NavigationStack {
            List {
                Section("Vault") {
                    SettingsStatusPanel(
                        title: "Encrypted local vault",
                        detail: "Stored on this device. Raw samples stay local unless a future export or backup is approved.",
                        facts: [
                            ("Sources", "\(appState.vaultSourceCount)"),
                            ("Samples", "\(appState.vaultSnapshot.samples.count)"),
                            ("Receipts", "\(appState.vaultSnapshot.receipts.count)")
                        ]
                    )
                    .healthPanelRow()
                }

                Section("Privacy") {
                    SettingsChecklistRow(title: "Local-first vault", status: "Active", color: .green)
                        .healthPanelRow()
                    SettingsChecklistRow(title: "AI requires explicit consent", status: "Active", color: .green)
                        .healthPanelRow()
                    SettingsChecklistRow(title: "Export and delete controls", status: "Planned", color: .orange)
                        .healthPanelRow()
                }

                Section("Manual setup") {
                    SettingsChecklistRow(title: "Apple Developer HealthKit capability", status: "Done", color: .green)
                        .healthPanelRow()
                    SettingsChecklistRow(title: "Fitbit/Google developer app", status: "Done", color: .green)
                        .healthPanelRow()
                    SettingsChecklistRow(title: "Google Sign-In in app", status: "Next", color: .teal)
                        .healthPanelRow()
                }
            }
            .navigationTitle("Settings")
            .healthNavigationTitleMode()
            .healthListChrome()
        }
    }
}

private struct PassportOverviewPanel: View {
    let summary: ContinuitySummary
    let sampleCount: Int
    let sourceCount: Int
    let receiptCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Vault overview")
                        .font(.headline)
                    Text(summary.status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(summary.score)")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text("Continuity")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                SummaryPill(label: "Samples", value: sampleCount)
                SummaryPill(label: "Sources", value: sourceCount)
                SummaryPill(label: "Receipts", value: receiptCount)
            }
        }
    }
}

private struct SummaryPill: View {
    let label: String
    let value: Int

    var body: some View {
        VStack(spacing: 1) {
            Text("\(value)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(Color.teal.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct MetricReadinessPanel: View {
    let metrics: [PassportMetric]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(metrics.prefix(4)) { metric in
                MetricRow(metric: metric)
                if metric.id != metrics.prefix(4).last?.id {
                    Divider()
                }
            }

            if metrics.count > 4 {
                Text("\(metrics.count - 4) more metrics tracked in the local vault.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct OnboardingPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Start privately")
                .font(.headline)
            Text("Health Passport will guide you through source connection, Apple Health permissions, and local encrypted storage before any sync.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(DemoData.onboardingSteps) { step in
                VStack(alignment: .leading, spacing: 4) {
                    Text(step.title)
                        .font(.subheadline.weight(.semibold))
                    Text(step.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct EmptyStatePanel: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ContinuityPanel: View {
    let summary: ContinuitySummary

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Continuity Score")
                    .font(.headline)
                Text(summary.status)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(summary.score)")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
    }
}

private struct MetricRow: View {
    let metric: PassportMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(metric.name)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(metric.status.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(statusColor)
            }
            Text(metric.source)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(metric.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch metric.status {
        case .ready: .green
        case .gap: .orange
        case .blocked: .red
        case .unsupported: .gray
        }
    }
}

private struct SourceRow: View {
    let name: String
    let status: String

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(name)
                    .font(.headline)
                Text(status)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

private struct ConnectedSourceRow: View {
    let source: ConnectedSourceSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.name)
                        .font(.headline)
                    Text(source.provider)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(source.sampleCount)")
                        .font(.headline.monospacedDigit())
                    Text(source.sampleCount == 1 ? "Sample" : "Samples")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                SourceMetaLabel(title: "Connected", date: source.connectedAt)
                if let lastSyncAt = source.lastSyncAt {
                    SourceMetaLabel(title: "Last sync", date: lastSyncAt)
                } else {
                    Text("No sync receipt yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("\(source.receiptCount) receipt\(source.receiptCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct GoogleHealthConnectionPanel: View {
    let status: ProviderOAuthConnectionStatus
    let isConnecting: Bool
    let connectAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(status.title)
                        .font(.headline)
                    Text(status.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(statusBadge)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(statusColor)
            }

            Button(isConnecting ? "Connecting..." : "Connect Google Health", action: connectAction)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 8))
                .controlSize(.regular)
                .disabled(isConnecting || status == .notConfigured)

            Text("Read-only Google scopes are requested. Tokens are saved in Keychain, not in app files.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusBadge: String {
        switch status {
        case .notConfigured:
            return "config"
        case .ready:
            return "ready"
        case .connected:
            return "saved"
        case .failed:
            return "check"
        }
    }

    private var statusColor: Color {
        switch status {
        case .notConfigured:
            return .orange
        case .ready:
            return .teal
        case .connected:
            return .green
        case .failed:
            return .red
        }
    }
}

private struct SourceMetaLabel: View {
    let title: String
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(date, format: .dateTime.month().day().hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct HealthPermissionPanel: View {
    @Environment(\.openURL) private var openURL

    let snapshot: HealthPermissionSnapshot
    let isRequesting: Bool
    let requestAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Writeback access")
                        .font(.headline)
                    Text(snapshot.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(snapshot.status.rawValue)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(permissionColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(permissionColor)
            }

            Button(isRequesting ? "Requesting..." : "Review Apple Health Access", action: requestAction)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 8))
            .controlSize(.regular)
            .disabled(isRequesting)

            if snapshot.status.needsSettingsRecovery {
                VStack(alignment: .leading, spacing: 8) {
                    Text(snapshot.status.recoveryHint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let settingsURL {
                        Button("Open App Settings") {
                            openURL(settingsURL)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                        .controlSize(.small)
                    }
                }
            }

            LazyVGrid(columns: permissionColumns, alignment: .leading, spacing: 8) {
                ForEach(snapshot.requestedTypes) { type in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(type.name)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Text("\(type.direction.rawValue) • \(type.access.rawValue)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private var permissionColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
    }

    private var permissionColor: Color {
        switch snapshot.status {
        case .notRequested: .secondary
        case .granted: .green
        case .partiallyGranted: .orange
        case .denied: .red
        case .unavailable: .gray
        }
    }

    private var settingsURL: URL? {
        #if os(iOS) && canImport(UIKit)
        URL(string: UIApplication.openSettingsURLString)
        #else
        nil
        #endif
    }
}

private struct WritebackLoopPanel: View {
    let statusMessage: String
    let isRunning: Bool
    let runAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sample writeback")
                        .font(.headline)
                    Text(statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Button(isRunning ? "Writing..." : "Run Sample Writeback", action: runAction)
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: 8))
            .controlSize(.regular)
            .disabled(isRunning)
        }
    }
}

private struct FixtureImportPanel: View {
    let statusMessage: String
    let isImporting: Bool
    let importAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Source import")
                    .font(.headline)
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button(isImporting ? "Importing..." : "Import Fitbit Fixture", action: importAction)
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: 8))
            .controlSize(.regular)
            .disabled(isImporting)
        }
    }
}

private struct ReceiptSummaryRow: View {
    let receipt: SyncReceiptSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(receipt.source)
                    .font(.headline)
                Spacer()
                if let finishedAt = receipt.finishedAt {
                    Text(finishedAt, format: .dateTime.month().day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(receipt.status)
                .font(.footnote)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: receiptColumns, alignment: .leading, spacing: 10) {
                ReceiptCount(label: "Imported", value: receipt.imported)
                ReceiptCount(label: "Written", value: receipt.written)
                ReceiptCount(label: "Skipped", value: receipt.skipped)
                ReceiptCount(label: "Unsupported", value: receipt.unsupported)
                ReceiptCount(label: "Failed", value: receipt.failed)
            }
        }
    }

    private var receiptColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
    }
}

private struct SettingsStatusPanel: View {
    let title: String
    let detail: String
    let facts: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(facts, id: \.0) { fact in
                    VStack(spacing: 1) {
                        Text(fact.1)
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                        Text(fact.0)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

private struct SettingsChecklistRow: View {
    let title: String
    let status: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(status)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(color)
        }
    }
}

private struct ReceiptCount: View {
    let label: String
    let value: Int

    var body: some View {
        VStack(alignment: .leading) {
            Text("\(value)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HealthPanelRowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 8)
            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.055))
                    .padding(.vertical, 3)
            )
    }
}

private extension View {
    func healthPanelRow() -> some View {
        modifier(HealthPanelRowModifier())
    }

    func healthListChrome() -> some View {
        listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.top, 8, for: .scrollContent)
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .contentMargins(.bottom, 110, for: .scrollContent)
            .background(.background)
    }

    @ViewBuilder
    func healthNavigationTitleMode() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
