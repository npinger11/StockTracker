import Foundation

struct PriceBar: Identifiable {
    let id: UUID = UUID()
    let timestamp: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Int
}
