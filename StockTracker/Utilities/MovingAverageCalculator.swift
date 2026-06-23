import Foundation

enum MovingAverageType: String, CaseIterable, Identifiable {
    case sma = "SMA"
    case ema = "EMA"
    var id: String { rawValue }
}

struct MovingAverageCalculator {

    // MARK: - Simple Moving Average

    static func sma(data: [Double], period: Int) -> [Double?] {
        guard period > 0, period <= data.count else {
            return Array(repeating: nil, count: data.count)
        }
        var result: [Double?] = Array(repeating: nil, count: data.count)
        for i in (period - 1)..<data.count {
            let slice = data[(i - period + 1)...i]
            result[i] = slice.reduce(0, +) / Double(period)
        }
        return result
    }

    // MARK: - Exponential Moving Average

    static func ema(data: [Double], period: Int) -> [Double?] {
        guard period > 0, data.count >= period else {
            return Array(repeating: nil, count: data.count)
        }
        let k = 2.0 / Double(period + 1)
        var result: [Double?] = Array(repeating: nil, count: data.count)
        // Seed with SMA of first `period` values
        let seed = data[0..<period].reduce(0, +) / Double(period)
        result[period - 1] = seed
        for i in period..<data.count {
            if let prev = result[i - 1] {
                result[i] = data[i] * k + prev * (1 - k)
            }
        }
        return result
    }

    // MARK: - Chart-ready output

    /// Returns (date, value) pairs — only entries where the MA is defined.
    static func compute(
        bars: [PriceBar],
        type: MovingAverageType,
        period: Int
    ) -> [(date: Date, value: Double)] {
        let closes = bars.map(\.close)
        let values: [Double?]
        switch type {
        case .sma: values = sma(data: closes, period: period)
        case .ema: values = ema(data: closes, period: period)
        }
        return zip(bars, values).compactMap { bar, val in
            val.map { (date: bar.timestamp, value: $0) }
        }
    }
}
