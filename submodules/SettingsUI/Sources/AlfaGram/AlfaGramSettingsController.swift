import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AccountUtils
import AlfaGramUI

private enum AlfaGramSettingsAction: Equatable {
    case onlineLog
    case profileLog
    case typingLog
    case helpGroup
    case autoFolders
    case hiddenAccounts
    case about
}

private final class AlfaGramSettingsControllerArguments {
    let toggle: (AlfaSettings.Key, Bool) -> Void
    let open: (AlfaGramSettingsAction) -> Void

    init(toggle: @escaping (AlfaSettings.Key, Bool) -> Void, open: @escaping (AlfaGramSettingsAction) -> Void) {
        self.toggle = toggle
        self.open = open
    }
}

/// AlfaGram: a settings icon — a white SF Symbol on a colored rounded tile (like the system Settings).
func alfaSettingsIcon(_ symbol: String, _ color: UInt32) -> UIImage? {
    let size = CGSize(width: 29.0, height: 29.0)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { _ in
        UIColor(rgb: color).setFill()
        UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: size), cornerRadius: 7.0).fill()
        if let glyph = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 14.0, weight: .semibold))?.withTintColor(UIColor.white, renderingMode: .alwaysOriginal) {
            let glyphSize = glyph.size
            glyph.draw(in: CGRect(origin: CGPoint(x: (size.width - glyphSize.width) / 2.0, y: (size.height - glyphSize.height) / 2.0), size: glyphSize))
        }
    }
}

private enum AlfaGramSettingsEntry: ItemListNodeEntry, Equatable {
    case header(Int32, Int32, String)
    /// section, id, key, title, explanation, icon symbol, icon color, value
    case toggle(Int32, Int32, AlfaSettings.Key, String, String, String, UInt32, Bool)
    /// section, id, action, title, icon symbol, icon color
    case action(Int32, Int32, AlfaGramSettingsAction, String, String, UInt32)
    case info(Int32, Int32, String)

    var section: ItemListSectionId {
        switch self {
        case let .header(section, _, _), let .toggle(section, _, _, _, _, _, _, _), let .action(section, _, _, _, _, _), let .info(section, _, _):
            return section
        }
    }

    var stableId: Int32 {
        switch self {
        case let .header(_, id, _), let .toggle(_, id, _, _, _, _, _, _), let .action(_, id, _, _, _, _), let .info(_, id, _):
            return id
        }
    }

