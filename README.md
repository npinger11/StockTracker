# StockTracker

A native macOS app (SwiftUI) that tracks stock prices in real time, displays price charts with adjustable moving average overlays, and pulls your SoFi brokerage portfolio via Plaid.

---

## Features

- **Live watchlist** — real-time bid/ask price and % change via Finnhub WebSocket
- **Add / remove tickers** — search by symbol or company name
- **Interactive price chart** — historical OHLCV from Yahoo Finance (6-month default, up to 5 years)
- **Dual moving averages** — toggle SMA or EMA independently; drag a slider to adjust each period (5–200 days)
- **SoFi portfolio** — pull holdings (shares, market value, cost basis, gain/loss) via Plaid Investments API
- Watchlist persisted to disk; API keys stored securely in macOS Keychain

---

## Requirements

| Requirement | Version |
|---|---|
| macOS | 13.0 Ventura or later |
| Xcode | 15.0 or later |
| Finnhub API key | Free — https://finnhub.io/register |
| Plaid developer account | Free — https://dashboard.plaid.com/signup |

---

## 1. Open in Xcode

```bash
open /Users/natepinger/StockTracker/StockTracker.xcodeproj
```

Or double-click `StockTracker.xcodeproj` in Finder.

---

## 2. Set Your Signing Team (Required)

1. In Xcode, click **StockTracker** in the project navigator (top of the left panel)
2. Select the **StockTracker** target → **Signing & Capabilities** tab
3. Under **Signing**, choose your **Team** (your personal Apple ID works fine — no paid membership needed for local development)

---

## 3. Build & Run

Press **Cmd+R** (or Product → Run). The app will launch.

---

## 4. First-Time App Setup

### Step 1 — Finnhub API Key (required for live prices & search)

1. Sign up at https://finnhub.io/register (free, takes 30 seconds)
2. Copy your API key from the dashboard
3. In the app: **Settings** tab → paste the key → **Save Key**

The watchlist will now connect via WebSocket and show live prices.

### Step 2 — Add Tickers to Your Watchlist

1. In the **Watchlist** tab, click the **+** button (top right)
2. Type a ticker symbol (e.g. `AAPL`) or company name
3. Click **Add** next to any result

Click a ticker to open its chart in the detail pane. Use the MA controls at the bottom to toggle/adjust moving averages.

### Step 3 — Connect SoFi via Plaid (optional)

#### 3a. Create a Free Plaid Developer Account

1. Go to https://dashboard.plaid.com/signup and create a free account
2. In the Plaid dashboard, navigate to **Team Settings → Keys** and copy your **Client ID** and **Secret**
3. For **Sandbox** (demo data with fake holdings): use immediately — no approval required
4. For **Development** (real SoFi account): submit a request in the Plaid dashboard under **Team Settings → Request Development Access** (approval typically takes 1–3 business days; use "Personal finance / portfolio monitoring" as the use case)

#### 3b. Enter Credentials in the App

1. In the app: click **Portfolio** in the sidebar
2. The setup form appears — paste your **Client ID** and **Secret**
3. Choose **Sandbox** (demo data) or **Development** (real SoFi)
4. Click **Save & Continue**

#### 3c. Connect Your Account

1. Click **Connect via Plaid**
2. A Plaid Link window opens — search for **SoFi** and sign in with your SoFi credentials
3. After successful authentication, your holdings load automatically

Your Plaid access token is stored in the macOS Keychain — you only need to authenticate once.

---

## Data Sources

| Data | Source | Cost |
|---|---|---|
| Live prices | Finnhub WebSocket | Free (60 REST calls/min) |
| Historical OHLCV | Yahoo Finance v8 API (unofficial) | Free, no key needed |
| SoFi portfolio holdings | Plaid Investments API | Free (Development tier, up to 100 connections) |

---

## Security Notes

- Your Finnhub API key and Plaid credentials are stored **only** in the macOS Keychain — never in source code or any file
- Plaid's `client_secret` and access tokens are treated as secrets; this app makes Plaid API calls directly (suitable for personal use — not App Store distribution)
- The app is **not sandboxed** to allow Keychain access and unrestricted network access

---

## Project Structure

```
StockTracker/
├── StockTrackerApp.swift          ← App entry point
├── Models/                        ← Data structures
├── Services/
│   ├── FinnhubService.swift       ← WebSocket live prices + symbol search
│   ├── YahooFinanceService.swift  ← Historical OHLCV data
│   └── PlaidService.swift         ← Plaid Link + holdings API
├── ViewModels/                    ← ObservableObject state management
├── Views/                         ← SwiftUI views
├── Utilities/
│   ├── MovingAverageCalculator.swift  ← SMA & EMA calculation
│   └── KeychainHelper.swift           ← Secure key storage
└── Resources/
    └── Info.plist
```

---

## Troubleshooting

**Prices show "—" and the connection badge says "Connecting…"**
→ Your Finnhub API key may not be saved yet. Go to **Settings** and re-paste it.

**Yahoo Finance chart fails to load**
→ Yahoo Finance's unofficial API occasionally changes. Retry, or switch to a different time range.

**Plaid says "INVALID_CREDENTIALS"**
→ Double-check your Client ID and Secret in the Plaid dashboard under **Team Settings → Keys**. Make sure you're using the correct environment's secret (Sandbox vs Development).

**SoFi not found in Plaid Link**
→ Search for "SoFi" in the institution search within Plaid Link. Make sure you're on Development mode and have been approved for real connections.

**Holdings don't appear after connecting**
→ Plaid may take a few seconds to sync. Tap **Refresh** in the Portfolio view.
