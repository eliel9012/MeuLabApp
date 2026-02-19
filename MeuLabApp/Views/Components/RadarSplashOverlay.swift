import UIKit

/// Overlay animado estilo "radar sweep" baseado no seu ícone.
/// Observação: o LaunchScreen.storyboard do iOS NÃO pode ser animado.
/// Use isto por cima da primeira tela do app (logo após abrir).
final class RadarSplashOverlay: UIView {

    private let logo = UIImageView(image: UIImage(named: "SplashLogo"))
    private let sweepLayer = CAShapeLayer()
    private let ringLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = true
        backgroundColor = UIColor(red: 0.035, green: 0.086, blue: 0.365, alpha: 1.0)

        logo.contentMode = .scaleAspectFit
        logo.translatesAutoresizingMaskIntoConstraints = false
        addSubview(logo)

        NSLayoutConstraint.activate([
            logo.centerXAnchor.constraint(equalTo: centerXAnchor),
            logo.centerYAnchor.constraint(equalTo: centerYAnchor),
            logo.widthAnchor.constraint(equalToConstant: 220),
            logo.heightAnchor.constraint(equalToConstant: 220),
        ])

        layer.addSublayer(ringLayer)
        layer.addSublayer(sweepLayer)

        ringLayer.fillColor = UIColor.clear.cgColor
        ringLayer.strokeColor = UIColor.white.withAlphaComponent(0.12).cgColor
        ringLayer.lineWidth = 2

        sweepLayer.fillColor = UIColor(red: 0.30, green: 1.00, blue: 0.40, alpha: 0.22).cgColor
        sweepLayer.shadowColor = UIColor(red: 0.30, green: 1.00, blue: 0.40, alpha: 1.00).cgColor
        sweepLayer.shadowRadius = 10
        sweepLayer.shadowOpacity = 0.6
        sweepLayer.shadowOffset = .zero
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius: CGFloat = 120

        let ringPath = UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        ringLayer.path = ringPath.cgPath

        let halfAngle: CGFloat = .pi / 18 // ~10°
        let start: CGFloat = -halfAngle
        let end: CGFloat = halfAngle

        let wedge = UIBezierPath()
        wedge.move(to: center)
        wedge.addArc(withCenter: center, radius: radius, startAngle: start, endAngle: end, clockwise: true)
        wedge.close()

        sweepLayer.path = wedge.cgPath
        sweepLayer.bounds = bounds
        sweepLayer.position = .zero

        // máscara circular para o sweep não vazar
        let mask = CAShapeLayer()
        mask.path = ringPath.cgPath
        sweepLayer.mask = mask
    }

    func play(completion: (() -> Void)? = nil) {
        let duration: TimeInterval = 1.0 // por ciclo
        let cycles: Double = 2.0
        
        let rot = CABasicAnimation(keyPath: "transform.rotation.z")
        rot.fromValue = 0
        rot.toValue = CGFloat.pi * 2 * cycles
        rot.duration = duration * cycles
        rot.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        sweepLayer.add(rot, forKey: "rot")

        UIView.animate(withDuration: 0.5, delay: duration * cycles - 0.25, options: [.curveEaseInOut], animations: {
            self.alpha = 0
        }, completion: { _ in
            self.removeFromSuperview()
            completion?()
        })
    }
}
