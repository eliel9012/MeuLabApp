import UIKit

/// Overlay animado estilo "radar sweep" baseado no seu ícone.
/// Observação: o LaunchScreen.storyboard do iOS NÃO pode ser animado.
/// Use isto por cima da primeira tela do app (logo após abrir).
final class RadarSplashOverlay: UIView {
    private enum Palette {
        static let backgroundTop = UIColor(red: 0.06, green: 0.17, blue: 0.44, alpha: 1.0)
        static let backgroundMid = UIColor(red: 0.03, green: 0.08, blue: 0.21, alpha: 1.0)
        static let backgroundBottom = UIColor(red: 0.01, green: 0.03, blue: 0.10, alpha: 1.0)
        static let signal = UIColor(red: 0.42, green: 1.00, blue: 0.56, alpha: 1.0)
        static let signalSoft = UIColor(red: 0.67, green: 1.00, blue: 0.76, alpha: 1.0)
        static let signalGlow = UIColor(red: 0.23, green: 0.96, blue: 0.45, alpha: 1.0)
        static let warmBlip = UIColor(red: 1.00, green: 0.98, blue: 0.62, alpha: 1.0)
        static let plateFill = UIColor.white.withAlphaComponent(0.035)
    }

    private let backgroundGradient = CAGradientLayer()
    private let ambientGlowLayer = CAGradientLayer()
    private let logoHaloLayer = CAGradientLayer()
    private let logoPlateLayer = CAShapeLayer()
    private let outerRingLayer = CAShapeLayer()
    private let innerRingLayer = CAShapeLayer()
    private let sweepContainerLayer = CALayer()
    private let sweepGlowLayer = CAShapeLayer()
    private let sweepBeamLayer = CAShapeLayer()
    private let gridRingLayers = (0..<4).map { _ in CAShapeLayer() }
    private let spokeLayers = (0..<4).map { _ in CAShapeLayer() }
    private let pulseLayers = (0..<2).map { _ in CAShapeLayer() }
    private let blipLayers = (0..<4).map { _ in CAShapeLayer() }
    private let logoContainer = UIView()
    private let logo = UIImageView(image: UIImage(named: "SplashLogo"))
    private var hasPlayed = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = true
        backgroundColor = Palette.backgroundBottom
        isUserInteractionEnabled = false

        configureLayers()
        configureLogo()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radarRadius = min(bounds.width, bounds.height) * 0.29
        let logoSize = min(min(bounds.width, bounds.height) * 0.42, 240)
        let plateInset = max(18, logoSize * 0.08)
        let plateFrame = CGRect(
            x: center.x - (logoSize / 2) - plateInset,
            y: center.y - (logoSize / 2) - plateInset,
            width: logoSize + (plateInset * 2),
            height: logoSize + (plateInset * 2)
        )
        let ringRadii: [CGFloat] = [1.02, 0.82, 0.62, 0.42].map { radarRadius * $0 }
        let crosshairLength = radarRadius * 2.45
        let beamWidth = max(8, radarRadius * 0.05)

        backgroundGradient.frame = bounds

        let ambientSize = radarRadius * 2.9
        ambientGlowLayer.frame = CGRect(
            x: center.x - ambientSize / 2,
            y: center.y - ambientSize / 2,
            width: ambientSize,
            height: ambientSize
        )

        let haloSize = plateFrame.width * 1.22
        logoHaloLayer.frame = CGRect(
            x: center.x - haloSize / 2,
            y: center.y - haloSize / 2,
            width: haloSize,
            height: haloSize
        )

        logoPlateLayer.frame = bounds
        logoPlateLayer.path = UIBezierPath(
            roundedRect: plateFrame,
            cornerRadius: plateFrame.width * 0.22
        ).cgPath

        outerRingLayer.frame = bounds
        outerRingLayer.path = UIBezierPath(
            arcCenter: center,
            radius: ringRadii[0],
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: true
        ).cgPath

        innerRingLayer.frame = bounds
        innerRingLayer.path = UIBezierPath(
            arcCenter: center,
            radius: ringRadii[2],
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: true
        ).cgPath

