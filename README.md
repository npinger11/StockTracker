# StockTracker

> A native macOS stock tracker built with SwiftUI — live prices, interactive charts with customizable moving average overlays, and SoFi brokerage portfolio import via Plaid.

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)
![Swift](https://img.shields.io/badge/swift-5.10-orange)
![Xcode](https://img.shields.io/badge/xcode-15%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)

---

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Requirements](#requirements)
- [Getting Started](#getting-started)
- [First-Time Setup](#first-time-setup)
- [Usage Guide](#usage-guide)
- [Data Sources](#data-sources)
- [Project Structure](#project-structure)
- [Development](#development)
- [Security](#security)
- [Troubleshooting](#troubleshooting)
- [Disclaimer](#disclaimer)

---

## Features

| Feature | Detail |
|---|---|
| **Live watchlist** | Real-time price updates via Finnhub WebSocket; green/red % change arrows |
| **Symbol search** | Debounced Finnhub REST search by ticker or company name |
| **Price chart** | Historical OHLCV line chart (1M / 3M / 6M / 1Y / 2Y / 5Y ranges) |
| **Dual MA overlays** | Two independent moving average lines — toggle, switch SMA ↔ EMA, drag period slider (5–200 days) |
| **MA color & width** | Full system ColorPicker + line width slider (0.5–5.0 pt) per overlay |
| **SoFi portfolio** | Import holdings (shares, market value, cost basis, gain/loss %) via Plaid Investments API |
| **Secure storage** | Watchlist persisted to `Application Support`; API keys stored in macOS Keychain |
| **WebSocket reconnect** | Exponential back-off reconnection — stays live through network interruptions |

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     SwiftUI Views                        │
│  ContentView (NavigationSplitView)                       │
│  ├── WatchlistView  ──── AddTickerView (sheet)           │
│  ├── StockDetailView ─── MAControlPanel × 2             │
│  ├── PortfolioView  ──── PlaidLinkView (WKWebView sheet) │
│  └── SettingsView                                        │
└───────────────────┬─────────────────────────────────────┘
                    │ @Published / @EnvironmentObject
┌───────────────────▼─────────────────────────────────────┐
│                   ViewModels                             │
│  WatchlistViewModel   ChartViewModel   PortfolioViewModel│
└───────┬───────────────────┬─────────────────────┬───────┘
        │                   │                     │
┌───────▼──────┐  ┌─────────▼──────┐  ┌──────────▼──────┐
│ FinnhubService│  │YahooFinanceSvc │  │  PlaidService   │
│  WebSocket    │  │  REST (v8)     │  │  REST + OAuth   │
│  + REST quote │  │  OHLCV bars    │  │  Link (WKWebView)│
└───────────────┘  └────────────────┘  └─────────────────┘
        │                                        │
┌───────▼────────────────────────────────────────▼───────┐
│              Utilities                                   │
│   MovingAverageCalculator (SMA / EMA)                   │
│   KeychainHelper                                        │
└─────────────────────────────────────────────────────────┘
```

**Technology choices:**
- **Swift Concurrency** (`async/await`, `Task`, `URLSessionWebSocketTask`) — no third-party networking
- **Swift Charts** (built-in, macOS 13+) — `LineMark` for price + MA overlays, `StrokeStyle` for dashes
- **Combine** — `@Published` → `sink` for live price updates flowing into watchlist rows
- **WKWebView** + `WKScriptMessageHandler` — embeds Plaid Link JS SDK, captures `public_token` via message bridge

---

## Requirements

| Requirement | Version |
|---|---|
| macOS | **13.0 Ventura** or later |
| Xcode | **15.0** or later |
| Finnhub API key | Free — [finnhub.io/register](https://finnhub.io/register) |
| Plaid developer account | Free — [dashboard.plaid.com/signup](https://dashboard.plaid.com/signup) |

---

## Getting Started

### 1. Clone & Open

```bash
git clone https://github.com/npinger11/StockTracker.git
cd StockTracker
open StockTracker.xcodeproj
```

### 2. Configure Signing

1. In Xcode, click the **StockTracker** project in the navigator
2. Select the **StockTracker** target → **Signing & Capabilities** tab
3. Set your **Team** — a personal Apple ID is sufficient (no paid membership required)

### 3. Build & Run

Press **`Cmd+R`** or choose **Product → Run**.

---

## First-Time Setup

### Step 1 — Finnhub API Key (required)

Finnhub provides free real-time US stock quotes via WebSocket and symbol search via REST.

1. Create a free account at [finnhub.io/register](https://finnhub.io/register) (~30 seconds)
2. Copy your API key from the Finnhub dashboard
3. In StockTracker: open the **Settings** tab → paste your key → click **Save Key**

The watchlist connection badge will turn green and prices will begin streaming.

### Step 2 — Build Your Watchlist

1. In the **Watchlist** tab, click **`+`** in the top-right toolbar
2. Type a ticker (e.g. `AAPL`) or company name — results appear as you type
3. Click **Add** next to any result

Click any ticker row to open its price chart in the detail pane.

### Step 3 — Connect SoFi via Plaid (optional)

Plaid's Investments API lets the app securely read your SoFi brokerage holdings.

#### 3a. Get Plaid API credentials

1. Create a free account at [dashboard.plaid.com/signup](https://dashboard.plaid.com/signup)
2. Go to **Team Settings → Keys** and copy your **Client ID** and **Secret**

> **Sandbox vs Development**
> - **Sandbox** — works immediately with realistic demo holdings, no real account needed
> - **Development** — connects to your real SoFi account; requires approval via *Team Settings → Request Development Access* (use case: *"Personal finance / portfolio monitoring"*; typical approval: 1–3 business days)

#### 3b. Enter credentials in the app

1. Click **Portfolio** in the sidebar
2. Paste your **Client ID** and **Secret**, choose your environment, click **Save & Continue**

#### 3c. Link your SoFi account

1. Click **Connect via Plaid**
2. In the Plaid Link window, search for **SoFi** and sign in with your SoFi credentials
3. Your holdings load automatically after successful authentication

> Your Plaid access token is stored in the macOS Keychain — you only need to authenticate once per device.

---

## Usage Guide

### Watchlist

| Action | How |
|---|---|
| Add ticker | Click **`+`** → search → **Add** |
| Remove ticker | Right-click a row → **Remove from Watchlist** |
| View chart | Click any ticker row |
| Live status | Green dot = WebSocket connected; orange dot = reconnecting |

Prices update in real time during US market hours (9:30 AM – 4:00 PM ET). Outside market hours the last trade price is shown via the Finnhub REST quote endpoint.

### Charts & Moving Averages

Select a ticker to open its chart. The **time range** selector (1M / 3M / 6M / 1Y / 2Y / 5Y) is in the top-right of the detail pane.

The **MA control strip** at the bottom of the chart gives you full control over two independent overlay lines:

| Control | Description |
|---|---|
| Checkbox | Toggle the overlay on/off (color and width are preserved while off) |
| SMA / EMA | Switch between Simple and Exponential moving average |
| Period slider | Drag to set the lookback window (5–200 trading days) |
| Color picker | Opens the macOS system color wheel — choose any color |
| Width slider | Line thickness from 0.5 pt (hairline) to 5.0 pt (bold) |

**Default settings:** MA 1 = SMA-20 in orange; MA 2 = EMA-50 in purple.

> **SMA vs EMA:** SMA weights all days equally. EMA applies a multiplier `k = 2 / (period + 1)`, giving more weight to recent prices — it reacts faster to sudden moves and is seeded from the SMA of the first `period` bars.

### Portfolio

The Portfolio tab imports your SoFi holdings via Plaid and displays:

- Total portfolio market value and overall gain/loss ($ and %)
- Per-holding table: symbol, name, shares, price, market value, cost basis, gain/loss

Click **Refresh** to pull the latest data on demand. Plaid typically syncs holdings overnight after market close.

### Settings

- **Finnhub API Key** — paste and save your key; the WebSocket reconnects immediately
- **About** — data source attribution and app version

---

## Data Sources

| Data type | Provider | Cost | Notes |
|---|---|---|---|
| Live US stock prices | [Finnhub](https://finnhub.io) WebSocket | Free | Up to 50 symbol subscriptions; 60 REST calls/min |
| Historical OHLCV | Yahoo Finance v8 API | Free | Unofficial endpoint; no key required |
| SoFi portfolio holdings | [Plaid](https://plaid.com) Investments API | Free | Development tier: up to 100 real connections |

---

## Project Structure

```
StockTracker/
├── StockTrackerApp.swift          # @main — app entry point, scene setup
│
├── Models/
│   ├── StockTicker.swift          # Watchlist item: symbol, live price, change %
│   ├── PriceBar.swift             # OHLCV bar for chart rendering
│   ├── Quote.swift                # Finnhub WebSocket trade message + REST types
│   └── PortfolioHolding.swift     # Plaid investment holding + gain/loss helpers
│
├── Services/
│   ├── FinnhubService.swift       # WebSocket connection, subscribe/unsubscribe,
│   │                              #   REST quote fetch, symbol search, reconnect
│   ├── YahooFinanceService.swift  # v8 REST fetch → [PriceBar], NSNull handling
│   └── PlaidService.swift         # Link token create, public_token exchange,
│                                  #   /investments/holdings/get, Keychain I/O
│
├── ViewModels/
│   ├── WatchlistViewModel.swift   # Tickers list, Finnhub lifecycle, disk persist
│   ├── ChartViewModel.swift       # Bars, MA series, color/width, range, Y-scale
│   └── PortfolioViewModel.swift   # Holdings, totals, Plaid service bridge
│
├── Views/
│   ├── ContentView.swift          # NavigationSplitView (sidebar + content + detail)
│   ├── WatchlistView.swift        # Ticker list rows with live price badges
│   ├── AddTickerView.swift        # Search sheet with debounced autocomplete
│   ├── StockDetailView.swift      # Swift Charts price line + MA overlays + controls
│   ├── PortfolioView.swift        # Holdings Table, Plaid setup form, Link sheet
│   ├── PlaidLinkView.swift        # WKWebView + WKScriptMessageHandler bridge
│   └── SettingsView.swift         # Finnhub key entry + app info
│
├── Utilities/
│   ├── MovingAverageCalculator.swift  # SMA + EMA, chart-ready (date, value) output
│   └── KeychainHelper.swift           # Generic Keychain read/write/delete
│
└── Resources/
    └── Info.plist                 # Bundle metadata, ATS config
```

---

## Development

### Running Tests

The project includes two headless Swift test scripts that verify core logic without a simulator:

```bash
# Moving average calculation — 31 assertions (SMA, EMA, edge cases)
swift verify_ma.swift

# Color and line-width properties — 41 assertions (defaults, mutations, isolation)
swift verify_color_width.swift
```

Both scripts exit with code `0` on success and `1` on any failure.

### Regenerating the Xcode Project

If you add or rename source files, regenerate `project.pbxproj` with:

```bash
python3 generate_xcodeproj.py
```

Then reopen `StockTracker.xcodeproj` in Xcode and set your signing team again.

### Distribution Build

```bash
# Release build
xcodebuild \
  -project StockTracker.xcodeproj \
  -scheme StockTracker \
  -destination 'platform=macOS' \
  -configuration Release \
  CONFIGURATION_BUILD_DIR="$(pwd)/dist/build" \
  build

# Ad-hoc sign (runs on build machine; right-click → Open on others)
codesign --force --deep --sign - dist/build/StockTracker.app

# Package (preserves macOS resource forks)
ditto -c -k --keepParent --rsrc dist/build/StockTracker.app \
  dist/StockTracker-v1.0.0-macos.zip
```

> For distribution to other Macs without a Gatekeeper prompt, you need an Apple Developer ID certificate and notarization via `xcrun notarytool`.

---

## Security

- **Keychain only** — Finnhub API key, Plaid `client_id`, `secret`, and `access_token` are stored exclusively in the macOS Keychain; never written to disk, logged, or committed to source control
- **No backend** — Plaid API calls are made directly from the app (suitable for personal use; production apps should proxy through a backend)
- **Not sandboxed** — App Sandbox is disabled to allow unrestricted Keychain access and network connections
- **`.gitignore`** — `dist/`, `DerivedData/`, and `*.xcuserstate` are excluded; no secrets are in the repository

---

## Troubleshooting

**Prices show "—" / connection badge stays orange**
→ Your Finnhub API key may not be saved. Go to **Settings**, re-paste your key, and tap **Save Key**. The badge turns green within a few seconds.

**Chart fails to load**
→ Yahoo Finance's unofficial API occasionally returns errors. Tap **Retry** or switch to a different time range. Intraday ranges are most stable.

**Search returns no results**
→ Confirm your Finnhub key is saved in **Settings** — the search endpoint requires a valid key.

**Plaid: "INVALID_CREDENTIALS"**
→ Verify your **Client ID** and **Secret** under **Team Settings → Keys** in the Plaid dashboard. Ensure you're using the secret matching your selected environment (Sandbox ≠ Development).

**SoFi not appearing in Plaid Link**
→ You must be on **Development** mode with approved access to see real institutions.

**Holdings empty after connecting**
→ Plaid syncs investment data asynchronously. Tap **Refresh** after a few seconds; initial sync can take up to 60 seconds.

**Prices not streaming outside market hours**
→ The Finnhub WebSocket only delivers trades during live market sessions (Mon–Fri 9:30 AM–4:00 PM ET). Off-hours prices are fetched via REST when you add a ticker.

---

## Disclaimer

StockTracker is a personal productivity tool and does not provide financial advice. All data is for informational purposes only. Past price history and moving average signals are not indicative of future performance. Always consult a qualified financial professional before making investment decisions.

---

## License

MIT License — see [`LICENSE`](LICENSE) for details.
