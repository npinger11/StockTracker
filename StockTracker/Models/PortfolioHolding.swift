import Foundation

struct PortfolioHolding: Identifiable {
    let id: UUID = UUID()
    let symbol: String
    let name: String
    let quantity: Double
    let institutionPrice: Double
    let institutionValue: Double
    let costBasis: Double?
    let securityType: String

    var gainLoss: Double? {
        guard let costBasis else { return nil }
        return institutionValue - costBasis
    }

    var gainLossPercent: Double? {
        guard let gainLoss, let costBasis, costBasis != 0 else { return nil }
        return (gainLoss / costBasis) * 100
    }
}
