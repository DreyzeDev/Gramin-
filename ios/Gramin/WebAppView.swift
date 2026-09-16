import SwiftUI
import UIKit
import WebKit

struct WebAppView: UIViewRepresentable {
    private let appURL = URL(string: "https://gramin.moonfacet.com/app")!

    func makeCoordinator() -> Coordinator { Coordinator(appURL: appURL) }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "gramin")

        if let token = KeychainStore.read("gramin-token"),
           let data = try? JSONEncoder().encode(token),
           let encoded = String(data: data, encoding: .utf8) {
            controller.addUserScript(WKUserScript(
                source: "window.__GRAMIN_NATIVE_TOKEN = \(encoded);",
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            ))
        }

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground
        context.coordinator.webView = webView
        context.coordinator.loadApp()
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "gramin")
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let appURL: URL
        weak var webView: WKWebView?

        init(appURL: URL) { self.appURL = appURL }

        func loadApp() {
            var request = URLRequest(url: appURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            webView?.load(request)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "gramin", let payload = message.body as? [String: Any],
                  let type = payload["type"] as? String else { return }
            switch type {
            case "saveToken":
                if let token = payload["value"] as? String { KeychainStore.save(token, key: "gramin-token") }
            case "deleteToken":
                KeychainStore.delete("gramin-token")
            case "haptic":
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            default:
                break
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
            if navigationAction.navigationType == .linkActivated, url.host != appURL.host {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            showOffline(in: webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            showOffline(in: webView)
        }

        private func showOffline(in webView: WKWebView) {
            let destination = appURL.absoluteString
            let html = """
            <!doctype html><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
            <style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:#f3f3f3;color:#050505;font-family:-apple-system;padding:24px;box-sizing:border-box;text-align:center}.card{max-width:360px}b{font-size:34px}p{color:#666;line-height:1.5}button{border:0;border-radius:17px;background:#050505;color:white;padding:16px 28px;font:700 16px -apple-system}</style>
            <div class="card"><b>Нет соединения</b><p>Gramin обновится и откроется, когда появится интернет.</p><button onclick="location.href='\(destination)'">Повторить</button></div>
            """
            webView.loadHTMLString(html, baseURL: nil)
        }
    }
}
