import SwiftUI

struct PortfolioView: View {
    @EnvironmentObject var vm: PortfolioViewModel

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

    // MARK: - Holdings table

    @ViewBuilder
    private var holdingsView: some View {
        VStack(spacing: 0) {
            summaryBar
            Divider()
            if vm.isLoading {
                ProgressView("Refreshing portfolio…")
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

    private var summaryBar: some View {
        HStack(spacing: 28) {
            StatLabel(title: "Total Value",
                      value: vm.totalValue.formatted(.currency(code: "USD")))
            if let gl = vm.totalGainLoss, let glp = vm.totalGainLossPercent {
                StatLabel(
                    title: "Total Gain/Loss",
                    value: "\(gl >= 0 ? "+" : "")\(gl.formatted(.currency(code: "USD"))) (\(String(format: "%.2f", glp))%)",
                    color: gl >= 0 ? .green : .red
                )
            }
            Spacer()
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

    private var holdingsTable: some View {
        Table(vm.holdings) {
            TableColumn("Symbol") { h in
                Text(h.symbol).font(.headline)
            }
            .width(min: 60, ideal: 80)

            TableColumn("Name") { h in
                Text(h.name).foregroundStyle(.secondary)
            }

            TableColumn("Shares") { h in
                Text(h.quantity, format: .number.precision(.fractionLength(4)))
                    .monospacedDigit()
            }
            .width(min: 60, ideal: 90)

            TableColumn("Price") { h in
                Text(h.institutionPrice, format: .currency(code: "USD"))
                    .monospacedDigit()
            }
            .width(min: 70, ideal: 90)

            TableColumn("Market Value") { h in
                Text(h.institutionValue, format: .currency(code: "USD"))
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

            TableColumn("Gain / Loss") { h in
                if let gl = h.gainLoss, let glp = h.gainLossPercent {
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
    }

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
            Text("Try refreshing — it may take a moment for Plaid to load your data.")
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
