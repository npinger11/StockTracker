import Foundation
import Combine

@MainActor
final class WatchlistViewModel: ObservableObject {

    @Published var tickers: [StockTicker] = []
    @Published var searchResults: [SymbolSearchResult] = []
    @Published var isSearching: Bool = false

    let finnhub = FinnhubService()

    private var cancellables = Set<AnyCancellable>()
    private let storageURL: URL

    // MARK: - Init

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("StockTracker", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("watchlist.json")

        loadFromDisk()
        startLiveUpdates()
        observePrices()
    }

    // MARK: - Public interface

    func addTicker(symbol: String, name: String) {
        let sym = symbol.uppercased()
        guard !tickers.contains(where: { $0.symbol == sym }) else { return }
        tickers.append(StockTicker(symbol: sym, name: name))
        saveToDisk()
        finnhub.addSymbol(sym)
    }

    func removeTicker(at offsets: IndexSet) {
        let removed = offsets.map { tickers[$0].symbol }
        tickers.remove(atOffsets: offsets)
        saveToDisk()
        removed.forEach { finnhub.removeSymbol($0) }
    }

    func removeTicker(symbol: String) {
        tickers.removeAll { $0.symbol == symbol }
        saveToDisk()
        finnhub.removeSymbol(symbol)
    }

    func searchSymbols(query: String) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        isSearching = true
        Task {
            searchResults = (try? await finnhub.searchSymbols(query: query)) ?? []
            isSearching = false
        }
    }

    // MARK: - Live updates

    private func startLiveUpdates() {
        finnhub.connect(symbols: tickers.map(\.symbol))
    }

    private func observePrices() {
        finnhub.$latestPrices
            .receive(on: RunLoop.main)
            .sink { [weak self] prices in
                guard let self else { return }
                for i in self.tickers.indices {
                    if let p = prices[self.tickers[i].symbol] {
                        self.tickers[i].livePrice = p
                    }
                }
            }
            .store(in: &cancellables)

        finnhub.$previousCloses
            .receive(on: RunLoop.main)
            .sink { [weak self] closes in
                guard let self else { return }
                for i in self.tickers.indices {
                    if let pc = closes[self.tickers[i].symbol] {
                        self.tickers[i].previousClose = pc
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Persistence

    private struct PersistedTicker: Codable {
        let id: UUID
        let symbol: String
        let name: String
        let addedAt: Date
    }

    private func saveToDisk() {
        let data = tickers.map {
            PersistedTicker(id: $0.id, symbol: $0.symbol, name: $0.name, addedAt: $0.addedAt)
        }
        if let encoded = try? JSONEncoder().encode(data) {
            try? encoded.write(to: storageURL)
        }
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: storageURL),
              let saved = try? JSONDecoder().decode([PersistedTicker].self, from: data) else { return }
        tickers = saved.map {
            var t = StockTicker(symbol: $0.symbol, name: $0.name)
            t.id = $0.id
            t.addedAt = $0.addedAt
            return t
        }
    }
}
