import Foundation

struct StockTicker: Identifiable, Codable, Equatable {
    var id: UUID
    var symbol: String
    var name: String
    var livePrice: Double?
    var previousClose: Double?
    var addedAt: Date

    var change: Double? {
        guard let livePrice, let previousClose else { return nil }
        return livePrice - previousClose
    }

    var changePercent: Double? {
        guard let change, let previousClose, previousClose != 0 else { return nil }
        return (change / previousClose) * 100
    }

    init(symbol: String, name: String) {
        self.id = UUID()
        self.symbol = symbol.uppercased()
        self.name = name
        self.addedAt = Date()
    }
}
