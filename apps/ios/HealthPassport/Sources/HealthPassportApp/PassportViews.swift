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
                Section {
                    OnboardingPanel()
                        .healthPanelRow()
                }

                Section {
                    ContinuityPanel(summary: appState.continuitySummary)
                        .healthPanelRow()
                }

                Section("Metric readiness") {
                    ForEach(appState.passportMetricSummaries) { metric in
                        MetricRow(metric: metric)
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
                Section {
                    EmptyStatePanel(
                        title: "No source connected yet",
                        detail: "Start with Fitbit/Google, then choose which data types should be preserved before Apple Health writeback."
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

                Section("Writeback Loop") {
                    WritebackLoopPanel(
                        statusMessage: appState.loopStatusMessage,
                        isRunning: appState.isRunningWritebackLoop,
                        runAction: {
                            Task { await appState.runDevelopmentWritebackLoop() }
                        }
                    )
                    .healthPanelRow()
                }

                Section("Fitbit Fixture") {
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
                Section {
                    EmptyStatePanel(
                        title: "Coach is off by default",
                        detail: "Later, you will preview the exact trend summary before anything is sent to an AI provider."
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
                    Text("Encrypted local vault")
                        .healthPanelRow()
                    Text("\(appState.vaultSourceCount) local source")
                        .foregroundStyle(.secondary)
                        .healthPanelRow()
                }

                Section("Privacy") {
                    Text("Local-first vault")
                        .healthPanelRow()
                    Text("AI requires explicit consent")
                        .healthPanelRow()
                    Text("Export and delete controls planned")
                        .healthPanelRow()
                }

                Section("Manual setup") {
                    Text("Apple Developer HealthKit capability")
                        .healthPanelRow()
                    Text("Fitbit/Google developer app")
                        .healthPanelRow()
                }
            }
            .navigationTitle("Settings")
            .healthNavigationTitleMode()
            .healthListChrome()
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
                    .font(.headline)
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

            VStack(alignment: .leading, spacing: 8) {
                ForEach(snapshot.requestedTypes) { type in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(type.name)
                                .font(.subheadline.weight(.semibold))
                            Text(type.direction.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(type.access.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
            }
        }
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
