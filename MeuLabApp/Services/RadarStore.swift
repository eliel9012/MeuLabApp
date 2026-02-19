import WebKit
import SwiftUI

/// Store global que mantém uma única instância do WKWebView para o Radar.
/// Isso garante que o Radar seja carregado apenas uma vez e permaneça "quente" na RAM.
@MainActor
class RadarStore: NSObject, ObservableObject {
    static let shared = RadarStore()
    static let processPool = WKProcessPool()
    let webView: WKWebView
    enum LoadingState { case idle, loading, loaded, error }
    @Published var state: LoadingState = .idle
    
    private override init() {
        let config = WKWebViewConfiguration()
        config.processPool = Self.processPool
        config.allowsInlineMediaPlayback = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        
        // Mantém cookies e cache se possível
        config.websiteDataStore = .default()
        
        self.webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 600), configuration: config)
        self.webView.isOpaque = false
        self.webView.backgroundColor = .clear
        
        super.init()
        
        prewarm()
    }
    
    func prewarm() {
        guard state == .idle || state == .error else { return }
        state = .loading
        
        let html = RadarHTML.content
        let baseURL = URL(string: "https://radar.meulab.fun/")
        
        webView.navigationDelegate = self
        webView.loadHTMLString(html, baseURL: baseURL)
    }
    
    // WKNavigationDelegate methods for the persistent store
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        state = .loaded
        print("✅ RadarWebViewStore: Map loaded successfully")
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        state = .error
        print("❌ RadarWebViewStore: Map load failed: \(error.localizedDescription)")
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        state = .error
        print("❌ RadarWebViewStore: Map provisional load failed: \(error.localizedDescription)")
    }
    
    func reload() {
        let html = RadarHTML.content
        let baseURL = URL(string: "https://radar.meulab.fun/")
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    /// Loads the HTML content only if the webView is not already displaying content.
    func ensureLoaded(html: String, baseURL: URL?) {
        if webView.url == nil && webView.backForwardList.currentItem == nil {
            load(html: html, baseURL: baseURL)
        }
    }

    /// Loads the given HTML string into the webView.
    func load(html: String, baseURL: URL?) {
        webView.loadHTMLString(html, baseURL: baseURL)
    }
}
