import Foundation
import UIKit
import StoreKit
import TelegramCore

private func alfaColor(_ rgb: UInt32) -> UIColor {
    return UIColor(red: CGFloat((rgb >> 16) & 0xff) / 255.0, green: CGFloat((rgb >> 8) & 0xff) / 255.0, blue: CGFloat(rgb & 0xff) / 255.0, alpha: 1.0)
}

/// AlfaGram: three slides shown once — Ghost mode, nothing is lost, link protection. Each with a moving emoji.
public final class AlfaOnboardingController: UIViewController {
    private static let shownKey = "onboardingV1"

    private struct Slide {
        let emoji: String
        let title: String
        let text: String
    }

    private let slides: [Slide] = [
        Slide(emoji: "👻", title: "Ghost rejim", text: "Onlayn ko'rinmasdan o'qing: «yozyapti» va «o'qildi» belgilari yuborilmaydi, story'larni anonim ko'ring. Sozlamalar → AlfaGram."),
        Slide(emoji: "🗑", title: "Hech narsa yo'qolmaydi", text: "Suhbatdoshingiz xabarni o'chirsa ham, u sizda 🗑 belgisi bilan qoladi. Tahrirlangan xabarning eski matnini ko'rish uchun xabarni bosib turing."),
        Slide(emoji: "🛡", title: "Havola himoyasi", text: "Soxta bank, Click, Payme yoki Telegram saytlari va «sovg'a» va'da qiluvchi havolalarni ochishdan oldin ogohlantiramiz. Hammasi faqat telefoningizda ishlaydi.")
    ]

    private var page = 0
    private let emojiLabel = UILabel()
    private let titleLabel = UILabel()
    private let textLabel = UILabel()
    private let pageControl = UIPageControl()
    private let button = UIButton(type: .system)
    private let content = UIView()

    /// Shown once per install, over the main screen.
    public static func presentIfNeeded(window: UIWindow?) {
        if AlfaSettings.flag(shownKey) {
            return
        }
        guard let root = window?.rootViewController else {
            return
        }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        AlfaSettings.setFlag(shownKey, true)
        let controller = AlfaOnboardingController()
        if #available(iOS 15.0, *), let sheet = controller.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        top.present(controller, animated: true, completion: nil)
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.systemBackground

        self.content.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.content)

