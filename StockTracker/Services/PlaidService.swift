import Foundation

enum PlaidEnvironment: String, CaseIterable, Identifiable {
    case sandbox     = "sandbox"
    case development = "development"
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .sandbox:     return "Sandbox (demo data)"
        case .development: return "Development (real SoFi account)"
        }
    }
    var baseURL: String {
        "https://\(rawValue).plaid.com"
    }
}

@MainActor
final class PlaidService: ObservableObject {

    @Published var isLinked: Bool = false
    @Published var isLoading: Bool = false
    @Published var error: String?

    // MARK: - Credentials (Keychain-backed)

    var clientID: String?   { KeychainHelper.load(for: .plaidClientID) }
    var secret: String?     { KeychainHelper.load(for: .plaidSecret) }
    var accessToken: String?{ KeychainHelper.load(for: .plaidAccessToken) }
    var environment: PlaidEnvironment {
        PlaidEnvironment(rawValue: KeychainHelper.load(for: .plaidEnvironment) ?? "sandbox") ?? .sandbox
    }

    var hasCredentials: Bool { clientID != nil && secret != nil }
    var hasAccessToken: Bool { accessToken != nil }

    func saveCredentials(clientID: String, secret: String, environment: PlaidEnvironment) {
        KeychainHelper.save(clientID, for: .plaidClientID)
        KeychainHelper.save(secret,   for: .plaidSecret)
        KeychainHelper.save(environment.rawValue, for: .plaidEnvironment)
    }

    func disconnectAccount() {
        KeychainHelper.delete(for: .plaidAccessToken)
        isLinked = false
    }

    // MARK: - Plaid Link flow

    /// Step 1: get a short-lived link_token from Plaid.
    func createLinkToken() async throws -> String {
        guard let clientID, let secret else { throw PlaidError.missingCredentials }
        let body: [String: Any] = [
            "client_id":   clientID,
            "secret":      secret,
            "client_name": "StockTracker",
            "country_codes": ["US"],
            "language":    "en",
            "user":        ["client_user_id": "stocktracker-user-\(clientID.prefix(8))"],
            "products":    ["investments"]
        ]
        let json = try await post(path: "/link/token/create", body: body)
        guard let token = json["link_token"] as? String else { throw PlaidError.invalidResponse("missing link_token") }
        return token
    }

    /// Step 2: exchange the public_token (from Plaid Link) for a durable access_token.
    func exchangePublicToken(_ publicToken: String) async throws {
        guard let clientID, let secret else { throw PlaidError.missingCredentials }
        let body: [String: Any] = [
            "client_id":    clientID,
            "secret":       secret,
            "public_token": publicToken
        ]
        let json = try await post(path: "/item/public_token/exchange", body: body)
        guard let token = json["access_token"] as? String else { throw PlaidError.invalidResponse("missing access_token") }
        KeychainHelper.save(token, for: .plaidAccessToken)
        isLinked = true
    }

    // MARK: - Investment holdings

    func fetchHoldings() async throws -> [PortfolioHolding] {
        guard let clientID, let secret, let accessToken else { throw PlaidError.missingCredentials }
        let body: [String: Any] = [
            "client_id":    clientID,
            "secret":       secret,
            "access_token": accessToken
        ]
        let json = try await post(path: "/investments/holdings/get", body: body)
        return try parseHoldings(json: json)
    }

    // MARK: - JSON helpers

    private func post(path: String, body: [String: Any]) async throws -> [String: Any] {
        let base = environment.baseURL
        guard let url = URL(string: "\(base)\(path)") else { throw PlaidError.invalidURL }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PlaidError.invalidResponse("response is not JSON object")
        }
        // Surface Plaid API errors
        if let errObj = json["error_message"] as? String {
            throw PlaidError.apiError(errObj)
        }
        return json
    }

    private func parseHoldings(json: [String: Any]) throws -> [PortfolioHolding] {
        guard let holdingsRaw   = json["holdings"]   as? [[String: Any]],
              let securitiesRaw = json["securities"]  as? [[String: Any]] else {
            throw PlaidError.invalidResponse("missing holdings/securities")
        }

        // Build security_id → security lookup
        var secMap: [String: [String: Any]] = [:]
        for sec in securitiesRaw {
            if let sid = sec["security_id"] as? String { secMap[sid] = sec }
        }

        return holdingsRaw.compactMap { h -> PortfolioHolding? in
            guard let sid       = h["security_id"]      as? String,
                  let sec       = secMap[sid],
                  let qty       = h["quantity"]          as? Double,
                  let instPrice = h["institution_price"] as? Double,
                  let instVal   = h["institution_value"] as? Double else { return nil }

            // Skip pure cash / sweep positions
            if sec["is_cash_equivalent"] as? Bool == true { return nil }

            return PortfolioHolding(
                symbol:          (sec["ticker_symbol"] as? String) ?? "N/A",
                name:            (sec["name"]          as? String) ?? "Unknown",
                quantity:        qty,
                institutionPrice: instPrice,
                institutionValue: instVal,
                costBasis:       h["cost_basis"]       as? Double,
                securityType:    (sec["type"]          as? String) ?? "equity"
            )
        }
        .sorted { $0.institutionValue > $1.institutionValue }
    }

    // MARK: - Errors

    enum PlaidError: LocalizedError {
        case missingCredentials
        case invalidURL
        case invalidResponse(String)
        case apiError(String)
        var errorDescription: String? {
            switch self {
            case .missingCredentials:     return "Plaid credentials not configured"
            case .invalidURL:             return "Invalid Plaid endpoint URL"
            case .invalidResponse(let d): return "Invalid Plaid response: \(d)"
            case .apiError(let msg):      return "Plaid API error: \(msg)"
            }
        }
    }
}
