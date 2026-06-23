#!/usr/bin/env swift
// verify_color_width.swift
// Verifies ChartViewModel color / line-width properties and their interaction
// with the MA calculation pipeline.
// Run:  swift verify_color_width.swift

import Foundation
import SwiftUI

// ── Inline stubs matching production types ────────────────────────────────

struct PriceBar {
    let timestamp: Date
    let open, high, low, close: Double
    let volume: Int
}

enum MovingAverageType: String { case sma = "SMA"; case ema = "EMA" }

struct MovingAverageCalculator {
    static func sma(data: [Double], period: Int) -> [Double?] {
        guard period > 0, period <= data.count else { return Array(repeating: nil, count: data.count) }
        var result: [Double?] = Array(repeating: nil, count: data.count)
        for i in (period - 1)..<data.count {
            result[i] = data[(i - period + 1)...i].reduce(0, +) / Double(period)
        }
        return result
    }
    static func ema(data: [Double], period: Int) -> [Double?] {
        guard period > 0, data.count >= period else { return Array(repeating: nil, count: data.count) }
        let k = 2.0 / Double(period + 1)
        var result: [Double?] = Array(repeating: nil, count: data.count)
        result[period - 1] = data[0..<period].reduce(0, +) / Double(period)
        for i in period..<data.count { if let p = result[i-1] { result[i] = data[i] * k + p * (1 - k) } }
        return result
    }
    static func compute(bars: [PriceBar], type: MovingAverageType, period: Int) -> [(date: Date, value: Double)] {
        let closes = bars.map(\.close)
        let vals: [Double?]
        switch type { case .sma: vals = sma(data: closes, period: period); case .ema: vals = ema(data: closes, period: period) }
        return zip(bars, vals).compactMap { bar, v in v.map { (date: bar.timestamp, value: $0) } }
    }
}

// Minimal ChartViewModel equivalent (non-@MainActor for scripting)
class ChartViewModel {
    var bars: [PriceBar] = []
    // MA 1
    var ma1Enabled: Bool = true
    var ma1Type: MovingAverageType = .sma
    var ma1Period: Int = 20
    var ma1Color: Color = .orange
    var ma1LineWidth: Double = 1.5
    // MA 2
    var ma2Enabled: Bool = true
    var ma2Type: MovingAverageType = .ema
    var ma2Period: Int = 50
    var ma2Color: Color = .purple
    var ma2LineWidth: Double = 1.5

    var ma1Series: [(date: Date, value: Double)] {
        ma1Enabled ? MovingAverageCalculator.compute(bars: bars, type: ma1Type, period: ma1Period) : []
    }
    var ma2Series: [(date: Date, value: Double)] {
        ma2Enabled ? MovingAverageCalculator.compute(bars: bars, type: ma2Type, period: ma2Period) : []
    }
}

// ── Test helpers ─────────────────────────────────────────────────────────

var passed = 0; var failed = 0

func check(_ label: String, _ condition: Bool, detail: String = "") {
    if condition {
        print("✅  \(label)")
        passed += 1
    } else {
        print("❌  \(label)\(detail.isEmpty ? "" : " — \(detail)")")
        failed += 1
    }
}

// ── Build sample bars ─────────────────────────────────────────────────────

let base = Date(timeIntervalSince1970: 0)
let sampleBars: [PriceBar] = (0..<60).map { i in
    let v = 100.0 + Double(i) * 0.5   // gentle uptrend
    return PriceBar(timestamp: base.addingTimeInterval(Double(i) * 86400),
                    open: v - 0.2, high: v + 0.5, low: v - 0.5, close: v, volume: 1_000_000)
}

// ── 1. Default values ─────────────────────────────────────────────────────

print("\n── 1. Default property values ───────────────────────────────────────────")

let vm = ChartViewModel()
check("ma1Color default is .orange",   vm.ma1Color == Color.orange)
check("ma2Color default is .purple",   vm.ma2Color == Color.purple)
check("ma1LineWidth default is 1.5",   vm.ma1LineWidth == 1.5)
check("ma2LineWidth default is 1.5",   vm.ma2LineWidth == 1.5)
check("ma1Period default is 20",       vm.ma1Period == 20)
check("ma2Period default is 50",       vm.ma2Period == 50)
check("ma1Type default is SMA",        vm.ma1Type == .sma)
check("ma2Type default is EMA",        vm.ma2Type == .ema)

// ── 2. Color mutation ────────────────────────────────────────────────────

print("\n── 2. Color mutation ────────────────────────────────────────────────────")

vm.ma1Color = .red
check("ma1Color can be set to .red",   vm.ma1Color == Color.red)

vm.ma1Color = Color(red: 0.2, green: 0.6, blue: 1.0)
check("ma1Color can be set to custom RGB", vm.ma1Color == Color(red: 0.2, green: 0.6, blue: 1.0))

