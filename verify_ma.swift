#!/usr/bin/env swift
// verify_ma.swift — quick headless test of MovingAverageCalculator logic
// Run with:  swift verify_ma.swift

import Foundation

// ── Inline copies of the types needed ──────────────────────────────────────

struct PriceBar {
    let timestamp: Date
    let open: Double; let high: Double; let low: Double
    let close: Double; let volume: Int
}

enum MovingAverageType: String {
    case sma = "SMA"; case ema = "EMA"
}

struct MovingAverageCalculator {
    static func sma(data: [Double], period: Int) -> [Double?] {
        guard period > 0, period <= data.count else { return Array(repeating: nil, count: data.count) }
        var result: [Double?] = Array(repeating: nil, count: data.count)
        for i in (period - 1)..<data.count {
            let slice = data[(i - period + 1)...i]
            result[i] = slice.reduce(0, +) / Double(period)
        }
        return result
    }

    static func ema(data: [Double], period: Int) -> [Double?] {
        guard period > 0, data.count >= period else { return Array(repeating: nil, count: data.count) }
        let k = 2.0 / Double(period + 1)
        var result: [Double?] = Array(repeating: nil, count: data.count)
        let seed = data[0..<period].reduce(0, +) / Double(period)
        result[period - 1] = seed
        for i in period..<data.count {
            if let prev = result[i - 1] { result[i] = data[i] * k + prev * (1 - k) }
        }
        return result
    }
}

// ── Test helpers ────────────────────────────────────────────────────────────

var passed = 0
var failed = 0

func expect(_ label: String, _ got: Double?, _ expected: Double, tolerance: Double = 0.0001) {
    guard let got else {
        print("❌  \(label): got nil, expected \(expected)")
        failed += 1; return
    }
    if abs(got - expected) <= tolerance {
        print("✅  \(label): \(String(format: "%.4f", got))")
        passed += 1
    } else {
        print("❌  \(label): got \(String(format: "%.6f", got)), expected \(expected)")
        failed += 1
    }
}

func expectNil(_ label: String, _ got: Double?) {
    if got == nil {
        print("✅  \(label): nil (correct — not enough data)")
        passed += 1
    } else {
        print("❌  \(label): expected nil but got \(got!)")
        failed += 1
    }
}

// ── 1. SMA basic correctness ─────────────────────────────────────────────

print("\n── SMA Tests ────────────────────────────────────────────────────────────")

let prices1 = [10.0, 20.0, 30.0, 40.0, 50.0]
let sma3 = MovingAverageCalculator.sma(data: prices1, period: 3)
// SMA(3) of [10,20,30] = 20.0
expectNil("SMA(3) index 0", sma3[0])
expectNil("SMA(3) index 1", sma3[1])
expect("SMA(3) index 2 == 20.0", sma3[2], 20.0)
expect("SMA(3) index 3 == 30.0", sma3[3], 30.0)
expect("SMA(3) index 4 == 40.0", sma3[4], 40.0)

// Edge: period == data length
let sma5 = MovingAverageCalculator.sma(data: prices1, period: 5)
expectNil("SMA(5) index 3", sma5[3])
expect("SMA(5) index 4 == 30.0", sma5[4], 30.0)

// Edge: period > data length — all nil
let smaLong = MovingAverageCalculator.sma(data: prices1, period: 10)
expectNil("SMA(10) index 4 when only 5 bars", smaLong[4])

// SMA period 1 == identity
let sma1 = MovingAverageCalculator.sma(data: prices1, period: 1)
expect("SMA(1) index 0 == 10.0", sma1[0], 10.0)

// ── 2. EMA basic correctness ─────────────────────────────────────────────

print("\n── EMA Tests ────────────────────────────────────────────────────────────")

let prices2 = [10.0, 20.0, 30.0, 40.0, 50.0]
let ema3 = MovingAverageCalculator.ema(data: prices2, period: 3)
// EMA(3): k = 2/(3+1) = 0.5
// Seed (avg of first 3): (10+20+30)/3 = 20.0
// EMA[3] = 40 * 0.5 + 20 * 0.5 = 30.0
// EMA[4] = 50 * 0.5 + 30 * 0.5 = 40.0
expectNil("EMA(3) index 0", ema3[0])
expectNil("EMA(3) index 1", ema3[1])
expect("EMA(3) index 2 == 20.0 (seed)", ema3[2], 20.0)
expect("EMA(3) index 3 == 30.0", ema3[3], 30.0)
expect("EMA(3) index 4 == 40.0", ema3[4], 40.0)

