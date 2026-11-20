import Foundation
import UIKit
import StoreKit
import TelegramCore

private func alfaColor(_ rgb: UInt32) -> UIColor {
    return UIColor(red: CGFloat((rgb >> 16) & 0xff) / 255.0, green: CGFloat((rgb >> 8) & 0xff) / 255.0, blue: CGFloat(rgb & 0xff) / 255.0, alpha: 1.0)
}

/// AlfaGram: "what AlfaGram can do" — shown once over the chat list: a list of features, each with an icon tile,
/// in the app's language (Uzbek Latin / Cyrillic, English, Russian).
public final class AlfaOnboardingController: UIViewController {
    private static let shownKey = "onboardingV2"

    private struct Feature {
        let symbol: String
        let title: String
        let text: String
    }

    private let features: [Feature] = [
        Feature(symbol: "eye.slash.fill", title: "Ghost rejim", text: "Onlayn ko'rinmasdan o'qing: «yozyapti» va «o'qildi» yuborilmaydi. Chatlar ro'yxati tepasidagi ko'z belgisi bilan bir bosishda yoqing."),
        Feature(symbol: "trash.fill", title: "O'chirilgan xabarlar qoladi", text: "Suhbatdoshingiz xabarni o'chirsa ham, u sizda 🗑 belgisi bilan saqlanib qoladi."),
        Feature(symbol: "clock.arrow.circlepath", title: "Tahrir tarixi", text: "Tahrirlangan xabarni bosib turing → «Tahrir tarixi» — barcha oldingi matnlarni ko'rasiz."),
        Feature(symbol: "lock.fill", title: "Chat qulfi", text: "Chatni bosib turing → «Chatni qulflash». U Face ID yoki parol bilan ochiladi, xabarlari ro'yxatda va bildirishnomada ko'rinmaydi."),
        Feature(symbol: "play.circle.fill", title: "Story'larni anonim ko'rish", text: "Story'larni muallifga bildirmasdan ko'ring — bu sukut bo'yicha yoqilgan."),
        Feature(symbol: "person.2.fill", title: "10 ta akkaunt", text: "10 tagacha akkauntni bitta ilovada ishlating. Keraklisini «Maxfiy akkauntlar»da yashirib qo'ying."),
        Feature(symbol: "video.circle.fill", title: "Dumaloq video kamerasi", text: "Dumaloq video tugmasini bosib turing — old yoki orqa kamerani tanlaysiz, yozuv qo'lsiz davom etadi."),
        Feature(symbol: "checkmark.shield.fill", title: "Havola himoyasi", text: "Soxta bank, Click, Payme yoki Telegram saytlari va «sovg'a» va'da qiluvchi havolalarni ochishdan oldin ogohlantiramiz."),
        Feature(symbol: "character.bubble.fill", title: "O'zbekcha va kirillcha", text: "Ilova o'zbek tilida, xohlasangiz kirillda. Lotincha yozganingizni kirillda yuborish ham mumkin."),
        Feature(symbol: "gearshape.fill", title: "Hammasi bir joyda", text: "Barcha imkoniyatlarni Sozlamalar → AlfaGram bo'limida yoqib-o'chirasiz.")
    ]

    private let scrollView = UIScrollView()
    private let button = UIButton(type: .system)

