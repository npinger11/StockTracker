import SwiftUI

struct PortfolioView: View {
    @EnvironmentObject var vm: PortfolioViewModel
    @EnvironmentObject var watchlistVM: WatchlistViewModel

    var body: some View {
        Group {
            if !vm.plaid.hasCredentials {
                PlaidSetupView()
                    .environmentObject(vm)
            } else if !vm.plaid.hasAccessToken {
                ConnectAccountView()
                    .environmentObject(vm)
            } else {
                holdingsView
            }
        }
        .navigationTitle("SoFi Portfolio")
    }

    // MARK: - Holdings view

    @ViewBuilder
    private var holdingsView: some View {
        VStack(spacing: 0) {
            summaryBar
            Divider()
            if vm.isLoading {
                ProgressView("Loading portfolio from Plaid…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = vm.error {
                errorState(error)
            } else if vm.holdings.isEmpty {
                emptyHoldings
            } else {
                holdingsTable
            }
        }
    }

    // MARK: - Summary bar

    private var summaryBar: some View {
        HStack(spacing: 24) {
            // Total value (live-adjusted when Finnhub prices are available)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("Total Value")
                        .font(.caption).foregroundStyle(.secondary)
                    if vm.hasLivePrices {
                        liveBadge
                    } else if vm.isFetchingLivePrices {
                        ProgressView().scaleEffect(0.5).frame(width: 14, height: 14)
                    }
                }
                Text(vm.totalValue, format: .currency(code: "USD"))
                    .font(.headline.monospacedDigit())
            }

            if let gl = vm.totalGainLoss, let glp = vm.totalGainLossPercent {
                StatLabel(
                    title: "Total Gain/Loss",
                    value: "\(gl >= 0 ? "+" : "")\(gl.formatted(.currency(code: "USD"))) (\(String(format: "%.2f", glp))%)",
                    color: gl >= 0 ? .green : .red
                )
            }

            Spacer()

            // Refresh prices only (quick)
            if vm.hasLivePrices {
                Button {
                    vm.fetchLivePrices()
                } label: {
                    Label("Refresh Prices", systemImage: "chart.line.uptrend.xyaxis")
                }
                .disabled(vm.isFetchingLivePrices)
                .help("Re-fetch live prices from Finnhub")
            }

            // Full refresh (Plaid + prices)
            Button {
                vm.fetchHoldings()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(vm.isLoading)

            Button(role: .destructive) {
                vm.disconnect()
            } label: {
                Label("Disconnect", systemImage: "link.badge.minus")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private var liveBadge: some View {
        Text("LIVE")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Color.green, in: Capsule())
    }

    // MARK: - Holdings table

    private var holdingsTable: some View {
        Table(vm.holdings) {
            // Symbol — shows watchlist indicator
            TableColumn("Symbol") { h in
                HStack(spacing: 4) {
                    Text(h.symbol).font(.headline)
                    if watchlistVM.tickers.contains(where: { $0.symbol == h.symbol }) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.blue)
                    }
                }
            }
            .width(min: 70, ideal: 90)

            TableColumn("Name") { h in
                Text(h.name).foregroundStyle(.secondary)
            }

            TableColumn("Shares") { h in
                Text(h.quantity, format: .number.precision(.fractionLength(4)))
                    .monospacedDigit()
            }
            .width(min: 60, ideal: 90)

            // Price: live (Finnhub) when available, otherwise Plaid institutional
            TableColumn("Price") { h in
                let isLive = vm.livePrices[h.symbol] != nil
                HStack(spacing: 3) {
                    Text(vm.effectivePrice(for: h), format: .currency(code: "USD"))
                        .monospacedDigit()
                    if isLive {
                        Circle().fill(Color.green).frame(width: 5, height: 5)
                    }
                }
            }
            .width(min: 80, ideal: 100)

            // Market value: live price × shares
            TableColumn("Mkt Value") { h in
                Text(vm.effectiveValue(for: h), format: .currency(code: "USD"))
                    .monospacedDigit()
            }
            .width(min: 90, ideal: 105)

            TableColumn("Cost Basis") { h in
                if let cb = h.costBasis {
                    Text(cb, format: .currency(code: "USD")).monospacedDigit()
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
            }
            .width(min: 90, ideal: 105)

            // Gain/Loss: computed from live price when available
            TableColumn("Gain / Loss") { h in
                if let gl = vm.effectiveGainLoss(for: h),
                   let glp = vm.effectiveGainLossPercent(for: h) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(gl, format: .currency(code: "USD"))
                            .monospacedDigit()
                            .foregroundStyle(gl >= 0 ? .green : .red)
                        Text(String(format: "%+.2f%%", glp))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(gl >= 0 ? .green : .red)
                    }
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
            }
            .width(min: 90, ideal: 110)
        }
        // Right-click context menu: add/remove from watchlist, view chart
        .contextMenu(forSelectionType: PortfolioHolding.ID.self) { ids in
            if let h = vm.holdings.first(where: { ids.contains($0.id) }),
               h.symbol != "N/A" {
                let onWatchlist = watchlistVM.tickers.contains { $0.symbol == h.symbol }
                if onWatchlist {
                    Button {
                        watchlistVM.removeTicker(symbol: h.symbol)
                    } label: {
                        Label("Remove \(h.symbol) from Watchlist", systemImage: "eye.slash")
                    }
                } else {
                    Button {
                        watchlistVM.addTicker(symbol: h.symbol, name: h.name)
                    } label: {
                        Label("Add \(h.symbol) to Watchlist", systemImage: "eye")
                    }
                }

                Divider()

                Button {
                    // Ensure it's on the watchlist so the chart is accessible
                    if !onWatchlist {
                        watchlistVM.addTicker(symbol: h.symbol, name: h.name)
                    }
                } label: {
                    Label("View Chart for \(h.symbol)", systemImage: "chart.xyaxis.line")
                }
            }
        } primaryAction: { ids in
            // Double-click: add to watchlist if not already there
            if let h = vm.holdings.first(where: { ids.contains($0.id) }),
               h.symbol != "N/A",
               !watchlistVM.tickers.contains(where: { $0.symbol == h.symbol }) {
                watchlistVM.addTicker(symbol: h.symbol, name: h.name)
            }
        }
    }

