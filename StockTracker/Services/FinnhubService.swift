import Foundation
import Combine

/// Manages a persistent Finnhub WebSocket connection and publishes live trade prices.
@MainActor
final class FinnhubService: ObservableObject {

    @Published var latestPrices: [String: Double] = [:]
    @Published var previousCloses: [String: Double] = [:]
    @Published var isConnected: Bool = false

    private var webSocketTask: URLSessionWebSocketTask?
    private let session = URLSession.shared
    private var subscribedSymbols: Set<String> = []
    private var reconnectTask: Task<Void, Never>?
    private var reconnectDelay: TimeInterval = 2

    var apiKey: String? { KeychainHelper.load(for: .finnhubAPIKey) }

    // MARK: - Connection management

    func connect(symbols: [String]) {
        subscribedSymbols = Set(symbols.map { $0.uppercased() })
        openConnection()
    }

    func addSymbol(_ symbol: String) {
        let s = symbol.uppercased()
        subscribedSymbols.insert(s)
        guard isConnected else { openConnection(); return }
        sendMessage(#"{"type":"subscribe","symbol":"\#(s)"}"#)
        Task { await fetchInitialQuote(symbol: s) }
    }

    func removeSymbol(_ symbol: String) {
        let s = symbol.uppercased()
        subscribedSymbols.remove(s)
        sendMessage(#"{"type":"unsubscribe","symbol":"\#(s)"}"#)
        latestPrices.removeValue(forKey: s)
        previousCloses.removeValue(forKey: s)
    }

    func disconnect() {
        reconnectTask?.cancel()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
    }

    // MARK: - Private helpers

    private func openConnection() {
        guard let apiKey, !apiKey.isEmpty else {
            isConnected = false
            return
        }
        guard let url = URL(string: "wss://ws.finnhub.io?token=\(apiKey)") else { return }

        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        isConnected = true
        reconnectDelay = 2

        for symbol in subscribedSymbols {
            sendMessage(#"{"type":"subscribe","symbol":"\#(symbol)"}"#)
        }
        receiveNext()

        // Fetch initial REST quotes for all symbols
        Task {
            for symbol in subscribedSymbols {
                await fetchInitialQuote(symbol: symbol)
            }
        }
    }

    private func receiveNext() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .success(let msg):
                    self.handle(message: msg)
                    self.receiveNext()
                case .failure(let error):
                    print("FinnhubService WebSocket error: \(error.localizedDescription)")
                    self.isConnected = false
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func handle(message: URLSessionWebSocketTask.Message) {
        let data: Data?
        switch message {
        case .string(let s): data = s.data(using: .utf8)
        case .data(let d):   data = d
        @unknown default:    return
        }
        guard let data,
              let decoded = try? JSONDecoder().decode(FinnhubMessage.self, from: data),
              case .trade(let tradeMsg) = decoded else { return }

        for trade in tradeMsg.trades {
            latestPrices[trade.symbol] = trade.price
        }
    }

    private func sendMessage(_ text: String) {
        webSocketTask?.send(.string(text)) { _ in }
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        let delay = reconnectDelay
        reconnectDelay = min(reconnectDelay * 2, 64)
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.openConnection()
        }
    }

    // MARK: - REST API

    func fetchInitialQuote(symbol: String) async {
        guard let apiKey, !apiKey.isEmpty,
              let url = URL(string: "https://finnhub.io/api/v1/quote?symbol=\(symbol)&token=\(apiKey)") else { return }
        guard let (data, _) = try? await session.data(from: url),
              let quote = try? JSONDecoder().decode(FinnhubQuote.self, from: data) else { return }
        if quote.c > 0 { latestPrices[symbol] = quote.c }
        if quote.pc > 0 { previousCloses[symbol] = quote.pc }
    }

    func searchSymbols(query: String) async throws -> [SymbolSearchResult] {
        guard let apiKey, !apiKey.isEmpty else { return [] }
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://finnhub.io/api/v1/search?q=\(encoded)&token=\(apiKey)") else { return [] }
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(SymbolSearchResponse.self, from: data)
        return response.result.filter { $0.type == "Common Stock" }
    }
}