    /// Shown once per install, over the main screen (the chat list).
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
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 28.0
        }
        top.present(controller, animated: true, completion: nil)
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.systemBackground

        let accent = alfaColor(0x2563eb)

        self.scrollView.alwaysBounceVertical = true
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.scrollView)

        let titleLabel = UILabel()
        titleLabel.text = AlfaCyrillic.ui("AlfaGram imkoniyatlari")
        titleLabel.font = UIFont.systemFont(ofSize: 28.0, weight: .bold)
        titleLabel.textColor = UIColor.label
        titleLabel.numberOfLines = 0

        let list = UIStackView()
        list.axis = .vertical
        list.alignment = .fill
        list.spacing = 0.0
        list.translatesAutoresizingMaskIntoConstraints = false
        self.scrollView.addSubview(list)

        list.addArrangedSubview(titleLabel)
        list.setCustomSpacing(18.0, after: titleLabel)

        for (index, feature) in self.features.enumerated() {
            list.addArrangedSubview(self.makeRow(feature, accent: accent, separator: index != self.features.count - 1))
        }

        self.button.backgroundColor = accent
        self.button.setTitleColor(UIColor.white, for: .normal)
        self.button.setTitle(AlfaCyrillic.ui("Tushunarli!"), for: .normal)
        self.button.titleLabel?.font = UIFont.systemFont(ofSize: 18.0, weight: .semibold)
        self.button.layer.cornerRadius = 25.0
        self.button.translatesAutoresizingMaskIntoConstraints = false
        self.button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
        self.view.addSubview(self.button)

        NSLayoutConstraint.activate([
            self.scrollView.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.scrollView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.scrollView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.scrollView.bottomAnchor.constraint(equalTo: self.button.topAnchor, constant: -10.0),

            list.topAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.topAnchor, constant: 36.0),
            list.bottomAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.bottomAnchor, constant: -16.0),
            list.leadingAnchor.constraint(equalTo: self.scrollView.frameLayoutGuide.leadingAnchor, constant: 24.0),
            list.trailingAnchor.constraint(equalTo: self.scrollView.frameLayoutGuide.trailingAnchor, constant: -24.0),

            self.button.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 20.0),
            self.button.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -20.0),
            self.button.heightAnchor.constraint(equalToConstant: 52.0),
            self.button.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -12.0)
        ])
    }

    /// One feature: a blue rounded tile with a white icon, the title and the explanation, a hairline below.
    private func makeRow(_ feature: Feature, accent: UIColor, separator: Bool) -> UIView {
        let row = UIView()

        let tile = UIView()
        tile.backgroundColor = accent
        tile.layer.cornerRadius = 14.0
        tile.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(tile)

        let icon = UIImageView(image: UIImage(systemName: feature.symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 24.0, weight: .semibold)))
        icon.tintColor = UIColor.white
        icon.contentMode = .center
        icon.translatesAutoresizingMaskIntoConstraints = false
        tile.addSubview(icon)

        let titleLabel = UILabel()
        titleLabel.text = AlfaCyrillic.ui(feature.title)
        titleLabel.font = UIFont.systemFont(ofSize: 18.0, weight: .semibold)
        titleLabel.textColor = UIColor.label
        titleLabel.numberOfLines = 0

        let textLabel = UILabel()
        textLabel.text = AlfaCyrillic.ui(feature.text)
        textLabel.font = UIFont.systemFont(ofSize: 15.0)
        textLabel.textColor = UIColor.secondaryLabel
        textLabel.numberOfLines = 0

        let texts = UIStackView(arrangedSubviews: [titleLabel, textLabel])
        texts.axis = .vertical
        texts.spacing = 4.0
        texts.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(texts)

        var constraints: [NSLayoutConstraint] = [
            tile.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            tile.widthAnchor.constraint(equalToConstant: 56.0),
            tile.heightAnchor.constraint(equalToConstant: 56.0),
            tile.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            tile.topAnchor.constraint(greaterThanOrEqualTo: row.topAnchor, constant: 14.0),
            icon.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
            texts.leadingAnchor.constraint(equalTo: tile.trailingAnchor, constant: 16.0),
            texts.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            texts.topAnchor.constraint(equalTo: row.topAnchor, constant: 16.0),
            texts.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -16.0)
        ]

        if separator {
            let line = UIView()
            line.backgroundColor = UIColor.separator
            line.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(line)
            constraints.append(contentsOf: [
                line.leadingAnchor.constraint(equalTo: texts.leadingAnchor),
                line.trailingAnchor.constraint(equalTo: row.trailingAnchor),
                line.bottomAnchor.constraint(equalTo: row.bottomAnchor),
                line.heightAnchor.constraint(equalToConstant: 0.5)
            ])
        }
        NSLayoutConstraint.activate(constraints)
        return row
    }

    @objc private func buttonPressed() {
        self.dismiss(animated: true, completion: nil)
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
