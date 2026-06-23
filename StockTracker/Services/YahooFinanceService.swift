import Foundation

struct YahooFinanceService {

    enum Range: String, CaseIterable, Identifiable {
        case oneMonth    = "1mo"
        case threeMonths = "3mo"
        case sixMonths   = "6mo"
        case oneYear     = "1y"
        case twoYears    = "2y"
        case fiveYears   = "5y"
        var id: String { rawValue }
        var label: String {
            switch self {
            case .oneMonth:    return "1M"
            case .threeMonths: return "3M"
            case .sixMonths:   return "6M"
            case .oneYear:     return "1Y"
            case .twoYears:    return "2Y"
            case .fiveYears:   return "5Y"
            }
        }
    }

    enum Interval: String {
        case fiveMinutes   = "5m"
        case thirtyMinutes = "30m"
        case oneDay        = "1d"
        case oneWeek       = "1wk"
    }

    /// Fetch OHLCV bars for a symbol.
    static func fetchBars(
        symbol: String,
        range: Range = .sixMonths,
        interval: Interval = .oneDay
    ) async throws -> [PriceBar] {
        let urlString = "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)"
            + "?range=\(range.rawValue)&interval=\(interval.rawValue)&includePrePost=false"

        guard let url = URL(string: urlString) else { throw ParseError.invalidURL }

        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 15)
        // Yahoo Finance requires a real-looking User-Agent
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ParseError.httpError
        }
        return try parse(data: data)
    }

    // MARK: - JSON parsing

    private static func parse(data: Data) throws -> [PriceBar] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chart = root["chart"] as? [String: Any],
              let results = chart["result"] as? [[String: Any]],
              let first = results.first else {
            throw ParseError.invalidStructure
        }

        guard let timestamps = first["timestamp"] as? [Double],
              let indicators = first["indicators"] as? [String: Any],
              let quoteArr = indicators["quote"] as? [[String: Any]],
              let q = quoteArr.first else {
            throw ParseError.missingData
        }

        // Yahoo returns arrays that may contain NSNull for missing bars
        func doubles(_ key: String) -> [Double?] {
            (q[key] as? [Any] ?? []).map { $0 is NSNull ? nil : ($0 as? Double) }
        }
        func ints(_ key: String) -> [Int?] {
            (q[key] as? [Any] ?? []).map { $0 is NSNull ? nil : ($0 as? Int) }
        }

        let opens   = doubles("open")
        let highs   = doubles("high")
        let lows    = doubles("low")
        let closes  = doubles("close")
        let volumes = ints("volume")

        var bars: [PriceBar] = []
        for i in 0..<timestamps.count {
            guard let o = opens[safe: i] ?? nil,
                  let h = highs[safe: i] ?? nil,
                  let l = lows[safe: i] ?? nil,
                  let c = closes[safe: i] ?? nil else { continue }
            let vol = volumes[safe: i].flatMap { $0 } ?? 0
            bars.append(PriceBar(
                timestamp: Date(timeIntervalSince1970: timestamps[i]),
                open: o, high: h, low: l, close: c, volume: vol
            ))
        }
        return bars.sorted { $0.timestamp < $1.timestamp }
    }

    enum ParseError: LocalizedError {
        case invalidURL
        case httpError
        case invalidStructure
        case missingData
        var errorDescription: String? {
            switch self {
            case .invalidURL:        return "Invalid URL for Yahoo Finance"
            case .httpError:         return "Yahoo Finance returned a non-200 response"
            case .invalidStructure:  return "Unexpected Yahoo Finance response structure"
            case .missingData:       return "No price data in Yahoo Finance response"
            }
        }
    }
}

// MARK: - Safe array subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