        for (index, ringLayer) in gridRingLayers.enumerated() {
            ringLayer.frame = bounds
            ringLayer.path = UIBezierPath(
                arcCenter: center,
                radius: ringRadii[index],
                startAngle: 0,
                endAngle: .pi * 2,
                clockwise: true
            ).cgPath
        }

        let spokeAngles: [CGFloat] = [0, .pi / 2, .pi / 4, (.pi * 3) / 4]
        for (spokeLayer, angle) in zip(spokeLayers, spokeAngles) {
            let dx = cos(angle) * crosshairLength / 2
            let dy = sin(angle) * crosshairLength / 2
            let path = UIBezierPath()
            path.move(to: CGPoint(x: center.x - dx, y: center.y - dy))
            path.addLine(to: CGPoint(x: center.x + dx, y: center.y + dy))
            spokeLayer.frame = bounds
            spokeLayer.path = path.cgPath
        }

        for pulseLayer in pulseLayers {
            pulseLayer.frame = bounds
            pulseLayer.path = UIBezierPath(
                arcCenter: center,
                radius: ringRadii[2],
                startAngle: 0,
                endAngle: .pi * 2,
                clockwise: true
            ).cgPath
        }

        let blips: [(distance: CGFloat, angle: CGFloat, size: CGFloat)] = [
            (0.38, .pi * 0.92, 12),
            (0.56, .pi * 1.53, 10),
            (0.79, .pi * 0.24, 14),
            (0.62, .pi * 1.18, 9),
        ]

        for (layer, blip) in zip(blipLayers, blips) {
            let point = CGPoint(
                x: center.x + cos(blip.angle) * radarRadius * blip.distance,
                y: center.y + sin(blip.angle) * radarRadius * blip.distance
            )
            let rect = CGRect(
                x: point.x - blip.size / 2,
                y: point.y - blip.size / 2,
                width: blip.size,
                height: blip.size
            )
            layer.frame = bounds
            layer.path = UIBezierPath(ovalIn: rect).cgPath
        }

        let sweepPath = UIBezierPath()
        sweepPath.move(to: center)
        sweepPath.addArc(
            withCenter: center,
            radius: radarRadius * 1.04,
            startAngle: -0.34,
            endAngle: 0.18,
            clockwise: true
        )
        sweepPath.close()

        let beamPath = UIBezierPath()
        beamPath.move(to: center)
        beamPath.addLine(to: CGPoint(x: center.x + radarRadius * 0.93, y: center.y + radarRadius * 0.1))

        sweepContainerLayer.frame = bounds
        sweepGlowLayer.frame = bounds
        sweepGlowLayer.path = sweepPath.cgPath
        sweepBeamLayer.frame = bounds
        sweepBeamLayer.path = beamPath.cgPath
        sweepBeamLayer.lineWidth = beamWidth

