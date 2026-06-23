import SwiftUI

@main
struct StockTrackerApp: App {
    @StateObject private var watchlistVM = WatchlistViewModel()
    @StateObject private var portfolioVM = PortfolioViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(watchlistVM)
                .environmentObject(portfolioVM)
                .frame(minWidth: 960, minHeight: 640)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
