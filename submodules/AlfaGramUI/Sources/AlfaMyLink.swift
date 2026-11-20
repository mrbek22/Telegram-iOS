import Foundation
import UIKit
import CoreImage
import TelegramCore

private func alfaLinkColor(_ rgb: UInt32, alpha: CGFloat = 1.0) -> UIColor {
    return UIColor(red: CGFloat((rgb >> 16) & 0xff) / 255.0, green: CGFloat((rgb >> 8) & 0xff) / 255.0, blue: CGFloat(rgb & 0xff) / 255.0, alpha: alpha)
}

/// AlfaGram: "My AlfaGram link" — a card with the name, @username, a QR code (AlfaGram logo in the middle) and the
/// alfagram.uz/username link; copy, share, save the QR card to Photos or share it as an image (for stories).
public final class AlfaMyLinkController: UIViewController {
    private let name: String
    private let username: String?
    private let openUsernameSetup: () -> Void

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let card = UIView()
    private var link: String {
        if let username, !username.isEmpty {
            return "https://alfagram.uz/" + username
        }
        return "https://alfagram.uz"
    }

    public init(name: String, username: String?, openUsernameSetup: @escaping () -> Void) {
        self.name = name
        self.username = username
        self.openUsernameSetup = openUsernameSetup
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .pageSheet
        if let sheet = self.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.systemGroupedBackground

        self.scrollView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.scrollView)
        self.stack.axis = .vertical
        self.stack.spacing = 14.0
        self.stack.alignment = .fill
        self.stack.translatesAutoresizingMaskIntoConstraints = false
        self.scrollView.addSubview(self.stack)
        NSLayoutConstraint.activate([
            self.scrollView.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.scrollView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            self.scrollView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.scrollView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.stack.topAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.topAnchor, constant: 28.0),
            self.stack.bottomAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.bottomAnchor, constant: -28.0),
            self.stack.leadingAnchor.constraint(equalTo: self.scrollView.frameLayoutGuide.leadingAnchor, constant: 20.0),
            self.stack.trailingAnchor.constraint(equalTo: self.scrollView.frameLayoutGuide.trailingAnchor, constant: -20.0)
        ])

        let title = UILabel()
        title.text = AlfaCyrillic.ui("Mening AlfaGram havolam")
        title.font = UIFont.systemFont(ofSize: 22.0, weight: .bold)
        title.textAlignment = .center
        self.stack.addArrangedSubview(title)

        self.buildCard()
        self.stack.addArrangedSubview(self.card)

        if let username = self.username, !username.isEmpty {
            self.stack.addArrangedSubview(self.button(AlfaCyrillic.ui("Havolani nusxalash"), symbol: "doc.on.doc", primary: true, action: #selector(self.copyPressed)))
            self.stack.addArrangedSubview(self.button(AlfaCyrillic.ui("Ulashish"), symbol: "square.and.arrow.up", primary: false, action: #selector(self.sharePressed)))
            self.stack.addArrangedSubview(self.button(AlfaCyrillic.ui("Kartochka sifatida ulashish"), symbol: "photo.on.rectangle", primary: false, action: #selector(self.shareCardPressed)))
            self.stack.addArrangedSubview(self.button(AlfaCyrillic.ui("QR'ni rasmlarga saqlash"), symbol: "square.and.arrow.down", primary: false, action: #selector(self.savePressed)))
        } else {
            let info = UILabel()
            info.text = AlfaCyrillic.ui("Shaxsiy havola uchun avval username qo'ying.")
            info.font = UIFont.systemFont(ofSize: 15.0)
            info.textColor = UIColor.secondaryLabel
            info.numberOfLines = 0
            info.textAlignment = .center
            self.stack.addArrangedSubview(info)
            self.stack.addArrangedSubview(self.button(AlfaCyrillic.ui("Username qo'yish"), symbol: "at", primary: true, action: #selector(self.usernamePressed)))
        }
    }

    private func buildCard() {
        let card = self.card
        card.layer.cornerRadius = 28.0
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true

        let gradient = CAGradientLayer()
        gradient.colors = [alfaLinkColor(0x0b0f1a).cgColor, alfaLinkColor(0x142e78).cgColor]
        gradient.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradient.endPoint = CGPoint(x: 1.0, y: 1.0)
        card.layer.insertSublayer(gradient, at: 0)

        let inner = UIStackView()
        inner.axis = .vertical
        inner.alignment = .center
        inner.spacing = 10.0
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: card.topAnchor, constant: 26.0),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24.0),
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20.0),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20.0)
        ])

        let nameLabel = UILabel()
        nameLabel.text = self.name
        nameLabel.font = UIFont.systemFont(ofSize: 22.0, weight: .bold)
        nameLabel.textColor = .white
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 2
        inner.addArrangedSubview(nameLabel)

        if let username = self.username, !username.isEmpty {
            let userLabel = UILabel()
            userLabel.text = "@" + username
            userLabel.font = UIFont.systemFont(ofSize: 16.0, weight: .medium)
            userLabel.textColor = alfaLinkColor(0xbcd0f5)
            inner.addArrangedSubview(userLabel)
        }

        let qrBox = UIView()
        qrBox.backgroundColor = .white
        qrBox.layer.cornerRadius = 22.0
        qrBox.layer.cornerCurve = .continuous
        qrBox.translatesAutoresizingMaskIntoConstraints = false
        let qrView = UIImageView(image: AlfaMyLinkController.qrImage(self.link, side: 600.0))
        qrView.contentMode = .scaleAspectFit
        qrView.translatesAutoresizingMaskIntoConstraints = false
        qrBox.addSubview(qrView)
        let logo = UIImageView(image: UIImage(named: "AlfaLaunchLogo"))
        logo.contentMode = .scaleAspectFit
        logo.backgroundColor = .white
        logo.layer.cornerRadius = 12.0
        logo.clipsToBounds = true
        logo.translatesAutoresizingMaskIntoConstraints = false
        qrBox.addSubview(logo)
        NSLayoutConstraint.activate([
            qrBox.widthAnchor.constraint(equalToConstant: 236.0),
            qrBox.heightAnchor.constraint(equalToConstant: 236.0),
            qrView.topAnchor.constraint(equalTo: qrBox.topAnchor, constant: 16.0),
            qrView.bottomAnchor.constraint(equalTo: qrBox.bottomAnchor, constant: -16.0),
            qrView.leadingAnchor.constraint(equalTo: qrBox.leadingAnchor, constant: 16.0),
            qrView.trailingAnchor.constraint(equalTo: qrBox.trailingAnchor, constant: -16.0),
            logo.centerXAnchor.constraint(equalTo: qrBox.centerXAnchor),
            logo.centerYAnchor.constraint(equalTo: qrBox.centerYAnchor),
            logo.widthAnchor.constraint(equalToConstant: 52.0),
            logo.heightAnchor.constraint(equalToConstant: 52.0)
        ])
        inner.setCustomSpacing(18.0, after: inner.arrangedSubviews.last ?? nameLabel)
        inner.addArrangedSubview(qrBox)

        let linkLabel = UILabel()
        linkLabel.text = self.link.replacingOccurrences(of: "https://", with: "")
        linkLabel.font = UIFont.systemFont(ofSize: 16.0, weight: .semibold)
        linkLabel.textColor = .white
        inner.setCustomSpacing(16.0, after: qrBox)
        inner.addArrangedSubview(linkLabel)

        let brand = UILabel()
        brand.text = "AlfaGram"
        brand.font = UIFont.systemFont(ofSize: 13.0, weight: .medium)
        brand.textColor = alfaLinkColor(0x8fa6d6)
        inner.addArrangedSubview(brand)
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let gradient = self.card.layer.sublayers?.first as? CAGradientLayer {
            gradient.frame = self.card.bounds
        }
    }

    private func button(_ title: String, symbol: String, primary: Bool, action: Selector) -> UIButton {
        var config = primary ? UIButton.Configuration.filled() : UIButton.Configuration.tinted()
        config.title = title
        config.image = UIImage(systemName: symbol)
        config.imagePadding = 8.0
        config.cornerStyle = .large
        config.buttonSize = .large
        let button = UIButton(configuration: config)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    /// A crisp QR code (high error correction, so the logo in the middle does not break it).
    static func qrImage(_ string: String, side: CGFloat) -> UIImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            return nil
        }
        filter.setValue(Data(string.utf8), forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else {
            return nil
        }
        let scale = side / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    private func cardImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: self.card.bounds)
        return renderer.image { _ in
            self.card.drawHierarchy(in: self.card.bounds, afterScreenUpdates: true)
        }
    }

    private func toast(_ text: String) {
        let alert = UIAlertController(title: nil, message: text, preferredStyle: .alert)
        self.present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: { [weak alert] in
            alert?.dismiss(animated: true)
        })
    }

    private func presentShare(_ items: [Any], from sender: UIView) {
        let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = activity.popoverPresentationController {
            popover.sourceView = sender
            popover.sourceRect = sender.bounds
        }
        self.present(activity, animated: true)
    }

    @objc private func copyPressed() {
        UIPasteboard.general.string = self.link
        self.toast(AlfaCyrillic.ui("Havola nusxalandi"))
    }

    @objc private func sharePressed(_ sender: UIButton) {
        self.presentShare([self.link], from: sender)
    }

    @objc private func shareCardPressed(_ sender: UIButton) {
        self.presentShare([self.cardImage(), self.link], from: sender)
    }

    @objc private func savePressed() {
        UIImageWriteToSavedPhotosAlbum(self.cardImage(), nil, nil, nil)
        self.toast(AlfaCyrillic.ui("Rasmlarga saqlandi"))
    }

    @objc private func usernamePressed() {
        let openUsernameSetup = self.openUsernameSetup
        self.dismiss(animated: true, completion: {
            openUsernameSetup()
        })
    }
}
