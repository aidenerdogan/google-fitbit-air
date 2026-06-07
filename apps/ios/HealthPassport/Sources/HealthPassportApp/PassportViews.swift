import SwiftUI

struct PassportView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    OnboardingPanel()
                }

                Section {
                    ContinuityPanel(score: 0, status: "Not connected")
                }

                Section("Metric readiness") {
                    ForEach(DemoData.metrics) { metric in
                        MetricRow(metric: metric)
                    }
                }
            }
            .navigationTitle("Health Passport")
        }
    }
}

struct SourcesView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    EmptyStatePanel(
                        title: "No source connected yet",
                        detail: "Start with Fitbit/Google, then choose which data types should be preserved before Apple Health writeback."
                    )
                }

                Section("Planned sources") {
                    SourceRow(name: "Fitbit/Google", status: "First connector")
                    SourceRow(name: "Apple Health", status: "Writeback target")
                }

                Section("Later") {
                    SourceRow(name: "Garmin", status: "Not in MVP")
                    SourceRow(name: "Oura", status: "Not in MVP")
                    SourceRow(name: "WHOOP", status: "Not in MVP")
                }
            }
            .navigationTitle("Sources")
        }
    }
}

struct ReceiptsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    EmptyStatePanel(
                        title: "Receipts will appear after first sync",
                        detail: "Each receipt will show imported, written, skipped, unsupported, and failed records."
                    )
                }

                Section("Latest") {
                    ForEach(DemoData.receipts) { receipt in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(receipt.source)
                                .font(.headline)
                            Text(receipt.status)
                                .foregroundStyle(.secondary)
                            HStack {
                                ReceiptCount(label: "Imported", value: receipt.imported)
                                ReceiptCount(label: "Written", value: receipt.written)
                                ReceiptCount(label: "Skipped", value: receipt.skipped)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .navigationTitle("Receipts")
        }
    }
}

struct CoachView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    EmptyStatePanel(
                        title: "Coach is off by default",
                        detail: "Later, you will preview the exact trend summary before anything is sent to an AI provider."
                    )
                }

                Section("Coach mode") {
                    Text("The coach will explain trends and gaps after you approve a small context summary.")
                    Text("No diagnosis, treatment, or automatic health-data sharing.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Coach")
        }
    }
}

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Vault") {
                    Text("Encrypted local vault")
                    Text("\(DemoData.vaultPreview.sources.count) planned local source")
                        .foregroundStyle(.secondary)
                }

                Section("Privacy") {
                    Text("Local-first vault")
                    Text("AI requires explicit consent")
                    Text("Export and delete controls planned")
                }

                Section("Manual setup") {
                    Text("Apple Developer HealthKit capability")
                    Text("Fitbit/Google developer app")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

private struct OnboardingPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Start privately")
                .font(.headline)
            Text("Health Passport will guide you through source connection, Apple Health permissions, and local encrypted storage before any sync.")
                .foregroundStyle(.secondary)

            ForEach(DemoData.onboardingSteps) { step in
                VStack(alignment: .leading, spacing: 4) {
                    Text(step.title)
                        .font(.subheadline.weight(.semibold))
                    Text(step.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 8)
    }
}

private struct EmptyStatePanel: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

private struct ContinuityPanel: View {
    let score: Int
    let status: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Continuity Score")
                .font(.headline)
            Text("\(score)")
                .font(.system(size: 44, weight: .semibold, design: .rounded))
            Text(status)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
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
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(metric.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
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
        .padding(.vertical, 4)
    }
}

private struct ReceiptCount: View {
    let label: String
    let value: Int

    var body: some View {
        VStack(alignment: .leading) {
            Text("\(value)")
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
