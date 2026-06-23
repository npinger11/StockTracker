import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case watchlist = "Watchlist"
    case portfolio = "Portfolio"
    case settings  = "Settings"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .watchlist: return "list.bullet.rectangle"
        case .portfolio: return "briefcase"
        case .settings:  return "gear"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var watchlistVM: WatchlistViewModel
    @EnvironmentObject var portfolioVM: PortfolioViewModel

    @State private var selectedTab: AppTab = .watchlist
    @State private var selectedSymbol: String?

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(AppTab.allCases, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 140, ideal: 160)
        } content: {
            // Middle column
            switch selectedTab {
            case .watchlist:
                WatchlistView(selectedSymbol: $selectedSymbol)
            case .portfolio:
                PortfolioView()
            case .settings:
                SettingsView()
            }
        } detail: {
            // Detail column — chart
            if let symbol = selectedSymbol {
                StockDetailView(symbol: symbol)
            } else {
                placeholderDetail
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var placeholderDetail: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 72))
                .foregroundStyle(.quaternary)
            Text("Select a ticker to view its chart")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
