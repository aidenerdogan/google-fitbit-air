import SwiftUI

struct RootView: View {
    @State private var selectedSection: PassportSection = .passport
    @StateObject private var appState = HealthPassportAppState.live()

    var body: some View {
        TabView(selection: $selectedSection) {
            PassportView(appState: appState)
                .tabItem { Text("Passport") }
                .tag(PassportSection.passport)

            SourcesView(appState: appState)
                .tabItem { Text("Sources") }
                .tag(PassportSection.sources)

            ReceiptsView(appState: appState)
                .tabItem { Text("Receipts") }
                .tag(PassportSection.receipts)

            CoachView(appState: appState)
                .tabItem { Text("Coach") }
                .tag(PassportSection.coach)

            SettingsView(appState: appState)
                .tabItem { Text("Settings") }
                .tag(PassportSection.settings)
        }
        .tint(.teal)
    }
}

enum PassportSection: String, CaseIterable, Identifiable {
    case passport
    case sources
    case receipts
    case coach
    case settings

    var id: String { rawValue }
}