    // MARK: - States

    private func errorState(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle).foregroundStyle(.orange)
            Text(msg).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Retry") { vm.fetchHoldings() }.buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyHoldings: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray").font(.largeTitle).foregroundStyle(.secondary)
            Text("No holdings found").foregroundStyle(.secondary)
            Text("Try refreshing — Plaid may take a moment to sync your SoFi data.")
                .font(.caption).foregroundStyle(.tertiary).multilineTextAlignment(.center)
            Button("Refresh") { vm.fetchHoldings() }.buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Stat label

struct StatLabel: View {
    let title: String
    let value: String
    var color: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(color)
        }
    }
}

// MARK: - Plaid Setup (enter credentials)

struct PlaidSetupView: View {
    @EnvironmentObject var vm: PortfolioViewModel
    @State private var clientID = ""
    @State private var secret = ""
    @State private var environment: PlaidEnvironment = .sandbox

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Connect your SoFi brokerage account via Plaid's free Investments API.")
                    Link("Create a free Plaid developer account →",
                         destination: URL(string: "https://dashboard.plaid.com/signup")!)
                        .font(.subheadline)
                }
            }

            Section("Plaid API Credentials") {
                TextField("Client ID", text: $clientID)
                SecureField("Secret", text: $secret)
                Picker("Environment", selection: $environment) {
                    ForEach(PlaidEnvironment.allCases) { env in
                        Text(env.displayName).tag(env)
                    }
                }
                Text("Use **Sandbox** for demo data (instant). Use **Development** for your real SoFi account (requires Plaid approval, 1-3 business days).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Save & Continue") {
                    vm.plaid.saveCredentials(clientID: clientID, secret: secret, environment: environment)
                }
                .buttonStyle(.borderedProminent)
                .disabled(clientID.isEmpty || secret.isEmpty)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 520)
        .navigationTitle("Set Up Plaid")
    }
}

// MARK: - Connect Account (trigger Plaid Link)

struct ConnectAccountView: View {
    @EnvironmentObject var vm: PortfolioViewModel
    @State private var isLoadingToken = false
    @State private var linkToken: String?
    @State private var tokenError: String?
    @State private var showLinkSheet = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 72))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.blue)

            Text("Connect SoFi Account")
                .font(.title.bold())

            Text("Tap below to open Plaid Link and securely sign into your SoFi brokerage account.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            if let err = tokenError {
                Text(err).font(.caption).foregroundStyle(.red)
                    .multilineTextAlignment(.center).frame(maxWidth: 380)
            }

            Button {
                startLinkFlow()
            } label: {
                if isLoadingToken {
                    ProgressView().scaleEffect(0.85)
                } else {
                    Label("Connect via Plaid", systemImage: "link")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isLoadingToken)

            Button("Reset Credentials") {
                KeychainHelper.delete(for: .plaidClientID)
                KeychainHelper.delete(for: .plaidSecret)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showLinkSheet) {
            if let token = linkToken {
                PlaidLinkSheet(linkToken: token) { publicToken in
                    Task {
                        try? await vm.plaid.exchangePublicToken(publicToken)
                        vm.fetchHoldings()
                    }
                }
            }
        }
    }

    private func startLinkFlow() {
        isLoadingToken = true
        tokenError = nil
        Task {
            do {
                linkToken = try await vm.plaid.createLinkToken()
                showLinkSheet = true
            } catch {
                tokenError = error.localizedDescription
            }
            isLoadingToken = false
        }
    }
}
