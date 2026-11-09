import Foundation
import UIKit
import TelegramCore

private func alfaColor(_ rgb: UInt32, alpha: CGFloat = 1.0) -> UIColor {
    return UIColor(red: CGFloat((rgb >> 16) & 0xff) / 255.0, green: CGFloat((rgb >> 8) & 0xff) / 255.0, blue: CGFloat(rgb & 0xff) / 255.0, alpha: alpha)
}

/// AlfaGram: the opening animation. The logo is "drawn" (~1 s): the square, the "A" (left leg, right leg), the
/// plane, then the whole logo lights up.
/// - The app ready earlier: the rest is drawn ~5× faster (≈0.2 s), then the screen opens.
/// - The app ready later: when drawn, the logo "breathes" (a pulsing ring) until it is ready.
/// Never longer than 3.5 s. Skipped when the system "Reduce Motion" is on.
public final class AlfaSplashOverlay: UIView {
    private static weak var current: AlfaSplashOverlay?
    private static var shown = false

    /// AppDelegate, right after the window is created (cold start only).
    public static func show(in window: UIWindow) {
        if shown {
            return
        }
        shown = true
        if UIAccessibility.isReduceMotionEnabled {
            return
        }
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

    private static let drawDuration: CFTimeInterval = 1.0
    private static let speedUp: Float = 5.0
    private static let maxDuration: TimeInterval = 3.5

    private let contentLayer = CALayer()
    private let logoLayer = CALayer()
    private var startTime: CFTimeInterval = 0
    private var isReady = false
    private var drawFinished = false
    private var exiting = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = alfaColor(0x0b0f1a)
        self.isUserInteractionEnabled = true
        self.layer.addSublayer(self.contentLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.contentLayer.frame = self.bounds
        self.logoLayer.position = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
        CATransaction.commit()
    }

    private static func image(_ base64: String) -> CGImage? {
        guard let data = Data(base64Encoded: base64), let image = UIImage(data: data) else {
            return nil
        }
        return image.cgImage
    }

    private static func linePath(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ u: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: x1 * u, y: y1 * u))
        path.addLine(to: CGPoint(x: x2 * u, y: y2 * u))
        return path
    }

    private func start() {
        let size = min(124.0, min(self.bounds.width, self.bounds.height) * 0.42)
        let u = size / 100.0
        let radius = size * 0.21
        let bounds = CGRect(x: 0.0, y: 0.0, width: size, height: size)

        self.contentLayer.frame = self.bounds
        self.logoLayer.bounds = bounds
        self.logoLayer.position = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
        self.contentLayer.addSublayer(self.logoLayer)

        let base = self.contentLayer.convertTime(CACurrentMediaTime(), from: nil)
        self.startTime = CACurrentMediaTime()
        let ease = CAMediaTimingFunction(controlPoints: 0.45, 0.0, 0.35, 1.0)

        // 1) the square
        let square = CAShapeLayer()
        square.frame = bounds
        square.path = UIBezierPath(roundedRect: bounds, cornerRadius: radius).cgPath
        square.fillColor = alfaColor(0x020a2e).cgColor
        square.strokeColor = alfaColor(0x2f6bff).cgColor
        square.lineWidth = 1.4 * u
        self.logoLayer.addSublayer(square)
        let squareOpacity = CABasicAnimation(keyPath: "opacity")
        squareOpacity.fromValue = 0.0
        squareOpacity.toValue = 1.0
        let squareScale = CABasicAnimation(keyPath: "transform.scale")
        squareScale.fromValue = 0.86
        squareScale.toValue = 1.0
        let squareGroup = CAAnimationGroup()
        squareGroup.animations = [squareOpacity, squareScale]
        squareGroup.beginTime = base
        squareGroup.duration = 0.22
        squareGroup.timingFunction = CAMediaTimingFunction(name: .easeOut)
        squareGroup.fillMode = .backwards
        square.add(squareGroup, forKey: "appear")

        // 2) the "A" and the plane, revealed along their strokes
        let clip = CALayer()
        clip.frame = bounds
        clip.cornerRadius = radius
        clip.masksToBounds = true
        self.logoLayer.addSublayer(clip)

        typealias Segment = (path: UIBezierPath, start: CFTimeInterval, end: CFTimeInterval, width: CGFloat)
        let plane = UIBezierPath()
        plane.move(to: CGPoint(x: 8.0 * u, y: 82.0 * u))
        plane.addQuadCurve(to: CGPoint(x: 90.0 * u, y: 31.0 * u), controlPoint: CGPoint(x: 40.0 * u, y: 54.0 * u))
        let segmentsA: [Segment] = [
            (AlfaSplashOverlay.linePath(20, 64, 50, 13, u), 0.12, 0.34, 26.0),
            (AlfaSplashOverlay.linePath(50, 13, 86, 86, u), 0.32, 0.56, 28.0)
        ]
        let segmentsP: [Segment] = [
            (plane, 0.54, 0.82, 26.0),
            (AlfaSplashOverlay.linePath(86, 33, 57, 76, u), 0.79, 0.93, 20.0)
        ]

        func addRevealed(_ base64: String, _ segments: [Segment]) {
            let imageLayer = CALayer()
            imageLayer.frame = bounds
            imageLayer.contents = AlfaSplashOverlay.image(base64)
            imageLayer.contentsGravity = .resizeAspectFill
            let mask = CALayer()
            mask.frame = bounds
            for segment in segments {
                let stroke = CAShapeLayer()
                stroke.frame = bounds
                stroke.path = segment.path.cgPath
                stroke.strokeColor = UIColor.white.cgColor
                stroke.fillColor = nil
                stroke.lineWidth = segment.width * u
                stroke.lineCap = .round
                stroke.strokeEnd = 1.0
                let draw = CABasicAnimation(keyPath: "strokeEnd")
                draw.fromValue = 0.0
                draw.toValue = 1.0
                draw.beginTime = base + segment.start
                draw.duration = segment.end - segment.start
                draw.timingFunction = ease
                draw.fillMode = .backwards
                stroke.add(draw, forKey: "draw")
                mask.addSublayer(stroke)

                // the pen tip
                let tip = CAShapeLayer()
                let tipRadius = 1.8 * u
                tip.path = UIBezierPath(ovalIn: CGRect(x: -tipRadius, y: -tipRadius, width: tipRadius * 2.0, height: tipRadius * 2.0)).cgPath
                tip.fillColor = UIColor.white.cgColor
                tip.opacity = 0.0
                self.logoLayer.addSublayer(tip)
                let move = CAKeyframeAnimation(keyPath: "position")
                move.path = segment.path.cgPath
                move.calculationMode = .paced
                let fade = CAKeyframeAnimation(keyPath: "opacity")
                fade.values = [0.0, 0.9, 0.9, 0.0]
                fade.keyTimes = [0.0, 0.1, 0.9, 1.0]
                let tipGroup = CAAnimationGroup()
                tipGroup.animations = [move, fade]
                tipGroup.beginTime = base + segment.start
                tipGroup.duration = segment.end - segment.start
                tipGroup.timingFunction = ease
                tip.add(tipGroup, forKey: "tip")
            }
            imageLayer.mask = mask
            clip.addSublayer(imageLayer)
        }
        addRevealed(AlfaSplashImages.letterA, segmentsA)
        addRevealed(AlfaSplashImages.plane, segmentsP)

        // 3) the whole logo
        let full = CALayer()
        full.frame = bounds
        full.contents = AlfaSplashOverlay.image(AlfaSplashImages.full)
        full.contentsGravity = .resizeAspectFill
        clip.addSublayer(full)
        let fullOpacity = CABasicAnimation(keyPath: "opacity")
        fullOpacity.fromValue = 0.0
        fullOpacity.toValue = 1.0
        fullOpacity.beginTime = base + 0.88
        fullOpacity.duration = 0.12
        fullOpacity.fillMode = .backwards
        full.add(fullOpacity, forKey: "appear")

        DispatchQueue.main.asyncAfter(deadline: .now() + AlfaSplashOverlay.drawDuration, execute: { [weak self] in
            guard let self = self, !self.exiting else {
                return
            }
            self.drawFinished = true
            if self.isReady {
                self.finish()
            } else {
                self.startBreathing()
            }
        })
        DispatchQueue.main.asyncAfter(deadline: .now() + AlfaSplashOverlay.maxDuration, execute: { [weak self] in
            self?.finish()
        })
    }

    private func startBreathing() {
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
        if self.isReady || self.exiting {
            return
        }
        self.isReady = true
        if self.drawFinished {
            self.finish()
            return
        }
        // the rest of the drawing, ~5× faster
        let now = CACurrentMediaTime()
        let elapsed = now - self.startTime
        let local = self.contentLayer.convertTime(now, from: nil)
        self.contentLayer.timeOffset = local
        self.contentLayer.beginTime = now
        self.contentLayer.speed = AlfaSplashOverlay.speedUp
        let remaining = max(0.0, AlfaSplashOverlay.drawDuration - elapsed) / Double(AlfaSplashOverlay.speedUp)
        DispatchQueue.main.asyncAfter(deadline: .now() + remaining + 0.03, execute: { [weak self] in
            self?.finish()
        })
    }

    private func finish() {
        if self.exiting {
            return
        }
        self.exiting = true
        self.superview?.bringSubviewToFront(self)
        let zoom = CABasicAnimation(keyPath: "transform.scale")
        zoom.fromValue = 1.0
        zoom.toValue = 1.12
        zoom.duration = 0.24
        zoom.fillMode = .forwards
        zoom.isRemovedOnCompletion = false
        self.logoLayer.add(zoom, forKey: "exit")
        UIView.animate(withDuration: 0.24, delay: 0.0, options: [.curveEaseIn], animations: {
            self.alpha = 0.0
        }, completion: { _ in
            self.removeFromSuperview()
        })
    }
}