vm.ma2Color = .green
check("ma2Color can be set to .green", vm.ma2Color == Color.green)

vm.ma2Color = .yellow
check("ma2Color can be set to .yellow", vm.ma2Color == Color.yellow)

// Reset to defaults for further tests
vm.ma1Color = .orange; vm.ma2Color = .purple

// ── 3. Line width mutation ────────────────────────────────────────────────

print("\n── 3. Line width mutation ───────────────────────────────────────────────")

let widths: [Double] = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0]
for w in widths {
    vm.ma1LineWidth = w
    check("ma1LineWidth = \(w)", vm.ma1LineWidth == w)
}
vm.ma2LineWidth = 3.0
check("ma2LineWidth = 3.0", vm.ma2LineWidth == 3.0)

// Reset
vm.ma1LineWidth = 1.5; vm.ma2LineWidth = 1.5

// ── 4. Color/width independent — no cross-contamination ──────────────────

print("\n── 4. Color and width settings are independent ───────────────────────────")

vm.ma1Color = .red;    vm.ma2Color = .blue
vm.ma1LineWidth = 1.0; vm.ma2LineWidth = 4.0

check("ma1Color .red not affected by ma2Color .blue", vm.ma1Color == Color.red)
check("ma2Color .blue not affected by ma1Color .red", vm.ma2Color == Color.blue)
check("ma1LineWidth 1.0 not affected by ma2LineWidth 4.0", vm.ma1LineWidth == 1.0)
check("ma2LineWidth 4.0 not affected by ma1LineWidth 1.0", vm.ma2LineWidth == 4.0)

// ── 5. Color/width don't affect MA series values ──────────────────────────

print("\n── 5. Color/width changes don't alter MA data series ────────────────────")

vm.bars = sampleBars
vm.ma1Period = 10; vm.ma1Type = .sma; vm.ma1Enabled = true
vm.ma2Period = 20; vm.ma2Type = .ema; vm.ma2Enabled = true

// Capture series with default colors/widths
let series1Before = vm.ma1Series
let series2Before = vm.ma2Series

// Change colors and widths aggressively
vm.ma1Color = .pink;    vm.ma1LineWidth = 5.0
vm.ma2Color = .cyan;    vm.ma2LineWidth = 0.5

let series1After = vm.ma1Series
let series2After = vm.ma2Series

let ma1Unchanged = zip(series1Before, series1After).allSatisfy { $0.value == $1.value }
let ma2Unchanged = zip(series2Before, series2After).allSatisfy { $0.value == $1.value }
check("SMA(10) values unchanged after color/width change", ma1Unchanged)
check("EMA(20) values unchanged after color/width change", ma2Unchanged)
check("MA1 series non-empty (60 bars, period 10)", !series1After.isEmpty)
check("MA2 series non-empty (60 bars, period 20)", !series2After.isEmpty)

// Spot-check a value
let expectedSMA10_at9 = sampleBars[0..<10].map(\.close).reduce(0,+) / 10.0
if let first = series1After.first {
    check("SMA(10) first value \(String(format:"%.2f",first.value)) ≈ \(String(format:"%.2f",expectedSMA10_at9))",
          abs(first.value - expectedSMA10_at9) < 0.001)
}

// ── 6. Toggle enabled/disabled — series empty when disabled ──────────────

print("\n── 6. Toggle enabled respects color/width state ─────────────────────────")

vm.ma1Enabled = false
check("ma1Series empty when disabled",     vm.ma1Series.isEmpty)
check("ma1Color preserved while disabled", vm.ma1Color == Color.pink)
check("ma1LineWidth preserved while disabled", vm.ma1LineWidth == 5.0)

vm.ma1Enabled = true
check("ma1Series non-empty after re-enable", !vm.ma1Series.isEmpty)
check("ma1Color still pink after re-enable", vm.ma1Color == Color.pink)

// ── 7. Boundary widths produce valid StrokeStyle ──────────────────────────

print("\n── 7. StrokeStyle construction with boundary widths ─────────────────────")

for w in [0.5, 5.0] {
    let stroke = StrokeStyle(lineWidth: w, dash: [5, 3])
    check("StrokeStyle(lineWidth: \(w)) lineWidth == \(w)", stroke.lineWidth == w)
    check("StrokeStyle(lineWidth: \(w)) dash preserved",   stroke.dash == [5, 3])
}

// ── Summary ──────────────────────────────────────────────────────────────

print("\n══════════════════════════════════════════════════════════════════════════")
print("Results: \(passed) passed, \(failed) failed")
if failed == 0 {
    print("✅  All color/width verification tests PASSED")
    exit(0)
} else {
    print("❌  \(failed) test(s) FAILED")
    exit(1)
}