    static func <(lhs: AlfaGramSettingsEntry, rhs: AlfaGramSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AlfaGramSettingsControllerArguments
        switch self {
        case let .header(_, _, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .toggle(_, _, key, title, text, symbol, color, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: alfaSettingsIcon(symbol, color), title: title, text: text, value: value, maximumNumberOfLines: 2, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(key, value)
            })
        case let .action(_, _, action, title, symbol, color):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: alfaSettingsIcon(symbol, color), title: title, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.open(action)
            })
        case let .info(_, _, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func alfaGramSettingsEntries() -> [AlfaGramSettingsEntry] {
    let ui = AlfaCyrillic.ui
    var entries: [AlfaGramSettingsEntry] = []
    var id: Int32 = 0
    func next() -> Int32 {
        id += 1
        return id
    }

    entries.append(.header(0, next(), ui("XABARLAR")))
    entries.append(.toggle(0, next(), .saveDeletedMessages, ui("O'chirilgan xabarlarni saqlash"), ui("Suhbatdosh o'chirgan xabar sizda 🗑 belgisi bilan qoladi"), "trash.fill", 0xff3b30, AlfaSettings.saveDeletedMessages))
    entries.append(.toggle(0, next(), .saveEditHistory, ui("Tahrir tarixini saqlash"), ui("Tahrirlangan xabarni bosib turing → «Tahrir tarixi»"), "clock.arrow.circlepath", 0x30b8a8, AlfaSettings.saveEditHistory))
    entries.append(.toggle(0, next(), .showMessageId, ui("Xabar menyusida «ID nusxalash»"), ui("Xabarni bosib turganda ID'ni nusxalash bandi"), "number", 0x5e6ad2, AlfaSettings.showMessageId))

    entries.append(.header(1, next(), ui("GHOST REJIM")))
    entries.append(.toggle(1, next(), .ghostOnline, ui("Onlayn ko'rinmaslik"), ui("Hech kim sizni onlayn holatda ko'rmaydi"), "eye.slash.fill", 0x8e8e93, AlfaSettings.ghostOnline))
    entries.append(.toggle(1, next(), .ghostTyping, ui("«Yozyapti...» ni yubormaslik"), ui("Suhbatdosh siz yozayotganingizni ko'rmaydi"), "pencil.slash", 0xff9500, AlfaSettings.ghostTyping))
    entries.append(.toggle(1, next(), .ghostRead, ui("O'qilganini bildirmaslik"), ui("Xabarni o'qiganingiz yuboruvchiga bildirilmaydi"), "envelope.open.fill", 0x007aff, AlfaSettings.ghostRead))
    entries.append(.toggle(1, next(), .stealthStories, ui("Story'larni anonim ko'rish"), ui("Story muallifi siz ko'rganingizni bilmaydi"), "play.circle.fill", 0x5856d6, AlfaSettings.stealthStories))
    entries.append(.info(1, next(), ui("Chatlar ro'yxati tepasidagi ko'z belgisi uchala Ghost sozlamasini bir bosishda yoqadi.")))

    entries.append(.header(2, next(), ui("KUZATUV")))
    entries.append(.toggle(2, next(), .onlineLog, ui("Kontaktlar onlayn tarixini yozish"), ui("Kim qachon onlayn bo'lgani yozib boriladi"), "clock.fill", 0x34c759, AlfaSettings.onlineLog))
    entries.append(.action(2, next(), .onlineLog, ui("Onlayn tarixi"), "list.bullet.rectangle", 0x34c759))
    entries.append(.toggle(2, next(), .profileLog, ui("Profil o'zgarishlarini yozish"), ui("Username, rasm, raqam yoki ism o'zgarishi"), "person.crop.circle.badge.exclamationmark", 0x007aff, AlfaSettings.profileLog))
    entries.append(.action(2, next(), .profileLog, ui("Profil o'zgarishlari"), "list.bullet.rectangle", 0x007aff))
    entries.append(.toggle(2, next(), .typingLog, ui("«Yozdi, yubormadi» jurnali"), ui("Sizga yozib, yubormaganlar"), "text.bubble.fill", 0xff9500, AlfaSettings.typingLog))
    entries.append(.action(2, next(), .typingLog, ui("Yozdi, yubormadi"), "list.bullet.rectangle", 0xff9500))
    entries.append(.info(2, next(), ui("Hammasi faqat telefoningizda saqlanadi.")))

    entries.append(.header(3, next(), ui("XAVFSIZLIK")))
    entries.append(.toggle(3, next(), .linkGuard, ui("Shubhali havolalardan ogohlantirish"), ui("Soxta bank, Click, Payme, Telegram saytlari va APK havolalari"), "checkmark.shield.fill", 0x007aff, AlfaSettings.linkGuard))
    entries.append(.toggle(3, next(), .blockAds, ui("Telegram reklamalarini yashirish"), ui("Kanallardagi homiylik xabarlari ko'rinmaydi"), "nosign", 0xff3b30, AlfaSettings.blockAds))

    entries.append(.header(8, next(), ui("CHATLAR")))
    entries.append(.toggle(8, next(), .hideStories, ui("Story'lar qatorini yashirish"), ui("Chatlar ro'yxati tepasidagi story qatori"), "circle.dashed", 0xaf52de, AlfaSettings.hideStories))
    entries.append(.toggle(8, next(), .silentSend, ui("Hammasini ovozsiz yuborish"), ui("Xabarlaringiz qabul qiluvchida tovushsiz keladi"), "bell.slash.fill", 0x5856d6, AlfaSettings.silentSend))
    entries.append(.toggle(8, next(), .roundVideoAsk, ui("Dumaloq videoda kamerani so'rash"), ui("Bosib turganda old yoki orqa kamera so'raladi"), "video.circle.fill", 0xff9500, AlfaSettings.roundVideoAsk))

    entries.append(.header(9, next(), ui("MAXFIYLIK")))
    entries.append(.action(9, next(), .hiddenAccounts, ui("Maxfiy akkauntlar"), "person.crop.circle.badge.xmark", 0x007aff))
    entries.append(.info(9, next(), ui("Chatni qulflash: chatlar ro'yxatida chatni bosib turing → «Chatni qulflash». Qulflangan chat Face ID yoki telefon paroli bilan ochiladi va xabarlari ro'yxatda ko'rinmaydi.")))

    entries.append(.header(6, next(), ui("CHEKLOVSIZ")))
    entries.append(.toggle(6, next(), .unrestrictedSave, ui("Taqiqlangan chatlardan saqlash"), ui("Rasm, video va matnni saqlash, skrinshot olish"), "square.and.arrow.down.fill", 0x30b0c7, AlfaSettings.unrestrictedSave))
    entries.append(.info(6, next(), ui("Saqlash va nusxa olish yopilgan chatlarda ham rasm, video va matnni saqlash, skrinshot olish. Forward'ni Telegram serveri baribir bloklashi mumkin.")))

    entries.append(.header(4, next(), ui("TIL")))
    entries.append(.toggle(4, next(), .cyrillicUi, ui("Kirill alifbosi (Ўзбекча)"), ui("O'zbek tili tanlanganda ilova kirillda"), "character.book.closed.fill", 0x30b8a8, AlfaSettings.cyrillicUi))
    entries.append(.toggle(4, next(), .sendCyrillic, ui("Lotincha yozsam, kirillda yuborilsin"), ui("Lotincha matn kirillga o'girib yuboriladi"), "character.cursor.ibeam", 0x007aff, AlfaSettings.sendCyrillic))
    entries.append(.info(4, next(), ui("O'zbek tili tanlangan bo'lsa, ilova kirillda ko'rinadi. Tilni Sozlamalar → Til bo'limidan tanlang.")))

    entries.append(.action(10, next(), .about, ui("AlfaGram haqida"), "info.circle.fill", 0x2563eb))

    return entries
}

// MARK: - Hidden accounts

private final class AlfaHiddenAccountsArguments {
    let toggle: (EnginePeer.Id, Bool) -> Void
    let open: (AccountRecordId) -> Void

    init(toggle: @escaping (EnginePeer.Id, Bool) -> Void, open: @escaping (AccountRecordId) -> Void) {
        self.toggle = toggle
        self.open = open
    }
}

private enum AlfaHiddenAccountsEntry: ItemListNodeEntry, Equatable {
    case account(Int32, EnginePeer.Id, String, Bool)
    case open(Int32, AccountRecordId, String)
    case info(Int32, Int32, String)

    var section: ItemListSectionId {
        switch self {
        case .account:
            return 0
        case .open:
            return 1
        case let .info(section, _, _):
            return section
        }
    }

    var stableId: Int32 {
        switch self {
        case let .account(id, _, _, _), let .open(id, _, _), let .info(_, id, _):
            return id
        }
    }

    static func <(lhs: AlfaHiddenAccountsEntry, rhs: AlfaHiddenAccountsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AlfaHiddenAccountsArguments
        switch self {
        case let .account(_, peerId, title, hidden):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: hidden, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(peerId, value)
            })
        case let .open(_, accountId, title):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.open(accountId)
            })
        case let .info(_, _, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

/// AlfaGram: which accounts are hidden from the accounts list and the switcher; a hidden one opens from here.
private func alfaHiddenAccountsController(context: AccountContext) -> ViewController {
    let arguments = AlfaHiddenAccountsArguments(toggle: { peerId, hidden in
        AlfaHiddenAccounts.setHidden(accountPeerId: peerId, hidden: hidden)
    }, open: { accountId in
        context.sharedContext.switchToAccount(id: accountId, fromSettingsController: nil, withChatListController: nil)
    })

    let signal = combineLatest(context.sharedContext.presentationData, activeAccountsAndPeers(context: context, includePrimary: true, includeHidden: true), AlfaHiddenAccounts.idsSignal())
    |> deliverOnMainQueue
    |> map { presentationData, accountsAndPeers, hiddenIds -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let ui = AlfaCyrillic.ui
        var entries: [AlfaHiddenAccountsEntry] = []
        var id: Int32 = 0
        for (_, peer, _) in accountsAndPeers.1 {
            id += 1
            entries.append(.account(id, peer.id, peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), hiddenIds.contains(peer.id.toInt64())))
        }
        id += 1
        entries.append(.info(0, id, ui("Yoqilgan akkaunt «Hisoblar» ro'yxatida va akkaunt almashtirishda ko'rinmaydi. Unga faqat shu yerdan, Face ID yoki parol bilan kirasiz. Bildirishnomalari kelaveradi — kerak bo'lsa, o'sha akkauntda o'chirib qo'ying.")))
        for (accountContext, peer, _) in accountsAndPeers.1 {
            if hiddenIds.contains(peer.id.toInt64()) && accountContext.account.id != context.account.id {
                id += 1
                entries.append(.open(id, accountContext.account.id, ui("Kirish") + ": " + peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)))
            }
        }

        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(ui("Maxfiy akkauntlar")), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }

