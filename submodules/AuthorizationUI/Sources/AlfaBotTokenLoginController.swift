import Foundation
import UIKit
import TelegramCore
import TelegramPresentationData
import AnimatedStickerNode
import TelegramAnimatedStickerNode

/// AlfaGram: «Log in with a bot token» — a full screen: a robot, a title, a short note, a rounded token field and a
/// wide button. `submit` gets the token and calls back with an error text, or nil once the login went through.
final class AlfaBotTokenLoginController: UIViewController, UITextFieldDelegate {
    private let presentationData: PresentationData
    private let submit: (String, @escaping (String?) -> Void) -> Void

    private let scrollView = UIScrollView()
    private let backButton = UIButton(type: .system)
    /// The animated robot (Noto Emoji 🤖, bundled as AlfaRobot.tgs).
    private let robotNode: AnimatedStickerNode = DefaultAnimatedStickerNodeImpl()
    private let titleLabel = UILabel()
    private let noteLabel = UILabel()
    private let tokenField = UITextField()
    private let loginButton = UIButton(type: .custom)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let footerLabel = UILabel()
    private var inProgress = false

    init(presentationData: PresentationData, submit: @escaping (String, @escaping (String?) -> Void) -> Void) {
        self.presentationData = presentationData
        self.submit = submit
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let theme = self.presentationData.theme
        self.view.backgroundColor = theme.list.plainBackgroundColor
        self.overrideUserInterfaceStyle = theme.overallDarkAppearance ? .dark : .light

        self.scrollView.alwaysBounceVertical = true
        self.scrollView.keyboardDismissMode = .interactive
        self.view.addSubview(self.scrollView)

        var backConfiguration = UIButton.Configuration.gray()
        backConfiguration.title = AlfaCyrillic.ui("Orqaga")
        backConfiguration.cornerStyle = .capsule
        backConfiguration.baseForegroundColor = theme.list.itemPrimaryTextColor
        backConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 10.0, leading: 18.0, bottom: 10.0, trailing: 18.0)
        self.backButton.configuration = backConfiguration
        self.backButton.addTarget(self, action: #selector(self.backPressed), for: .touchUpInside)
        self.view.addSubview(self.backButton)

        self.robotNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "AlfaRobot"), width: 240, height: 240, playbackMode: .loop, mode: .direct(cachePathPrefix: nil))
        self.robotNode.visibility = true
        self.scrollView.addSubview(self.robotNode.view)

        self.titleLabel.text = AlfaCyrillic.ui("Bot token bilan kirish")
        self.titleLabel.font = UIFont.systemFont(ofSize: 28.0, weight: .bold)
        self.titleLabel.textColor = theme.list.itemPrimaryTextColor
        self.titleLabel.textAlignment = .center
        self.titleLabel.numberOfLines = 0
        self.scrollView.addSubview(self.titleLabel)

        self.noteLabel.text = AlfaCyrillic.ui("Bot rejimi cheklangan: chatlar ro'yxati va eski xabarlar ko'rinmaydi")
        self.noteLabel.font = UIFont.systemFont(ofSize: 16.0)
        self.noteLabel.textColor = theme.list.itemSecondaryTextColor
        self.noteLabel.textAlignment = .center
        self.noteLabel.numberOfLines = 0
        self.scrollView.addSubview(self.noteLabel)

        self.tokenField.font = UIFont.monospacedSystemFont(ofSize: 17.0, weight: .regular)
        self.tokenField.textColor = theme.list.itemPrimaryTextColor
        self.tokenField.tintColor = theme.list.itemAccentColor
        self.tokenField.attributedPlaceholder = NSAttributedString(string: "123456789:ABCdef...", attributes: [.foregroundColor: theme.list.itemPlaceholderTextColor, .font: UIFont.monospacedSystemFont(ofSize: 17.0, weight: .regular)])
        self.tokenField.autocorrectionType = .no
        self.tokenField.autocapitalizationType = .none
        self.tokenField.spellCheckingType = .no
        self.tokenField.keyboardType = .asciiCapable
        self.tokenField.returnKeyType = .done
        self.tokenField.clearButtonMode = .whileEditing
        self.tokenField.delegate = self
        self.tokenField.layer.cornerRadius = 16.0
        self.tokenField.layer.borderWidth = 1.0
        self.tokenField.layer.borderColor = theme.list.itemBlocksSeparatorColor.cgColor
        self.tokenField.backgroundColor = theme.list.itemBlocksBackgroundColor
        self.tokenField.leftView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 18.0, height: 1.0))
        self.tokenField.leftViewMode = .always
        self.tokenField.addTarget(self, action: #selector(self.tokenChanged), for: .editingChanged)
        self.scrollView.addSubview(self.tokenField)

        self.loginButton.setTitle(AlfaCyrillic.ui("Tizimga kirish"), for: .normal)
        self.loginButton.titleLabel?.font = UIFont.systemFont(ofSize: 17.0, weight: .semibold)
        self.loginButton.setTitleColor(.white, for: .normal)
        self.loginButton.backgroundColor = theme.list.itemCheckColors.fillColor
        self.loginButton.layer.cornerRadius = 27.0
        self.loginButton.addTarget(self, action: #selector(self.loginPressed), for: .touchUpInside)
        self.scrollView.addSubview(self.loginButton)

        self.activityIndicator.color = .white
        self.activityIndicator.hidesWhenStopped = true
        self.loginButton.addSubview(self.activityIndicator)

        self.footerLabel.text = AlfaCyrillic.ui("Tokenni @BotFather beradi: /newbot yoki /token buyrug'i.")
        self.footerLabel.font = UIFont.systemFont(ofSize: 13.0)
        self.footerLabel.textColor = theme.list.itemSecondaryTextColor
        self.footerLabel.textAlignment = .center
        self.footerLabel.numberOfLines = 0
        self.scrollView.addSubview(self.footerLabel)

        self.updateButtonState()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.tokenField.becomeFirstResponder()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let bounds = self.view.bounds
        let safe = self.view.safeAreaInsets
        let side: CGFloat = 24.0
        let width = min(bounds.width - side * 2.0, 460.0)
        let left = floor((bounds.width - width) / 2.0)

        let backSize = self.backButton.sizeThatFits(CGSize(width: 200.0, height: 44.0))
        self.backButton.frame = CGRect(x: 16.0, y: safe.top + 8.0, width: backSize.width, height: max(44.0, backSize.height))

        let top = self.backButton.frame.maxY
        self.scrollView.frame = CGRect(x: 0.0, y: top, width: bounds.width, height: bounds.height - top)

        var y: CGFloat = 32.0
        let robotSide: CGFloat = 110.0
        self.robotNode.frame = CGRect(x: floor((bounds.width - robotSide) / 2.0), y: y - 5.0, width: robotSide, height: robotSide)
        self.robotNode.updateLayout(size: CGSize(width: robotSide, height: robotSide))
        y += 100.0 + 24.0
        let titleHeight = self.titleLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        self.titleLabel.frame = CGRect(x: left, y: y, width: width, height: titleHeight)
        y += titleHeight + 12.0
        let noteHeight = self.noteLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        self.noteLabel.frame = CGRect(x: left, y: y, width: width, height: noteHeight)
        y += noteHeight + 40.0
        self.tokenField.frame = CGRect(x: left, y: y, width: width, height: 58.0)
        y += 58.0 + 32.0
        self.loginButton.frame = CGRect(x: left, y: y, width: width, height: 54.0)
        self.activityIndicator.center = CGPoint(x: width / 2.0, y: 27.0)
        y += 54.0 + 16.0
        let footerHeight = self.footerLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        self.footerLabel.frame = CGRect(x: left, y: y, width: width, height: footerHeight)
        y += footerHeight + 24.0
        self.scrollView.contentSize = CGSize(width: bounds.width, height: y)
    }

    private var token: String {
        return self.tokenField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func updateButtonState() {
        let enabled = !self.inProgress && !self.token.isEmpty
        self.loginButton.isEnabled = enabled
        self.loginButton.alpha = (enabled || self.inProgress) ? 1.0 : 0.5
        self.loginButton.setTitle(self.inProgress ? "" : AlfaCyrillic.ui("Tizimga kirish"), for: .normal)
        if self.inProgress {
            self.activityIndicator.startAnimating()
        } else {
            self.activityIndicator.stopAnimating()
        }
        self.tokenField.isEnabled = !self.inProgress
    }

    @objc private func tokenChanged() {
        self.updateButtonState()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.loginPressed()
        return false
    }

    @objc private func backPressed() {
        guard !self.inProgress else {
            return
        }
        self.view.endEditing(true)
        self.dismiss(animated: true, completion: nil)
    }

    @objc private func loginPressed() {
        let token = self.token
        guard !self.inProgress, !token.isEmpty else {
            return
        }
        self.inProgress = true
        self.updateButtonState()
        self.submit(token, { [weak self] errorText in
            guard let self else {
                return
            }
            self.inProgress = false
            self.updateButtonState()
            if let errorText {
                let alert = UIAlertController(title: nil, message: errorText, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: self.presentationData.strings.Common_OK, style: .default, handler: { [weak self] _ in
                    self?.tokenField.becomeFirstResponder()
                }))
                self.present(alert, animated: true, completion: nil)
            } else {
                self.view.endEditing(true)
                self.dismiss(animated: true, completion: nil)
            }
        })
    }
}