// EMA should respond faster than SMA to a sudden upward price spike.
// Flat at 10 for 5 bars, then spike to 50 on the last bar.
// SMA(5) = (10+10+10+10+50)/5 = 18.0
// EMA(5): seed=10, k=1/3 → EMA = 50*(1/3) + 10*(2/3) ≈ 23.33
let spikeSeries = [10.0, 10.0, 10.0, 10.0, 10.0, 50.0]
let smaSpike = MovingAverageCalculator.sma(data: spikeSeries, period: 5)
let emaSpike = MovingAverageCalculator.ema(data: spikeSeries, period: 5)
let lastSMAs = smaSpike[5]!
let lastEMAs = emaSpike[5]!
print("  Spike series — SMA final=\(String(format:"%.2f",lastSMAs)), EMA final=\(String(format:"%.2f",lastEMAs))")
expect("SMA(5) after spike = 18.0", lastSMAs, 18.0)
expect("EMA(5) after spike ≈ 23.33", lastEMAs, 23.333, tolerance: 0.01)
if lastEMAs > lastSMAs {
    print("✅  EMA > SMA after price spike (correct — EMA reacts faster)")
    passed += 1
} else {
    print("❌  EMA should be > SMA after price spike")
    failed += 1
}
// Note: for a constant-slope linear series, EMA ≈ SMA (both lag the same average distance).
let rampUp = stride(from: 1.0, through: 20.0, by: 1.0).map { $0 }
let smaR   = MovingAverageCalculator.sma(data: rampUp, period: 5)
let emaR   = MovingAverageCalculator.ema(data: rampUp, period: 5)
let lastSMAr = smaR.last!!
let lastEMAr = emaR.last!!
expect("SMA(5) on linear 1..20 = 18.0", lastSMAr, 18.0)
expect("EMA(5) on linear 1..20 ≈ 18.0 (steady-state lag equals SMA lag)", lastEMAr, 18.0, tolerance: 0.01)

// ── 3. SMA sliding window property ──────────────────────────────────────

print("\n── SMA sliding window property ──────────────────────────────────────────")

let prices3 = [5.0, 10.0, 15.0, 20.0, 25.0, 30.0]
let sma2 = MovingAverageCalculator.sma(data: prices3, period: 2)
// Sliding average of consecutive pairs
expect("SMA(2)[1] = (5+10)/2 = 7.5",  sma2[1], 7.5)
expect("SMA(2)[2] = (10+15)/2 = 12.5", sma2[2], 12.5)
expect("SMA(2)[3] = (15+20)/2 = 17.5", sma2[3], 17.5)
expect("SMA(2)[4] = (20+25)/2 = 22.5", sma2[4], 22.5)
expect("SMA(2)[5] = (25+30)/2 = 27.5", sma2[5], 27.5)

// ── 4. Real-world sample: SMA-20 of first 20 bars all equal 100 ──────────

print("\n── SMA-20 on flat price series ───────────────────────────────────────────")

let flat = Array(repeating: 100.0, count: 25)
let sma20flat = MovingAverageCalculator.sma(data: flat, period: 20)
expect("SMA(20) on flat 100.0 series at index 19", sma20flat[19], 100.0)
expect("SMA(20) on flat 100.0 series at index 24", sma20flat[24], 100.0)

// EMA on flat series should also converge to 100
let ema20flat = MovingAverageCalculator.ema(data: flat, period: 20)
expect("EMA(20) on flat 100.0 series at index 19", ema20flat[19], 100.0)
expect("EMA(20) on flat 100.0 series at index 24", ema20flat[24], 100.0)

// ── 5. Period-1 edge cases ───────────────────────────────────────────────

print("\n── Period edge cases ─────────────────────────────────────────────────────")

let prices5 = [3.0, 7.0, 2.0]
expect("SMA(1) == identity at index 1", MovingAverageCalculator.sma(data: prices5, period: 1)[1], 7.0)
expect("EMA(1) == identity at index 1", MovingAverageCalculator.ema(data: prices5, period: 1)[1], 7.0)

// Period = data.count for EMA
let ema3seed = MovingAverageCalculator.ema(data: prices5, period: 3)
expect("EMA(3) seed = (3+7+2)/3 = 4.0", ema3seed[2], 4.0)

// ── Summary ─────────────────────────────────────────────────────────────

print("\n══════════════════════════════════════════════════════════════════════════")
print("Results: \(passed) passed, \(failed) failed")
if failed == 0 {
    print("✅  All moving average tests PASSED — logic is correct")
    exit(0)
} else {
    print("❌  Some tests FAILED")
    exit(1)
}
