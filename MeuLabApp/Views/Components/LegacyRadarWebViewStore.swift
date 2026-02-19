import Foundation
import WebKit

/// This file is retained to avoid breaking the Xcode project structure.
/// The class has been renamed to avoid a naming conflict with the primary version in Services.
final class LegacyRadarWebViewStore {
    static let shared = LegacyRadarWebViewStore()
    let webView: WKWebView
    
    private init() {
        let configuration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: configuration)
    }
    
    func load(html: String, baseURL: URL?) {
        webView.loadHTMLString(html, baseURL: baseURL)
    }
    
    func ensureLoaded(html: String, baseURL: URL?) {
        if webView.url == nil && webView.backForwardList.currentItem == nil {
            load(html: html, baseURL: baseURL)
        }
    }
}
