import Foundation
import Combine

@MainActor
final class PortfolioViewModel: ObservableObject {

    @Published var holdings: [PortfolioHolding] = []
    @Published var isLoading: Bool = false
    @Published var isFetchingLivePrices: Bool = false
    @Published var livePrices: [String: Double] = [:]
    @Published var error: String?

    let plaid = PlaidService()

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Live price helpers

    var hasLivePrices: Bool { !livePrices.isEmpty }

    /// Best available price for a holding: Finnhub live → Plaid institutional fallback.
    func effectivePrice(for h: PortfolioHolding) -> Double {
        livePrices[h.symbol] ?? h.institutionPrice
    }

    func effectiveValue(for h: PortfolioHolding) -> Double {
        effectivePrice(for: h) * h.quantity
    }

    func effectiveGainLoss(for h: PortfolioHolding) -> Double? {
        guard let costBasis = h.costBasis else { return nil }
        return effectiveValue(for: h) - costBasis
    }

    func effectiveGainLossPercent(for h: PortfolioHolding) -> Double? {
        guard let gl = effectiveGainLoss(for: h),
              let cb = h.costBasis, cb != 0 else { return nil }
        return (gl / cb) * 100
    }

    // MARK: - Portfolio summary (live-adjusted)

    var totalValue: Double {
        holdings.reduce(0) { $0 + effectiveValue(for: $1) }
    }

    var totalGainLoss: Double? {
        let withBasis = holdings.filter { $0.costBasis != nil }
        guard !withBasis.isEmpty else { return nil }
        let totalBasis = withBasis.compactMap(\.costBasis).reduce(0, +)
        return totalValue - totalBasis
    }

    var totalGainLossPercent: Double? {
        let withBasis = holdings.filter { $0.costBasis != nil }
        guard !withBasis.isEmpty else { return nil }
        let totalBasis = withBasis.compactMap(\.costBasis).reduce(0, +)
        guard totalBasis != 0 else { return nil }
        return ((totalValue - totalBasis) / totalBasis) * 100
    }

    // MARK: - Init

    init() {
        plaid.$isLinked
            .filter { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.fetchHoldings() }
            .store(in: &cancellables)

        if plaid.hasAccessToken {
            plaid.isLinked = true
        }
    }

    // MARK: - Actions

    func fetchHoldings() {
        guard plaid.hasAccessToken else { return }
        isLoading = true
        error = nil
        Task {
            do {
                holdings = try await plaid.fetchHoldings()
                // Immediately enrich with live prices once holdings are known
                fetchLivePrices()
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }

    /// Fetches the current Finnhub quote for every equity holding in parallel.
    func fetchLivePrices() {
        let symbols = holdings
            .filter { !$0.symbol.isEmpty && $0.symbol != "N/A" }
            .filter { $0.securityType.lowercased() != "mutual fund" }
            .map(\.symbol)
        guard !symbols.isEmpty,
              let apiKey = KeychainHelper.load(for: .finnhubAPIKey),
              !apiKey.isEmpty else { return }

        isFetchingLivePrices = true
        Task {
            await withTaskGroup(of: (String, Double?).self) { group in
                for symbol in symbols {
                    group.addTask { [apiKey] in
                        let price = await Self.fetchQuote(symbol: symbol, apiKey: apiKey)
                        return (symbol, price)
                    }
                }
                for await (symbol, price) in group {
                    if let price { livePrices[symbol] = price }
                }
            }
            isFetchingLivePrices = false
        }
    }

    func disconnect() {
        plaid.disconnectAccount()
        holdings = []
        livePrices = [:]
        error = nil
    }

    // MARK: - Private

    private static func fetchQuote(symbol: String, apiKey: String) async -> Double? {
        guard let url = URL(string:
            "https://finnhub.io/api/v1/quote?symbol=\(symbol)&token=\(apiKey)") else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let quote = try? JSONDecoder().decode(FinnhubQuote.self, from: data),
              quote.c > 0 else { return nil }
        return quote.c
    }
}