        logoContainer.frame = CGRect(
            x: center.x - logoSize / 2,
            y: center.y - logoSize / 2,
            width: logoSize,
            height: logoSize
        )
        logo.frame = logoContainer.bounds
        logoContainer.layer.shadowPath = UIBezierPath(
            roundedRect: logoContainer.bounds,
            cornerRadius: logoContainer.bounds.width * 0.22
        ).cgPath
    }

    func play(completion: (() -> Void)? = nil) {
        guard !hasPlayed else { return }
        hasPlayed = true
        layoutIfNeeded()

        alpha = 1
        logoContainer.alpha = 0
        logoContainer.transform = CGAffineTransform(translationX: 0, y: 12).scaledBy(x: 0.9, y: 0.9)

        animateSweep()
        animatePulseRings()
        animateBlips()
        animateAmbientGlow()

        UIView.animate(
            withDuration: 0.62,
            delay: 0.04,
            usingSpringWithDamping: 0.82,
            initialSpringVelocity: 0.55,
            options: [.curveEaseOut, .allowUserInteraction]
        ) {
            self.logoContainer.alpha = 1
            self.logoContainer.transform = .identity
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.95) {
            UIView.animate(withDuration: 0.4, delay: 0, options: [.curveEaseInOut]) {
                self.alpha = 0
                self.logoContainer.transform = CGAffineTransform(translationX: 0, y: -8).scaledBy(x: 1.03, y: 1.03)
            } completion: { _ in
                self.removeFromSuperview()
                completion?()
            }
        }
    }

    private func configureLayers() {
        backgroundGradient.colors = [
            Palette.backgroundTop.cgColor,
            Palette.backgroundMid.cgColor,
            Palette.backgroundBottom.cgColor,
        ]
        backgroundGradient.locations = [0.0, 0.46, 1.0]
        backgroundGradient.startPoint = CGPoint(x: 0.12, y: 0.0)
        backgroundGradient.endPoint = CGPoint(x: 0.88, y: 1.0)
        layer.addSublayer(backgroundGradient)

        ambientGlowLayer.type = .radial
        ambientGlowLayer.colors = [
            Palette.signalGlow.withAlphaComponent(0.24).cgColor,
            Palette.signalGlow.withAlphaComponent(0.0).cgColor,
        ]
        ambientGlowLayer.locations = [0.0, 1.0]
        ambientGlowLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        ambientGlowLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        ambientGlowLayer.opacity = 0.8
        layer.addSublayer(ambientGlowLayer)

        logoHaloLayer.type = .radial
        logoHaloLayer.colors = [
            UIColor.white.withAlphaComponent(0.16).cgColor,
            Palette.signalGlow.withAlphaComponent(0.0).cgColor,
        ]
        logoHaloLayer.locations = [0.0, 1.0]
        logoHaloLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        logoHaloLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        logoHaloLayer.opacity = 0.9
        layer.addSublayer(logoHaloLayer)

        logoPlateLayer.fillColor = Palette.plateFill.cgColor
        logoPlateLayer.strokeColor = Palette.signal.withAlphaComponent(0.15).cgColor
        logoPlateLayer.lineWidth = 1.2
        layer.addSublayer(logoPlateLayer)

        spokeLayers.forEach { spokeLayer in
            spokeLayer.fillColor = UIColor.clear.cgColor
            spokeLayer.strokeColor = Palette.signalSoft.withAlphaComponent(0.09).cgColor
            spokeLayer.lineWidth = 1.0
            layer.addSublayer(spokeLayer)
        }

        for (index, ringLayer) in gridRingLayers.enumerated() {
            ringLayer.fillColor = UIColor.clear.cgColor
            ringLayer.strokeColor = Palette.signalSoft.withAlphaComponent(index == 0 ? 0.22 : 0.12).cgColor
            ringLayer.lineWidth = index == 0 ? 2.2 : 1.0
            layer.addSublayer(ringLayer)
        }

        outerRingLayer.fillColor = UIColor.clear.cgColor
        outerRingLayer.strokeColor = Palette.signal.withAlphaComponent(0.34).cgColor
        outerRingLayer.lineWidth = 2.2
        layer.addSublayer(outerRingLayer)

        innerRingLayer.fillColor = UIColor.clear.cgColor
        innerRingLayer.strokeColor = Palette.signal.withAlphaComponent(0.15).cgColor
        innerRingLayer.lineWidth = 1.2
        layer.addSublayer(innerRingLayer)

        pulseLayers.forEach { pulseLayer in
            pulseLayer.fillColor = UIColor.clear.cgColor
            pulseLayer.strokeColor = Palette.signal.withAlphaComponent(0.18).cgColor
            pulseLayer.lineWidth = 2.0
            pulseLayer.opacity = 0
            layer.addSublayer(pulseLayer)
        }

        blipLayers.forEach { blipLayer in
            blipLayer.fillColor = Palette.warmBlip.cgColor
            blipLayer.shadowColor = Palette.warmBlip.cgColor
            blipLayer.shadowRadius = 16
            blipLayer.shadowOpacity = 0.9
            blipLayer.shadowOffset = .zero
            blipLayer.opacity = 0.82
            layer.addSublayer(blipLayer)
        }

        sweepGlowLayer.fillColor = Palette.signal.withAlphaComponent(0.2).cgColor
        sweepGlowLayer.shadowColor = Palette.signal.cgColor
        sweepGlowLayer.shadowRadius = 24
        sweepGlowLayer.shadowOpacity = 0.78
        sweepGlowLayer.shadowOffset = .zero
        sweepContainerLayer.addSublayer(sweepGlowLayer)

        sweepBeamLayer.fillColor = UIColor.clear.cgColor
        sweepBeamLayer.strokeColor = UIColor.white.withAlphaComponent(0.9).cgColor
        sweepBeamLayer.lineCap = .round
        sweepBeamLayer.shadowColor = Palette.signal.cgColor
        sweepBeamLayer.shadowRadius = 12
        sweepBeamLayer.shadowOpacity = 0.6
        sweepBeamLayer.shadowOffset = .zero
        sweepContainerLayer.addSublayer(sweepBeamLayer)
        layer.addSublayer(sweepContainerLayer)
    }

    private func configureLogo() {
        logo.contentMode = .scaleAspectFit
        logoContainer.layer.shadowColor = Palette.signal.cgColor
        logoContainer.layer.shadowRadius = 34
        logoContainer.layer.shadowOpacity = 0.45
        logoContainer.layer.shadowOffset = CGSize(width: 0, height: 14)
        logoContainer.addSubview(logo)
        addSubview(logoContainer)
    }

    private func animateSweep() {
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = -0.12
        rotation.toValue = CGFloat.pi * 2 * 1.8
        rotation.duration = 1.85
        rotation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        sweepContainerLayer.add(rotation, forKey: "radarRotation")
    }

    private func animateAmbientGlow() {
        let glowPulse = CABasicAnimation(keyPath: "opacity")
        glowPulse.fromValue = 0.65
        glowPulse.toValue = 0.95
        glowPulse.duration = 0.82
        glowPulse.autoreverses = true
        glowPulse.repeatCount = 2
        ambientGlowLayer.add(glowPulse, forKey: "glowPulse")

        let haloPulse = CABasicAnimation(keyPath: "opacity")
        haloPulse.fromValue = 0.3
        haloPulse.toValue = 0.95
        haloPulse.duration = 0.48
        haloPulse.timingFunction = CAMediaTimingFunction(name: .easeOut)
        logoHaloLayer.add(haloPulse, forKey: "haloReveal")
    }

    private func animatePulseRings() {
        let now = CACurrentMediaTime()

        for (index, pulseLayer) in pulseLayers.enumerated() {
            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = 0.82
            scale.toValue = 1.18

            let opacity = CABasicAnimation(keyPath: "opacity")
            opacity.fromValue = 0.48
            opacity.toValue = 0.0

            let group = CAAnimationGroup()
            group.animations = [scale, opacity]
            group.duration = 1.1
            group.beginTime = now + (Double(index) * 0.18)
            group.repeatCount = 2
            group.timingFunction = CAMediaTimingFunction(name: .easeOut)
            pulseLayer.add(group, forKey: "pulse")
        }
    }

    private func animateBlips() {
        let now = CACurrentMediaTime()

        for (index, blipLayer) in blipLayers.enumerated() {
            let shimmer = CAKeyframeAnimation(keyPath: "opacity")
            shimmer.values = [0.24, 1.0, 0.36, 0.82]
            shimmer.keyTimes = [0.0, 0.32, 0.7, 1.0]
            shimmer.duration = 0.68
            shimmer.beginTime = now + (Double(index) * 0.16)
            shimmer.repeatCount = 2
            shimmer.timingFunctions = [
                CAMediaTimingFunction(name: .easeOut),
                CAMediaTimingFunction(name: .easeInEaseOut),
                CAMediaTimingFunction(name: .easeIn),
            ]
            blipLayer.add(shimmer, forKey: "shimmer")
        }
    }
}
