import Foundation
import Combine

@MainActor
final class PortfolioViewModel: ObservableObject {

    @Published var holdings: [PortfolioHolding] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    let plaid = PlaidService()

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Summary

    var totalValue: Double {
        holdings.reduce(0) { $0 + $1.institutionValue }
    }

    var totalGainLoss: Double? {
        let withBasis = holdings.compactMap(\.costBasis)
        guard !withBasis.isEmpty else { return nil }
        let totalBasis = withBasis.reduce(0, +)
        return totalValue - totalBasis
    }

    var totalGainLossPercent: Double? {
        let withBasis = holdings.compactMap(\.costBasis)
        guard !withBasis.isEmpty else { return nil }
        let totalBasis = withBasis.reduce(0, +)
        guard totalBasis != 0 else { return nil }
        return ((totalValue - totalBasis) / totalBasis) * 100
    }

    // MARK: - Init

    init() {
        // Auto-fetch when Plaid becomes linked
        plaid.$isLinked
            .filter { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.fetchHoldings() }
            .store(in: &cancellables)

        // If we already have an access token from a previous session, mark as linked
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
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }

    func disconnect() {
        plaid.disconnectAccount()
        holdings = []
        error = nil
    }
}
