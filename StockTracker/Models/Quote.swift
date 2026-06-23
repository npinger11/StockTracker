import Foundation

// MARK: - Finnhub WebSocket message

enum FinnhubMessage: Decodable {
    case trade(TradeMessage)
    case ping
    case unknown

    private enum CodingKeys: String, CodingKey {
        case type, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type_ = try container.decode(String.self, forKey: .type)
        switch type_ {
        case "trade":
            let trades = (try? container.decode([Trade].self, forKey: .data)) ?? []
            self = .trade(TradeMessage(trades: trades))
        case "ping":
            self = .ping
        default:
            self = .unknown
        }
    }
}

struct TradeMessage {
    let trades: [Trade]
}

struct Trade: Decodable {
    let symbol: String
    let price: Double
    let timestamp: Double
    let volume: Double

    private enum CodingKeys: String, CodingKey {
        case symbol = "s"
        case price = "p"
        case timestamp = "t"
        case volume = "v"
    }
}

// MARK: - Finnhub symbol search

struct SymbolSearchResult: Decodable {
    let description: String
    let displaySymbol: String
    let symbol: String
    let type: String
}

struct SymbolSearchResponse: Decodable {
    let count: Int
    let result: [SymbolSearchResult]
}

// MARK: - Finnhub quote (REST)

struct FinnhubQuote: Decodable {
    /// Current price
    let c: Double
    /// Previous close
    let pc: Double
}