        self.emojiLabel.font = UIFont.systemFont(ofSize: 76.0)
        self.emojiLabel.textAlignment = .center
        self.titleLabel.font = UIFont.boldSystemFont(ofSize: 22.0)
        self.titleLabel.textAlignment = .center
        self.titleLabel.textColor = UIColor.label
        self.textLabel.font = UIFont.systemFont(ofSize: 15.0)
        self.textLabel.textAlignment = .center
        self.textLabel.textColor = UIColor.secondaryLabel
        self.textLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [self.emojiLabel, self.titleLabel, self.textLabel])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 10.0
        stack.setCustomSpacing(14.0, after: self.emojiLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        self.content.addSubview(stack)

        self.pageControl.numberOfPages = self.slides.count
        self.pageControl.currentPageIndicatorTintColor = alfaColor(0x2563eb)
        self.pageControl.pageIndicatorTintColor = UIColor.tertiaryLabel
        self.pageControl.isUserInteractionEnabled = false
        self.pageControl.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.pageControl)

        self.button.backgroundColor = alfaColor(0x2563eb)
        self.button.setTitleColor(UIColor.white, for: .normal)
        self.button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17.0)
        self.button.layer.cornerRadius = 14.0
        self.button.translatesAutoresizingMaskIntoConstraints = false
        self.button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
        self.view.addSubview(self.button)

        NSLayoutConstraint.activate([
            self.content.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 24.0),
            self.content.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 24.0),
            self.content.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -24.0),
            stack.topAnchor.constraint(equalTo: self.content.topAnchor),
            stack.leadingAnchor.constraint(equalTo: self.content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: self.content.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: self.content.bottomAnchor),
            self.button.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 20.0),
            self.button.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -20.0),
            self.button.heightAnchor.constraint(equalToConstant: 50.0),
            self.button.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -16.0),
            self.pageControl.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            self.pageControl.bottomAnchor.constraint(equalTo: self.button.topAnchor, constant: -12.0)
        ])

        let left = UISwipeGestureRecognizer(target: self, action: #selector(self.swipedLeft))
        left.direction = .left
        self.view.addGestureRecognizer(left)
        let right = UISwipeGestureRecognizer(target: self, action: #selector(self.swipedRight))
        right.direction = .right
        self.view.addGestureRecognizer(right)

        self.apply(animatedDirection: 0)
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.startWiggle()
    }

    /// The emoji keeps moving: a small swing and bounce, repeated.
    private func startWiggle() {
        let layer = self.emojiLabel.layer
        layer.removeAnimation(forKey: "wiggle")
        let rotation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        rotation.values = [0.0, -0.16, 0.16, -0.10, 0.08, 0.0, 0.0]
        rotation.keyTimes = [0.0, 0.12, 0.28, 0.42, 0.54, 0.64, 1.0]
        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [1.0, 1.12, 0.96, 1.04, 1.0, 1.0]
        scale.keyTimes = [0.0, 0.14, 0.3, 0.46, 0.64, 1.0]
        let group = CAAnimationGroup()
        group.animations = [rotation, scale]
        group.duration = 1.8
        group.repeatCount = .infinity
        layer.add(group, forKey: "wiggle")
    }

    private func apply(animatedDirection: Int) {
        let slide = self.slides[self.page]
        let update = {
            self.emojiLabel.text = slide.emoji
            self.titleLabel.text = AlfaCyrillic.ui(slide.title)
            self.textLabel.text = AlfaCyrillic.ui(slide.text)
            self.pageControl.currentPage = self.page
            self.button.setTitle(AlfaCyrillic.ui(self.page == self.slides.count - 1 ? "Boshlash" : "Keyingi"), for: .normal)
        }
        if animatedDirection == 0 {
            update()
            return
        }
        let offset: CGFloat = animatedDirection > 0 ? -40.0 : 40.0
        UIView.animate(withDuration: 0.14, animations: {
            self.content.alpha = 0.0
            self.content.transform = CGAffineTransform(translationX: offset, y: 0.0)
        }, completion: { _ in
            update()
            self.content.transform = CGAffineTransform(translationX: -offset, y: 0.0)
            UIView.animate(withDuration: 0.22, animations: {
                self.content.alpha = 1.0
                self.content.transform = .identity
            }, completion: { _ in
                self.startWiggle()
            })
        })
    }

    @objc private func buttonPressed() {
        if self.page >= self.slides.count - 1 {
            self.dismiss(animated: true, completion: nil)
            return
        }
        self.page += 1
        self.apply(animatedDirection: 1)
    }

    @objc private func swipedLeft() {
        if self.page < self.slides.count - 1 {
            self.page += 1
            self.apply(animatedDirection: 1)
        }
    }

    @objc private func swipedRight() {
        if self.page > 0 {
            self.page -= 1
            self.apply(animatedDirection: -1)
        }
    }
}

/// AlfaGram: the App Store "Rate this app" prompt — after 3 days and 8 launches, at most once in 60 days
/// (the system limits it further).
public enum AlfaReview {
    public static func onAppReady(window: UIWindow?) {
        let now = Int(Date().timeIntervalSince1970)
        var first = AlfaSettings.integer("firstLaunch")
        if first == 0 {
            first = now
            AlfaSettings.setInteger("firstLaunch", now)
        }
        let launches = AlfaSettings.integer("launches") + 1
        AlfaSettings.setInteger("launches", launches)
        let last = AlfaSettings.integer("lastReview")
        if now - first < 3 * 24 * 60 * 60 || launches < 8 || (last != 0 && now - last < 60 * 24 * 60 * 60) {
            return
        }
        AlfaSettings.setInteger("lastReview", now)
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0, execute: { [weak window] in
            guard let scene = window?.windowScene else {
                return
            }
            if #available(iOS 16.0, *) {
                AppStore.requestReview(in: scene)
            }
        })
    }
}
