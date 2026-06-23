#!/usr/bin/env swift
// verify_intervals.swift
// Unit tests for the new 1H / 1D interval logic in YahooFinanceService.
// Run:  swift verify_intervals.swift

import Foundation

// ── Inline stubs matching production types ────────────────────────────────

struct PriceBar {
    let timestamp: Date
    let open, high, low, close: Double
    let volume: Int
}

enum Interval: String {
    case oneMinute     = "1m"
    case fiveMinutes   = "5m"
    case thirtyMinutes = "30m"
    case oneDay        = "1d"
    case oneWeek       = "1wk"
}

enum Range: String, CaseIterable {
    case oneHour     = "1h"
    case oneDay      = "1d"
    case oneMonth    = "1mo"
    case threeMonths = "3mo"
    case sixMonths   = "6mo"
    case oneYear     = "1y"
    case twoYears    = "2y"
    case fiveYears   = "5y"

    var label: String {
        switch self {
        case .oneHour:     return "1H"
        case .oneDay:      return "1D"
        case .oneMonth:    return "1M"
        case .threeMonths: return "3M"
        case .sixMonths:   return "6M"
        case .oneYear:     return "1Y"
        case .twoYears:    return "2Y"
        case .fiveYears:   return "5Y"
        }
    }

    var yahooRangeParam: String {
        self == .oneHour ? "1d" : rawValue
    }

    var defaultInterval: Interval {
        switch self {
        case .oneHour: return .oneMinute
        case .oneDay:  return .fiveMinutes
        default:       return .oneDay
        }
    }

    var isIntraday: Bool { self == .oneHour || self == .oneDay }
}

// Simulate the trimming logic from fetchBars
func applyTrimming(bars: [PriceBar], range: Range) -> [PriceBar] {
    range == .oneHour ? Array(bars.suffix(60)) : bars
}

// ── Helpers ───────────────────────────────────────────────────────────────

var passed = 0; var failed = 0

func check(_ label: String, _ condition: Bool) {
    if condition {
        print("✅  \(label)")
        passed += 1
    } else {
        print("❌  \(label)")
        failed += 1
    }
}

func makeBars(_ count: Int) -> [PriceBar] {
    let base = Date(timeIntervalSince1970: 1_700_000_000)
    return (0..<count).map { i in
        PriceBar(
            timestamp: base.addingTimeInterval(Double(i) * 60),
            open: 100, high: 101, low: 99, close: 100, volume: 1000
        )
    }
}

// ── 1. Range labels ───────────────────────────────────────────────────────

print("\n── 1. Range labels ──────────────────────────────────────────────────────")

let expectedLabels: [(Range, String)] = [
    (.oneHour,     "1H"), (.oneDay,      "1D"),
    (.oneMonth,    "1M"), (.threeMonths, "3M"),
    (.sixMonths,   "6M"), (.oneYear,     "1Y"),
    (.twoYears,    "2Y"), (.fiveYears,   "5Y")
]
for (range, label) in expectedLabels {
    check("Range.\(range) label == \"\(label)\"", range.label == label)
}

// ── 2. CaseIterable order — 1H and 1D are first ───────────────────────────

print("\n── 2. CaseIterable order ────────────────────────────────────────────────")

let allCases = Range.allCases
check("Total case count is 8",             allCases.count == 8)
check("First case is .oneHour",            allCases[0] == .oneHour)
check("Second case is .oneDay",            allCases[1] == .oneDay)
check("Last case is .fiveYears",           allCases.last == .fiveYears)

// ── 3. yahooRangeParam ────────────────────────────────────────────────────

print("\n── 3. Yahoo range parameter mapping ─────────────────────────────────────")

// 1H is special: no native Yahoo "1h" range — must use "1d" and trim
check("1H yahooRangeParam == \"1d\" (not \"1h\")", Range.oneHour.yahooRangeParam == "1d")
check("1D yahooRangeParam == \"1d\"",              Range.oneDay.yahooRangeParam  == "1d")
check("1M yahooRangeParam == \"1mo\"",             Range.oneMonth.yahooRangeParam == "1mo")
check("3M yahooRangeParam == \"3mo\"",             Range.threeMonths.yahooRangeParam == "3mo")
check("6M yahooRangeParam == \"6mo\"",             Range.sixMonths.yahooRangeParam == "6mo")
check("1Y yahooRangeParam == \"1y\"",              Range.oneYear.yahooRangeParam  == "1y")
check("2Y yahooRangeParam == \"2y\"",              Range.twoYears.yahooRangeParam == "2y")
check("5Y yahooRangeParam == \"5y\"",              Range.fiveYears.yahooRangeParam == "5y")

