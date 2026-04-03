import SwiftUI
import UIKit

/// Use em SwiftUI para mostrar a animação por cima da primeira tela.
/// Exemplo:
/// ContentView()
///   .radarSplash()
public struct RadarSplashModifier: ViewModifier {
    public init() {}
    public func body(content: Content) -> some View {
        content
            .background(RadarSplashInjector())
    }
}

public extension View {
    func radarSplash() -> some View { self.modifier(RadarSplashModifier()) }
}

/// Um UIViewController invisível que injeta a overlay quando aparece.
private struct RadarSplashInjector: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> SplashHostController {
        let vc = SplashHostController()
        vc.view.backgroundColor = .clear
        return vc
    }

    func updateUIViewController(_ uiViewController: SplashHostController, context: Context) {}

    final class SplashHostController: UIViewController {
        private var hasShown = false

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard !hasShown else { return }
            hasShown = true
            RadarSplashPresenter.show(on: view)
        }
    }
}

public final class RadarSplashPresenter {
    private static var hasShownThisSession = false

    /// Chame uma vez (ex.: no .onAppear do primeiro view) se preferir controle manual.
    public static func show(on view: UIView) {
        guard !hasShownThisSession else { return }
        hasShownThisSession = true

        let hostView: UIView
        if let window = view.window ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) {
            hostView = window
        } else {
            hostView = view
        }

        guard !hostView.subviews.contains(where: { $0 is RadarSplashOverlay }) else { return }

        let splash = RadarSplashOverlay(frame: hostView.bounds)
        splash.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        splash.isUserInteractionEnabled = false
        hostView.addSubview(splash)
        splash.play()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if splash.superview != nil {
                splash.removeFromSuperview()
            }
        }
    }
}
