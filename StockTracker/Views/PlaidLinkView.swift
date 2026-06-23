import SwiftUI
import WebKit

// MARK: - Sheet wrapper (SwiftUI)

struct PlaidLinkSheet: View {
    let linkToken: String
    let onSuccess: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Connect SoFi via Plaid")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            PlaidLinkWebView(linkToken: linkToken) { publicToken in
                onSuccess(publicToken)
                dismiss()
            }
        }
        .frame(width: 640, height: 680)
    }
}

// MARK: - WKWebView wrapper (AppKit bridge)

struct PlaidLinkWebView: NSViewRepresentable {
    let linkToken: String
    let onSuccess: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSuccess: onSuccess)
    }

    func makeNSView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "plaidHandler")

        let config = WKWebViewConfiguration()
        config.userContentController = controller
        // Allow inline media & JS
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        let html = buildHTML(token: linkToken)
        webView.loadHTMLString(html, baseURL: URL(string: "https://plaid.com"))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // No-op: only load once on creation
    }

    // MARK: - HTML template

    private func buildHTML(token: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Connect Account</title>
          <style>
            * { box-sizing: border-box; margin: 0; padding: 0; }
            body {
              font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
              display: flex; align-items: center; justify-content: center;
              height: 100vh; background: #f5f5f7;
            }
            .card {
              background: white; border-radius: 18px;
              padding: 48px 40px; text-align: center;
              box-shadow: 0 4px 24px rgba(0,0,0,.08);
              max-width: 400px; width: 90%;
            }
            .icon { font-size: 48px; margin-bottom: 16px; }
            h1 { font-size: 22px; font-weight: 600; margin-bottom: 8px; color: #1d1d1f; }
            p  { font-size: 15px; color: #6e6e73; margin-bottom: 28px; line-height: 1.5; }
            button {
              background: #0071e3; color: #fff;
              border: none; border-radius: 12px;
              padding: 14px 32px; font-size: 16px;
              font-weight: 500; cursor: pointer; width: 100%;
            }
            button:hover { background: #005bbf; }
            button:disabled { background: #bbb; cursor: default; }
            #status { margin-top: 14px; font-size: 13px; color: #6e6e73; }
          </style>
        </head>
        <body>
          <div class="card">
            <div class="icon">🔗</div>
            <h1>Connect SoFi</h1>
            <p>Click below to securely link your SoFi brokerage account through Plaid.</p>
            <button id="btn" onclick="openLink()">Connect with Plaid</button>
            <div id="status"></div>
          </div>

          <script src="https://cdn.plaid.com/link/v2/stable/link-initialize.js"></script>
          <script>
            var handler = null;

            function openLink() {
              if (handler) { handler.open(); return; }
              document.getElementById('btn').disabled = true;
              document.getElementById('status').textContent = 'Initializing…';

              handler = Plaid.create({
                token: '\(linkToken)',
                onSuccess: function(public_token, metadata) {
                  window.webkit.messageHandlers.plaidHandler.postMessage({
                    event: 'success',
                    public_token: public_token
                  });
                },
                onExit: function(err, metadata) {
                  window.webkit.messageHandlers.plaidHandler.postMessage({
                    event: 'exit',
                    error: err ? (err.display_message || err.error_message || 'Exited') : null
                  });
                  document.getElementById('btn').disabled = false;
                  document.getElementById('status').textContent = err
                    ? '⚠️ ' + (err.display_message || err.error_message)
                    : '';
                  handler = null;
                },
                onLoad: function() {
                  document.getElementById('btn').disabled = false;
                  document.getElementById('status').textContent = '';
                  handler.open();
                }
              });
            }

            // Auto-open once the page loads
            window.addEventListener('load', function() {
              setTimeout(openLink, 400);
            });
          </script>
        </body>
        </html>
        """
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let onSuccess: (String) -> Void
        weak var webView: WKWebView?

        init(onSuccess: @escaping (String) -> Void) {
            self.onSuccess = onSuccess
        }

        // Receive messages from Plaid Link JS
        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "plaidHandler",
                  let body = message.body as? [String: Any],
                  let event = body["event"] as? String else { return }

            if event == "success", let token = body["public_token"] as? String {
                DispatchQueue.main.async { self.onSuccess(token) }
            }
        }

        // Allow navigation to Plaid CDN
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }
    }
}