// ── 4. defaultInterval ────────────────────────────────────────────────────

print("\n── 4. Default interval per range ────────────────────────────────────────")

check("1H uses 1-minute bars",  Range.oneHour.defaultInterval == .oneMinute)
check("1D uses 5-minute bars",  Range.oneDay.defaultInterval  == .fiveMinutes)
check("1M uses daily bars",     Range.oneMonth.defaultInterval == .oneDay)
check("3M uses daily bars",     Range.threeMonths.defaultInterval == .oneDay)
check("6M uses daily bars",     Range.sixMonths.defaultInterval == .oneDay)
check("1Y uses daily bars",     Range.oneYear.defaultInterval  == .oneDay)
check("2Y uses daily bars",     Range.twoYears.defaultInterval == .oneDay)
check("5Y uses daily bars",     Range.fiveYears.defaultInterval == .oneDay)

// Verify raw interval strings match Yahoo Finance API values
check("1-minute interval rawValue == \"1m\"", Interval.oneMinute.rawValue   == "1m")
check("5-minute interval rawValue == \"5m\"", Interval.fiveMinutes.rawValue == "5m")
check("1-day interval rawValue == \"1d\"",    Interval.oneDay.rawValue      == "1d")

// ── 5. isIntraday flag ────────────────────────────────────────────────────

print("\n── 5. isIntraday flag ───────────────────────────────────────────────────")

check("1H isIntraday == true",  Range.oneHour.isIntraday     == true)
check("1D isIntraday == true",  Range.oneDay.isIntraday      == true)
check("1M isIntraday == false", Range.oneMonth.isIntraday    == false)
check("3M isIntraday == false", Range.threeMonths.isIntraday == false)
check("6M isIntraday == false", Range.sixMonths.isIntraday   == false)
check("1Y isIntraday == false", Range.oneYear.isIntraday     == false)
check("2Y isIntraday == false", Range.twoYears.isIntraday    == false)
check("5Y isIntraday == false", Range.fiveYears.isIntraday   == false)

// ── 6. Intraday trimming — 1H ─────────────────────────────────────────────

print("\n── 6. Intraday trimming for 1H range ────────────────────────────────────")

// Exact 60 bars → all returned
let exact60 = makeBars(60)
let trimmed60 = applyTrimming(bars: exact60, range: .oneHour)
check("1H with exactly 60 bars → 60 returned",     trimmed60.count == 60)
check("1H exact 60: first bar is bars[0]",         trimmed60.first?.timestamp == exact60.first?.timestamp)
check("1H exact 60: last bar is bars[59]",         trimmed60.last?.timestamp  == exact60.last?.timestamp)

// More than 60 bars (typical: full day = ~390 1-min bars) → last 60 only
let full390 = makeBars(390)
let trimmed390 = applyTrimming(bars: full390, range: .oneHour)
check("1H with 390 bars → exactly 60 returned",    trimmed390.count == 60)
check("1H 390→60: first returned bar is bar[330]", trimmed390.first?.timestamp == full390[330].timestamp)
check("1H 390→60: last returned bar is bar[389]",  trimmed390.last?.timestamp  == full390[389].timestamp)

// Edge: exactly 61 bars → last 60
let bars61 = makeBars(61)
let trimmed61 = applyTrimming(bars: bars61, range: .oneHour)
check("1H with 61 bars → 60 returned",             trimmed61.count == 60)
check("1H 61→60: first bar is bar[1] (bar[0] dropped)", trimmed61.first?.timestamp == bars61[1].timestamp)

// Edge: fewer than 60 bars (e.g. market just opened) → all returned
let bars30 = makeBars(30)
let trimmed30 = applyTrimming(bars: bars30, range: .oneHour)
check("1H with only 30 bars → all 30 returned (no crash)", trimmed30.count == 30)

// Edge: empty bars array → empty result (no crash)
let empty: [PriceBar] = []
let trimmedEmpty = applyTrimming(bars: empty, range: .oneHour)
check("1H with 0 bars → 0 returned (no crash)", trimmedEmpty.isEmpty)

