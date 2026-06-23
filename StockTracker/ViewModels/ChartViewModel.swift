import Foundation
import Combine
import SwiftUI

@MainActor
final class ChartViewModel: ObservableObject {

    @Published var bars: [PriceBar] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    // MA 1
    @Published var ma1Enabled: Bool = true
    @Published var ma1Type: MovingAverageType = .sma
    @Published var ma1Period: Int = 20
    @Published var ma1Color: Color = .orange
    @Published var ma1LineWidth: Double = 1.5

    // MA 2
    @Published var ma2Enabled: Bool = true
    @Published var ma2Type: MovingAverageType = .ema
    @Published var ma2Period: Int = 50
    @Published var ma2Color: Color = .purple
    @Published var ma2LineWidth: Double = 1.5

    @Published var selectedRange: YahooFinanceService.Range = .sixMonths

    // MARK: - Computed chart data

    var ma1Series: [(date: Date, value: Double)] {
        ma1Enabled ? MovingAverageCalculator.compute(bars: bars, type: ma1Type, period: ma1Period) : []
    }

    var ma2Series: [(date: Date, value: Double)] {
        ma2Enabled ? MovingAverageCalculator.compute(bars: bars, type: ma2Type, period: ma2Period) : []
    }

    /// Unified Y-axis range covering price + both MA lines, with 5 % padding.
    var priceRange: ClosedRange<Double> {
        guard !bars.isEmpty else { return 0...1 }
        var all: [Double] = bars.flatMap { [$0.low, $0.high] }
        all += ma1Series.map(\.value)
        all += ma2Series.map(\.value)
        let mn = all.min() ?? 0
        let mx = all.max() ?? 1
        let pad = (mx - mn) * 0.05
        return (mn - pad)...(mx + pad)
    }

    // MARK: - Data loading

    func load(symbol: String) {
        isLoading = true
        error = nil
        Task {
            do {
                bars = try await YahooFinanceService.fetchBars(
                    symbol: symbol,
                    range: selectedRange,
                    interval: .oneDay
                )
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}
