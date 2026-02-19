import SwiftUI
import WebKit

struct RadarWebView: UIViewRepresentable {
    let aircraft: [Aircraft]
    let html: String
    let baseURL: URL?
    let isInteractive: Bool
    let forcePanelClosed: Bool
    @Binding var selectedAircraftID: Aircraft.ID?
    var onMapChange: (([Double]) -> Void)? // [minLat, maxLat, minLon, maxLon]

    init(
        aircraft: [Aircraft] = [],
        html: String = RadarHTML.content,
        baseURL: URL? = URL(string: "https://radar.meulab.fun/"),
        isInteractive: Bool = true,
        forcePanelClosed: Bool = false,
        selectedAircraftID: Binding<Aircraft.ID?> = .constant(nil),
        onMapChange: (([Double]) -> Void)? = nil
    ) {
        self.aircraft = aircraft
        self.html = html
        self.baseURL = baseURL
        self.isInteractive = isInteractive
        self.forcePanelClosed = forcePanelClosed
        self._selectedAircraftID = selectedAircraftID
        self.onMapChange = onMapChange
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let store = LegacyRadarWebViewStore.shared
        let webView = store.webView
        
        webView.scrollView.isScrollEnabled = isInteractive
        webView.isUserInteractionEnabled = isInteractive
        context.coordinator.forcePanelClosed = forcePanelClosed
        webView.navigationDelegate = context.coordinator
        
        // Garante que o conteúdo esteja carregado
        store.ensureLoaded(html: html, baseURL: baseURL)
        
        // Injeção inicial se já tiver dados e a página estiver carregada
        if !aircraft.isEmpty, webView.url != nil || webView.backForwardList.currentItem != nil {
            injectAircraft(webView)
        }
        
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.scrollView.isScrollEnabled = isInteractive
        webView.isUserInteractionEnabled = isInteractive
        context.coordinator.forcePanelClosed = forcePanelClosed
        context.coordinator.selectedID = selectedAircraftID 
        context.coordinator.onMapChange = onMapChange

        // Garante que o conteúdo esteja carregado
        LegacyRadarWebViewStore.shared.ensureLoaded(html: html, baseURL: baseURL)

        // Se solicitado, tenta fechar o painel quando houver conteúdo
        if forcePanelClosed, webView.url != nil || webView.backForwardList.currentItem != nil {
            webView.evaluateJavaScript(Self.closePanelScript, completionHandler: nil)
        }
        
        // Injeta dados quando houver conteúdo
        if webView.url != nil || webView.backForwardList.currentItem != nil {
            injectAircraft(webView)
            
            // Inject selection if present
            if let selectedID = selectedAircraftID {
                // Ensure the aircraft data is present before selecting
                // But data injection is async/throttled.
                // We should inject selection command regardless, as JS might already have the data.
                let script = "if(typeof selectAC === 'function') { selectAC('\(selectedID)'); if(MAP && AC.has('\(selectedID)')) { var p=AC.get('\(selectedID)'); MAP.center=new mapkit.Coordinate(p.lat,p.lon); }}"
                webView.evaluateJavaScript(script, completionHandler: nil)
            }
        }
    }

    private func injectAircraft(_ webView: WKWebView) {
        guard !aircraft.isEmpty else { return }
        // Throttle JS injection to avoid saturating the main thread and causing gesture gate timeouts
        let now = Date()
        if now.timeIntervalSince(RadarWebView.lastInjection) < 0.5 {
            return
        }
        
        // Só injeta se o webView já tiver conteúdo carregado
        let hasContent = webView.url != nil || webView.backForwardList.currentItem != nil
        guard hasContent else { return }
        
        // Prepare list for JS
        let jsList = aircraft.map { ac in
            [
                "hex": ac.hex ?? ac.id,
                "flight": ac.callsign,
                "lat": ac.lat as Any,
                "lon": ac.lon as Any,
                "alt_baro": ac.altitudeFt,
                "gs": ac.speedKt,
                "track": ac.track as Any,
                "t": ac.model as Any,
                "r": ac.registration as Any,
                "src": ac.source.rawValue
            ]
        }
        
        let container = ["aircraft": jsList]
        if let data = try? JSONSerialization.data(withJSONObject: container),
           let jsonString = String(data: data, encoding: .utf8) {
            let script = "updateData(\(jsonString)); if (typeof setOnline==='function'){ try { setOnline(true,false); FE=0; } catch(e){} }"
            webView.evaluateJavaScript(script, completionHandler: nil)
        }

        RadarWebView.lastInjection = now
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var hasLoaded = false
        var forcePanelClosed = false
        var selectedID: Aircraft.ID?
        var onMapChange: (([Double]) -> Void)?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Register handler if not already done
            webView.configuration.userContentController.removeScriptMessageHandler(forName: "onMapChange")
            webView.configuration.userContentController.add(self, name: "onMapChange")
            
            guard forcePanelClosed else { return }
            webView.evaluateJavaScript(RadarWebView.closePanelScript, completionHandler: nil)
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "onMapChange", let bounds = message.body as? [Double], bounds.count == 4 {
                print("[RadarWebView] 🗺️ Map bounds changed: \(bounds)")
                onMapChange?(bounds)
            }
        }
    }

    private static let closePanelScript =
        "var p=document.getElementById('panel'); if(p){p.classList.add('hidden');}" +
        "var b=document.getElementById('btn-panel'); if(b){b.classList.remove('active');}"

    private static var lastInjection: Date = .distantPast
}

