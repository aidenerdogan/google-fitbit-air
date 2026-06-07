import SwiftUI

struct RootView: View {
    @State private var selectedSection: PassportSection = .passport

    var body: some View {
        TabView(selection: $selectedSection) {
            PassportView()
                .tabItem { Text("Passport") }
                .tag(PassportSection.passport)

            SourcesView()
                .tabItem { Text("Sources") }
                .tag(PassportSection.sources)

            ReceiptsView()
                .tabItem { Text("Receipts") }
                .tag(PassportSection.receipts)

            CoachView()
                .tabItem { Text("Coach") }
                .tag(PassportSection.coach)

            SettingsView()
                .tabItem { Text("Settings") }
                .tag(PassportSection.settings)
        }
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