    return ItemListController(context: context, state: signal)
}

public func alfaGramSettingsController(context: AccountContext) -> ViewController {
    let revisionPromise = ValuePromise<Int32>(0, ignoreRepeated: false)
    var pushImpl: ((ViewController) -> Void)?
    var openHelpImpl: (() -> Void)?
    var presentAlertImpl: ((String) -> Void)?

    let arguments = AlfaGramSettingsControllerArguments(toggle: { key, value in
        AlfaSettings.setValue(key, value)
        if key == .onlineLog && value {
            AlfaOnlineLog.startPolling(account: context.account)
        }
        if key == .cyrillicUi {
            let languageCode = context.sharedContext.currentPresentationData.with { $0 }.strings.primaryComponent.languageCode
            let _ = context.engine.localization.downloadAndApplyLocalization(accountManager: context.sharedContext.accountManager, languageCode: languageCode).start()
        }
        revisionPromise.set(0)
    }, open: { action in
        switch action {
        case .onlineLog:
            pushImpl?(alfaOnlineLogController(context: context))
        case .profileLog:
            pushImpl?(alfaProfileLogController(context: context))
        case .typingLog:
            pushImpl?(alfaTypingLogController(context: context))
        case .helpGroup:
            openHelpImpl?()
        case .about:
            pushImpl?(alfaAboutController(context: context))
        case .hiddenAccounts:
            AlfaAuth.authenticate(reason: AlfaCyrillic.ui("Maxfiy akkauntlarni ochish"), completion: { success in
                if success {
                    pushImpl?(alfaHiddenAccountsController(context: context))
                }
            })
        case .autoFolders:
            let _ = (alfaCreateAutoFolders(context: context)
            |> deliverOnMainQueue).start(next: { count in
                let text = count == 0 ? AlfaCyrillic.ui("Barcha avto papkalar allaqachon bor (yoki papkalar soni chegarasiga yetgan).") : AlfaCyrillic.ui("\(count) ta papka qo'shildi. Chatlar ro'yxati tepasida ko'rinadi.")
                presentAlertImpl?(text)
            })
        }
    })

    let signal = combineLatest(context.sharedContext.presentationData, revisionPromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("AlfaGram"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: alfaGramSettingsEntries(), style: .blocks, animateChanges: false)

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    pushImpl = { [weak controller] c in
        controller?.push(c)
    }
    presentAlertImpl = { [weak controller] text in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        controller?.present(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
    }
    openHelpImpl = { [weak controller] in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: "https://t.me/alfagram_chat", forceExternal: false, presentationData: presentationData, navigationController: controller?.navigationController as? NavigationController, dismissInput: {})
    }
    return controller
}
