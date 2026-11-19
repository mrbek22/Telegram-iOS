import Foundation
import UIKit
import TelegramCore

private func alfaColor(_ rgb: UInt32, alpha: CGFloat = 1.0) -> UIColor {
    return UIColor(red: CGFloat((rgb >> 16) & 0xff) / 255.0, green: CGFloat((rgb >> 8) & 0xff) / 255.0, blue: CGFloat(rgb & 0xff) / 255.0, alpha: alpha)
}

/// AlfaGram: the opening screen. It continues the system launch screen (LaunchScreen.xib: the same dark background
/// and the same 124 pt logo in the centre), so the logo is visible from the very first moment and stays in place
/// while the app loads — a soft pulse when loading takes a while — then zooms slightly and fades into the app.
/// The overlay keeps itself on top of everything the app adds to the window until it leaves.
/// Never longer than 4 s.
public final class AlfaSplashOverlay: UIView {
    private static weak var current: AlfaSplashOverlay?
    private static var shown = false

    /// AppDelegate, right after the window is created (cold start only).
    public static func show(in window: UIWindow) {
        if shown {
            return
        }
        shown = true
        let overlay = AlfaSplashOverlay(frame: window.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(overlay)
        current = overlay
        overlay.start()
    }

    /// The main screen (or the login screen) is ready.
    public static func setReady() {
        current?.markReady()
    }

    /// The same size as the logo of LaunchScreen.xib.
    private static let logoSize: CGFloat = 124.0
    /// Shown at least this long, so the hand-off from the launch screen never flickers.
    private static let minDuration: CFTimeInterval = 0.35
    /// Loading longer than this starts the pulse.
    private static let pulseDelay: TimeInterval = 0.9
    private static let maxDuration: TimeInterval = 4.0

    private let logoLayer = CALayer()
    private var startTime: CFTimeInterval = 0
    private var exiting = false
    private var displayLink: CADisplayLink?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = alfaColor(0x0b0f1a)
        self.isUserInteractionEnabled = true
        self.layer.addSublayer(self.logoLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.logoLayer.position = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
        CATransaction.commit()
    }

    private static func image(_ base64: String) -> CGImage? {
        guard let data = Data(base64Encoded: base64), let image = UIImage(data: data) else {
            return nil
        }
        return image.cgImage
    }

    private func start() {
        let size = AlfaSplashOverlay.logoSize
        let bounds = CGRect(x: 0.0, y: 0.0, width: size, height: size)
        self.startTime = CACurrentMediaTime()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.logoLayer.bounds = bounds
        self.logoLayer.position = CGPoint(x: self.bounds.midX, y: self.bounds.midY)

        let clip = CALayer()
        clip.frame = bounds
        clip.cornerRadius = size * 0.21
        if #available(iOS 13.0, *) {
            clip.cornerCurve = .continuous
        }
        clip.masksToBounds = true
        clip.contents = AlfaSplashOverlay.image(AlfaSplashImages.full)
        clip.contentsGravity = .resizeAspectFill
        self.logoLayer.addSublayer(clip)
        CATransaction.commit()

        // Whatever the app adds to the window later stays below the overlay.
        let displayLink = CADisplayLink(target: AlfaSplashDisplayLinkTarget(self), selector: #selector(AlfaSplashDisplayLinkTarget.tick))
        displayLink.add(to: .main, forMode: .common)
        self.displayLink = displayLink

        DispatchQueue.main.asyncAfter(deadline: .now() + AlfaSplashOverlay.pulseDelay, execute: { [weak self] in
            guard let self = self, !self.exiting else {
                return
            }
            self.startPulse()
        })
        DispatchQueue.main.asyncAfter(deadline: .now() + AlfaSplashOverlay.maxDuration, execute: { [weak self] in
            self?.finish()
        })
    }

    fileprivate func keepOnTop() {
        guard let superview = self.superview else {
            return
        }
        if superview.subviews.last !== self {
            superview.bringSubviewToFront(self)
        }
    }

    private func startPulse() {
        if UIAccessibility.isReduceMotionEnabled {
            return
        }
        let size = self.logoLayer.bounds.width
        let breath = CABasicAnimation(keyPath: "transform.scale")
        breath.fromValue = 1.0
        breath.toValue = 1.03
        breath.duration = 0.55
        breath.autoreverses = true
        breath.repeatCount = .infinity
        breath.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        self.logoLayer.add(breath, forKey: "breath")

        let ring = CAShapeLayer()
        ring.frame = self.logoLayer.bounds
        ring.path = UIBezierPath(roundedRect: self.logoLayer.bounds, cornerRadius: size * 0.21).cgPath
        ring.fillColor = nil
        ring.strokeColor = alfaColor(0x4f9dff).cgColor
        ring.lineWidth = 2.0 * size / 100.0
        ring.opacity = 0.0
        self.logoLayer.insertSublayer(ring, at: 0)
        let ringScale = CABasicAnimation(keyPath: "transform.scale")
        ringScale.fromValue = 1.0
        ringScale.toValue = 1.28
        let ringOpacity = CABasicAnimation(keyPath: "opacity")
        ringOpacity.fromValue = 0.8
        ringOpacity.toValue = 0.0
        let ringGroup = CAAnimationGroup()
        ringGroup.animations = [ringScale, ringOpacity]
        ringGroup.duration = 1.1
        ringGroup.repeatCount = .infinity
        ring.add(ringGroup, forKey: "ring")
    }

    private func markReady() {
        if self.exiting {
            return
        }
        let elapsed = CACurrentMediaTime() - self.startTime
        let wait = max(0.0, AlfaSplashOverlay.minDuration - elapsed)
        DispatchQueue.main.asyncAfter(deadline: .now() + wait, execute: { [weak self] in
            self?.finish()
        })
    }

    private func finish() {
        if self.exiting {
            return
        }
        self.exiting = true
        self.keepOnTop()
        if !UIAccessibility.isReduceMotionEnabled {
            let zoom = CABasicAnimation(keyPath: "transform.scale")
            zoom.fromValue = (self.logoLayer.presentation()?.value(forKeyPath: "transform.scale") as? NSNumber)?.doubleValue ?? 1.0
            zoom.toValue = 1.12
            zoom.duration = 0.28
            zoom.fillMode = .forwards
            zoom.isRemovedOnCompletion = false
            self.logoLayer.removeAnimation(forKey: "breath")
            self.logoLayer.add(zoom, forKey: "exit")
        }
        UIView.animate(withDuration: 0.28, delay: 0.0, options: [.curveEaseIn], animations: {
            self.alpha = 0.0
        }, completion: { _ in
            self.displayLink?.invalidate()
            self.displayLink = nil
            self.removeFromSuperview()
        })
    }
}

/// CADisplayLink retains its target: a weak hop, so the overlay is released when it leaves.
private final class AlfaSplashDisplayLinkTarget: NSObject {
    private weak var overlay: AlfaSplashOverlay?

    init(_ overlay: AlfaSplashOverlay) {
        self.overlay = overlay
    }

    @objc func tick() {
        self.overlay?.keepOnTop()
    }
}