// ── 7. No trimming for non-1H ranges ──────────────────────────────────────

print("\n── 7. No trimming applied to non-1H ranges ──────────────────────────────")

let bars200 = makeBars(200)
for range in [Range.oneDay, .oneMonth, .threeMonths, .sixMonths, .oneYear, .twoYears, .fiveYears] {
    let result = applyTrimming(bars: bars200, range: range)
    check("Range.\(range) (\(range.label)): 200 bars → 200 returned (no trim)", result.count == 200)
}

// ── 8. URL construction correctness ───────────────────────────────────────

print("\n── 8. URL construction for each range ───────────────────────────────────")

func buildURL(symbol: String, range: Range) -> String {
    let interval = range.defaultInterval
    return "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)"
        + "?range=\(range.yahooRangeParam)&interval=\(interval.rawValue)&includePrePost=false"
}

// 1H: must use range=1d&interval=1m (not range=1h)
let url1H = buildURL(symbol: "AAPL", range: .oneHour)
check("1H URL contains range=1d (not 1h)",      url1H.contains("range=1d"))
check("1H URL contains interval=1m",             url1H.contains("interval=1m"))
check("1H URL does NOT contain range=1h",        !url1H.contains("range=1h"))

// 1D: must use range=1d&interval=5m
let url1D = buildURL(symbol: "AAPL", range: .oneDay)
check("1D URL contains range=1d",                url1D.contains("range=1d"))
check("1D URL contains interval=5m",             url1D.contains("interval=5m"))
check("1D URL does NOT contain interval=1m",     !url1D.contains("interval=1m"))

// 6M: must use range=6mo&interval=1d
let url6M = buildURL(symbol: "AAPL", range: .sixMonths)
check("6M URL contains range=6mo",               url6M.contains("range=6mo"))
check("6M URL contains interval=1d",             url6M.contains("interval=1d"))

// 1Y: must use range=1y&interval=1d
let url1Y = buildURL(symbol: "AAPL", range: .oneYear)
check("1Y URL contains range=1y",                url1Y.contains("range=1y"))
check("1Y URL contains interval=1d",             url1Y.contains("interval=1d"))

// All URLs include includePrePost=false (no pre/after-market bars)
for range in Range.allCases {
    let url = buildURL(symbol: "TSLA", range: range)
    check("Range.\(range.label) URL includes includePrePost=false", url.contains("includePrePost=false"))
}

// ── 9. Trimming preserves chronological order ─────────────────────────────

print("\n── 9. Trimming preserves chronological order ─────────────────────────────")

// Create out-of-order bars to simulate sorted input (they'll already be sorted, this checks we don't re-sort)
let orderedBars = makeBars(120)  // 120 consecutive 1-min bars
let trimmedOrdered = applyTrimming(bars: orderedBars, range: .oneHour)
check("Trimmed 1H bars are in ascending timestamp order",
    zip(trimmedOrdered, trimmedOrdered.dropFirst()).allSatisfy { $0.timestamp < $1.timestamp })
check("Last trimmed bar has the most recent timestamp",
    trimmedOrdered.last?.timestamp == orderedBars.last?.timestamp)
check("First trimmed bar is exactly 59 bars before the last",
    trimmedOrdered.first?.timestamp == orderedBars[60].timestamp)

// ── 10. Picker label sequence ─────────────────────────────────────────────

print("\n── 10. Picker label sequence (as shown in UI) ───────────────────────────")

let labels = Range.allCases.map(\.label)
check("Picker labels: [\"1H\", \"1D\", \"1M\", \"3M\", \"6M\", \"1Y\", \"2Y\", \"5Y\"]",
    labels == ["1H", "1D", "1M", "3M", "6M", "1Y", "2Y", "5Y"])
check("1H is the first picker option",  labels.first == "1H")
check("5Y is the last picker option",   labels.last  == "5Y")
check("1D immediately follows 1H",      labels[1]    == "1D")

// ── Summary ───────────────────────────────────────────────────────────────

print("\n══════════════════════════════════════════════════════════════════════════")
print("Results: \(passed) passed, \(failed) failed")
if failed == 0 {
    print("✅  All interval logic tests PASSED")
    exit(0)
} else {
    print("❌  \(failed) test(s) FAILED")
    exit(1)
}
