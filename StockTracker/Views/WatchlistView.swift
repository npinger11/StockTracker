import SwiftUI

struct WatchlistView: View {
    @EnvironmentObject var vm: WatchlistViewModel
    @Binding var selectedSymbol: String?
    @State private var showAdd = false

    var body: some View {
        List(vm.tickers, selection: $selectedSymbol) { ticker in
            TickerRow(ticker: ticker)
                .tag(ticker.symbol)
                .contextMenu {
                    Button(role: .destructive) {
                        if selectedSymbol == ticker.symbol { selectedSymbol = nil }
                        vm.removeTicker(symbol: ticker.symbol)
                    } label: {
                        Label("Remove from Watchlist", systemImage: "trash")
                    }
                }
        }
        .listStyle(.inset)
        .navigationTitle("Watchlist")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                ConnectionBadge(isConnected: vm.finnhub.isConnected)

                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add ticker")
            }
        }
        .overlay {
            if vm.tickers.isEmpty {
                emptyState
            }
        }
        .sheet(isPresented: $showAdd) {
            AddTickerView()
                .environmentObject(vm)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "plus.circle.dashed")
                .font(.system(size: 52))
                .foregroundStyle(.quaternary)
            Text("No tickers yet")
                .font(.title3.bold())
                .foregroundStyle(.secondary)
            Text("Tap  +  to add your first stock.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Ticker row

struct TickerRow: View {
    let ticker: StockTicker

    var body: some View {
        HStack(spacing: 10) {
            // Symbol & name
            VStack(alignment: .leading, spacing: 2) {
                Text(ticker.symbol)
                    .font(.headline)
                Text(ticker.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            // Price & change
            VStack(alignment: .trailing, spacing: 2) {
                if let price = ticker.livePrice {
                    Text(price, format: .currency(code: "USD"))
                        .font(.headline.monospacedDigit())
                } else {
                    Text("—")
                        .font(.headline)
                        .foregroundStyle(.tertiary)
                }
                if let pct = ticker.changePercent {
                    changeLabel(pct)
                }
            }
        }
        .padding(.vertical, 3)
    }

    private func changeLabel(_ pct: Double) -> some View {
        HStack(spacing: 2) {
            Image(systemName: pct >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2.bold())
            Text(String(format: "%.2f%%", abs(pct)))
                .font(.caption.monospacedDigit())
        }
        .foregroundStyle(pct >= 0 ? Color.green : Color.red)
    }
}

// MARK: - Live connection badge

struct ConnectionBadge: View {
    let isConnected: Bool
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isConnected ? Color.green : Color.orange)
                .frame(width: 7, height: 7)
            Text(isConnected ? "Live" : "Connecting…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
