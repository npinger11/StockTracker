import SwiftUI
import Charts

struct StockDetailView: View {
    let symbol: String
    @StateObject private var vm = ChartViewModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .onAppear { vm.load(symbol: symbol) }
        .onChange(of: symbol) { newSymbol in vm.load(symbol: newSymbol) }
        .onChange(of: vm.selectedRange) { _ in vm.load(symbol: symbol) }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Text(symbol)
                .font(.largeTitle.bold())
            Spacer()
            Picker("Range", selection: $vm.selectedRange) {
                ForEach(YahooFinanceService.Range.allCases) { range in
                    Text(range.label).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 280)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if vm.isLoading {
            ProgressView("Loading chart data…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = vm.error {
            errorView(error)
        } else if vm.bars.isEmpty {
            Text("No data available for \(symbol)")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                priceChart
                    .padding([.horizontal, .top])
                    .frame(maxHeight: .infinity)

                Divider()
                maControls
                    .padding()
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") { vm.load(symbol: symbol) }
                .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Chart

    private var priceChart: some View {
        Chart {
            // Price line only — single series so .foregroundStyle works correctly.
            // MA lines are drawn via chartOverlay+Canvas below, completely bypassing
            // Swift Charts' internal series→color cache which prevented color updates.
            ForEach(vm.bars) { bar in
                LineMark(
                    x: .value("Date", bar.timestamp),
                    y: .value("Close", bar.close)
                )
                .foregroundStyle(Color.blue)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .interpolationMethod(.linear)
            }
        }
        .chartYScale(domain: vm.priceRange)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.quaternary)
                if vm.selectedRange.isIntraday {
                    AxisValueLabel(format: .dateTime.hour().minute())
                        .font(.caption)
                } else {
                    AxisValueLabel(format: .dateTime.month(.abbreviated).year(.twoDigits))
                        .font(.caption)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 6)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.quaternary)
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(v, format: .currency(code: "USD").precision(.fractionLength(2)))
                            .font(.caption)
                    }
                }
            }
        }
        // Canvas overlay draws MA lines outside Swift Charts' rendering pipeline.
        // The draw closure captures vm.ma1Color / vm.ma2Color from the outer scope
        // and runs fresh on every SwiftUI render — no caching, instant color updates.
        .chartOverlay { proxy in
            GeometryReader { geo in
                let origin = geo[proxy.plotAreaFrame].origin
                Canvas { ctx, _ in
                    if vm.ma1Enabled {
                        ctx.stroke(
                            buildMAPath(series: vm.ma1Series, proxy: proxy, origin: origin),
                            with: .color(vm.ma1Color),
                            style: StrokeStyle(lineWidth: vm.ma1LineWidth, dash: [5, 3])
                        )
                    }
                    if vm.ma2Enabled {
                        ctx.stroke(
                            buildMAPath(series: vm.ma2Series, proxy: proxy, origin: origin),
                            with: .color(vm.ma2Color),
                            style: StrokeStyle(lineWidth: vm.ma2LineWidth, dash: [5, 3])
                        )
                    }
                }
            }
        }
    }

    /// Converts MA (date, value) pairs to a Path in the chart's screen coordinate space.
    /// `origin` is the plot area's top-left corner within the chartOverlay's coordinate system.
    private func buildMAPath(
        series: [(date: Date, value: Double)],
        proxy: ChartProxy,
        origin: CGPoint
    ) -> Path {
        var path = Path()
        for (i, pt) in series.enumerated() {
            guard
                let x = proxy.position(forX: pt.date),
                let y = proxy.position(forY: pt.value)
            else { continue }
            let point = CGPoint(x: origin.x + x, y: origin.y + y)
            i == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        return path
    }

    // MARK: - MA Controls

    private var maControls: some View {
        HStack(spacing: 20) {
            MAControlPanel(
                label: "MA 1",
                enabled: $vm.ma1Enabled,
                type: $vm.ma1Type,
                period: $vm.ma1Period,
                color: $vm.ma1Color,
                lineWidth: $vm.ma1LineWidth
            )
            Divider().frame(height: 64)
            MAControlPanel(
                label: "MA 2",
                enabled: $vm.ma2Enabled,
                type: $vm.ma2Type,
                period: $vm.ma2Period,
                color: $vm.ma2Color,
                lineWidth: $vm.ma2LineWidth
            )
            Spacer()
        }
    }
}

// MARK: - MA Control Panel

struct MAControlPanel: View {
    let label: String
    @Binding var enabled: Bool
    @Binding var type: MovingAverageType
    @Binding var period: Int
    @Binding var color: Color
    @Binding var lineWidth: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                // Toggle + colored label
                Toggle(isOn: $enabled) {
                    HStack(spacing: 5) {
                        // Live swatch showing current color
                        RoundedRectangle(cornerRadius: 2)
                            .fill(enabled ? color : Color.secondary.opacity(0.3))
                            .frame(width: 18, height: 3)
                        Text(label)
                            .font(.subheadline.bold())
                    }
                }
                .toggleStyle(.checkbox)

                if enabled {
                    // SMA / EMA picker
                    Picker("", selection: $type) {
                        ForEach(MovingAverageType.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 100)

                    // Period
                    HStack(spacing: 5) {
                        Text("Period:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(
                            value: Binding(
                                get: { Double(period) },
                                set: { period = Int($0.rounded()) }
                            ),
                            in: 5...200,
                            step: 1
                        )
                        .frame(width: 110)
                        Text("\(period)")
                            .font(.caption.monospacedDigit())
                            .frame(width: 28, alignment: .leading)
                    }

                    // Color picker
                    HStack(spacing: 5) {
                        Text("Color:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ColorPicker("", selection: $color, supportsOpacity: false)
                            .labelsHidden()
                            .frame(width: 28, height: 28)
                    }

                    // Line width
                    HStack(spacing: 5) {
                        Text("Width:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $lineWidth, in: 0.5...5.0, step: 0.5)
                            .frame(width: 80)
                        Text(String(format: "%.1f", lineWidth))
                            .font(.caption.monospacedDigit())
                            .frame(width: 24, alignment: .leading)
                    }
                }
            }
        }
    }
}
