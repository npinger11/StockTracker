import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var watchlistVM: WatchlistViewModel

    @State private var apiKey: String = KeychainHelper.load(for: .finnhubAPIKey) ?? ""
    @State private var saveConfirmed = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Finnhub provides free real-time WebSocket quotes and symbol search for US stocks.")
                        .foregroundStyle(.secondary)
                    Link("Get a free API key at finnhub.io →",
                         destination: URL(string: "https://finnhub.io/register")!)
                        .font(.subheadline)
                }
            } header: {
                Text("Finnhub API Key")
            }

            Section {
                SecureField("Paste your Finnhub API key here", text: $apiKey)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Save Key") {
                        KeychainHelper.save(apiKey, for: .finnhubAPIKey)
                        saveConfirmed = true
                        // Reconnect WebSocket with new key
                        watchlistVM.finnhub.disconnect()
                        watchlistVM.finnhub.connect(symbols: watchlistVM.tickers.map(\.symbol))
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            saveConfirmed = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKey.isEmpty)

                    if saveConfirmed {
                        Label("Saved!", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .transition(.opacity.combined(with: .scale))
                    }
                }
                .animation(.easeInOut, value: saveConfirmed)
            }

            Section("About") {
                LabeledContent("Data Sources") {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Live prices: Finnhub WebSocket")
                        Text("Historical charts: Yahoo Finance")
                        Text("Portfolio: Plaid Investments API")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                LabeledContent("Minimum macOS") { Text("13.0 Ventura") }
                LabeledContent("Version") { Text("1.0.0") }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .frame(maxWidth: 520)
    }
}
