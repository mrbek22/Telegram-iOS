import Foundation
import UIKit
import TelegramCore

/// AlfaGram: the hidden chats' code — set it up (a 4-digit PIN or a password) and ask for it.
public enum AlfaHiddenChatsUI {
    /// The window the alerts go over — taken from the caller's controller (UIApplication.shared is not available here).
    private static weak var window: UIWindow?

    /// The topmost view controller of that window (the alerts go over whatever is on screen).
    private static func topController() -> UIViewController? {
        guard var top = window?.rootViewController else {
            return nil
        }
        while let presented = top.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }

    private static func configure(_ field: UITextField, numeric: Bool, placeholder: String) {
        field.isSecureTextEntry = true
        field.placeholder = placeholder
        field.textAlignment = .center
        field.keyboardType = numeric ? .numberPad : .asciiCapable
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.spellCheckingType = .no
    }

    /// Asks for the code; `completion(true)` once it is right.
    public static func askCode(from controller: UIViewController, title: String, completion: @escaping (Bool) -> Void) {
        if let controllerWindow = controller.view.window {
            window = controllerWindow
        }
        guard let top = topController() else {
            completion(false)
            return
        }
        let numeric = AlfaHiddenChats.isNumericCode
        let alert = UIAlertController(title: title, message: AlfaCyrillic.ui(numeric ? "4 raqamli PIN kodni kiriting" : "Parolni kiriting"), preferredStyle: .alert)
        alert.addTextField { field in
            configure(field, numeric: numeric, placeholder: numeric ? "••••" : AlfaCyrillic.ui("Parol"))
        }
        alert.addAction(UIAlertAction(title: AlfaCyrillic.ui("Bekor qilish"), style: .cancel, handler: { _ in
            completion(false)
        }))
        alert.addAction(UIAlertAction(title: AlfaCyrillic.ui("Ochish"), style: .default, handler: { [weak alert] _ in
            let code = alert?.textFields?.first?.text ?? ""
            if AlfaHiddenChats.checkCode(code) {
                completion(true)
            } else {
                let wrong = UIAlertController(title: nil, message: AlfaCyrillic.ui("Kod noto'g'ri"), preferredStyle: .alert)
                wrong.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                    completion(false)
                }))
                topController()?.present(wrong, animated: true, completion: nil)
            }
        }))
        top.present(alert, animated: true, completion: nil)
    }

    /// From the settings: turn on (lock type + code), or — after the code — change the code / turn off.
    public static func manage(from controller: UIViewController, completion: @escaping () -> Void) {
        if let controllerWindow = controller.view.window {
            window = controllerWindow
        }
        if !AlfaHiddenChats.isEnabled {
            setup(completion: { _ in
                completion()
            })
            return
        }
        askCode(from: controller, title: AlfaCyrillic.ui("Yashirin chatlar"), completion: { success in
            guard success, let top = topController() else {
                completion()
                return
            }
            let sheet = UIAlertController(title: AlfaCyrillic.ui("Yashirin chatlar"), message: nil, preferredStyle: .actionSheet)
            sheet.addAction(UIAlertAction(title: AlfaCyrillic.ui("Kodni o'zgartirish"), style: .default, handler: { _ in
                setup(completion: { _ in
                    completion()
                })
            }))
            sheet.addAction(UIAlertAction(title: AlfaCyrillic.ui("O'chirish (hamma chat ko'rinadi)"), style: .destructive, handler: { _ in
                AlfaHiddenChats.disable()
                completion()
            }))
            sheet.addAction(UIAlertAction(title: AlfaCyrillic.ui("Bekor qilish"), style: .cancel, handler: { _ in
                completion()
            }))
            if let popover = sheet.popoverPresentationController {
                popover.sourceView = top.view
                popover.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 1.0, height: 1.0)
                popover.permittedArrowDirections = []
            }
            top.present(sheet, animated: true, completion: nil)
        })
    }

    /// The lock type, then the code twice. `completion(true)` once a code is saved.
    public static func setup(completion: @escaping (Bool) -> Void) {
        guard let top = topController() else {
            completion(false)
            return
        }
        let sheet = UIAlertController(title: AlfaCyrillic.ui("Qulf turi"), message: AlfaCyrillic.ui("Yashirin chatlar shu kod bilan ochiladi"), preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: AlfaCyrillic.ui("4 raqamli PIN"), style: .default, handler: { _ in
            enterNewCode(numeric: true, completion: completion)
        }))
        sheet.addAction(UIAlertAction(title: AlfaCyrillic.ui("Harfli-raqamli parol"), style: .default, handler: { _ in
            enterNewCode(numeric: false, completion: completion)
        }))
        sheet.addAction(UIAlertAction(title: AlfaCyrillic.ui("Bekor qilish"), style: .cancel, handler: { _ in
            completion(false)
        }))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = top.view
            popover.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 1.0, height: 1.0)
            popover.permittedArrowDirections = []
        }
        top.present(sheet, animated: true, completion: nil)
    }

    private static func enterNewCode(numeric: Bool, completion: @escaping (Bool) -> Void) {
        guard let top = topController() else {
            completion(false)
            return
        }
        let alert = UIAlertController(title: AlfaCyrillic.ui(numeric ? "4 raqamli PIN" : "Harfli-raqamli parol"), message: AlfaCyrillic.ui("Kodni ikki marta kiriting. Uni unutmang: tiklab bo'lmaydi."), preferredStyle: .alert)
        alert.addTextField { field in
            configure(field, numeric: numeric, placeholder: AlfaCyrillic.ui("Yangi kod"))
        }
        alert.addTextField { field in
            configure(field, numeric: numeric, placeholder: AlfaCyrillic.ui("Qaytadan"))
        }
        alert.addAction(UIAlertAction(title: AlfaCyrillic.ui("Bekor qilish"), style: .cancel, handler: { _ in
            completion(false)
        }))
        alert.addAction(UIAlertAction(title: AlfaCyrillic.ui("Saqlash"), style: .default, handler: { [weak alert] _ in
            let first = alert?.textFields?.first?.text ?? ""
            let second = alert?.textFields?.last?.text ?? ""
            var problem: String?
            if first != second {
                problem = "Kodlar bir xil emas"
            } else if numeric && (first.count != 4 || !first.allSatisfy({ $0.isASCII && $0.isNumber })) {
                problem = "PIN aynan 4 ta raqam bo'lishi kerak"
            } else if !numeric && first.count < 4 {
                problem = "Parol kamida 4 belgidan iborat bo'lsin"
            }
            if let problem {
                let error = UIAlertController(title: nil, message: AlfaCyrillic.ui(problem), preferredStyle: .alert)
                error.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                    enterNewCode(numeric: numeric, completion: completion)
                }))
                topController()?.present(error, animated: true, completion: nil)
                return
            }
            AlfaHiddenChats.setCode(first, numeric: numeric)
            completion(true)
        }))
        top.present(alert, animated: true, completion: nil)
    }
}
