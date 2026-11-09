import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AlfaGramUI

private enum AlfaGramSettingsAction: Equatable {
    case onlineLog
    case profileLog
    case typingLog
    case helpGroup
}

private final class AlfaGramSettingsControllerArguments {
    let toggle: (AlfaSettings.Key, Bool) -> Void
    let open: (AlfaGramSettingsAction) -> Void

    init(toggle: @escaping (AlfaSettings.Key, Bool) -> Void, open: @escaping (AlfaGramSettingsAction) -> Void) {
        self.toggle = toggle
        self.open = open
    }
}

private enum AlfaGramSettingsEntry: ItemListNodeEntry, Equatable {
    case header(Int32, Int32, String)
    case toggle(Int32, Int32, AlfaSettings.Key, String, Bool)
    case action(Int32, Int32, AlfaGramSettingsAction, String)
    case info(Int32, Int32, String)

    var section: ItemListSectionId {
        switch self {
        case let .header(section, _, _), let .toggle(section, _, _, _, _), let .action(section, _, _, _), let .info(section, _, _):
            return section
        }
    }

    var stableId: Int32 {
        switch self {
        case let .header(_, id, _), let .toggle(_, id, _, _, _), let .action(_, id, _, _), let .info(_, id, _):
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
        case let .toggle(_, _, key, title, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(key, value)
            })
        case let .action(_, _, action, title):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: "", sectionId: self.section, style: .blocks, action: {
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
    entries.append(.toggle(0, next(), .saveDeletedMessages, ui("O'chirilgan xabarlarni saqlash"), AlfaSettings.saveDeletedMessages))
    entries.append(.toggle(0, next(), .saveEditHistory, ui("Tahrir tarixini saqlash"), AlfaSettings.saveEditHistory))
    entries.append(.toggle(0, next(), .showMessageId, ui("Xabar menyusida «ID nusxalash»"), AlfaSettings.showMessageId))
    entries.append(.info(0, next(), ui("Suhbatdosh o'chirgan xabar chatda qoladi va vaqti yonida 🗑 belgisi chiqadi. Tahrirlangan xabarni bosib turing → «Tahrir tarixi» — oldingi matnlar.")))

    entries.append(.header(1, next(), ui("GHOST REJIM")))
    entries.append(.toggle(1, next(), .ghostOnline, ui("Onlayn ko'rinmaslik"), AlfaSettings.ghostOnline))
    entries.append(.toggle(1, next(), .ghostTyping, ui("«Yozyapti...» ni yubormaslik"), AlfaSettings.ghostTyping))
    entries.append(.toggle(1, next(), .ghostRead, ui("O'qilganini bildirmaslik"), AlfaSettings.ghostRead))
    entries.append(.toggle(1, next(), .stealthStories, ui("Story'larni anonim ko'rish"), AlfaSettings.stealthStories))
    entries.append(.info(1, next(), ui("Yoqilganda boshqalar sizni onlayn, yozayotgan, xabarini yoki story'sini ko'rgan holda ko'rmaydi.")))

    entries.append(.header(2, next(), ui("KUZATUV")))
    entries.append(.toggle(2, next(), .onlineLog, ui("Kontaktlar onlayn tarixini yozish"), AlfaSettings.onlineLog))
    entries.append(.action(2, next(), .onlineLog, ui("Onlayn tarixi")))
    entries.append(.toggle(2, next(), .profileLog, ui("Profil o'zgarishlarini yozish"), AlfaSettings.profileLog))
    entries.append(.action(2, next(), .profileLog, ui("Profil o'zgarishlari")))
    entries.append(.toggle(2, next(), .typingLog, ui("«Yozdi, yubormadi» jurnali"), AlfaSettings.typingLog))
    entries.append(.action(2, next(), .typingLog, ui("Yozdi, yubormadi")))
    entries.append(.info(2, next(), ui("Kim qachon onlayn bo'lgani, username, rasm yoki raqamini o'zgartirgani va sizga yozib, yubormagani. Hammasi faqat telefoningizda saqlanadi.")))

    entries.append(.header(3, next(), ui("XAVFSIZLIK")))
    entries.append(.toggle(3, next(), .linkGuard, ui("Shubhali havolalardan ogohlantirish"), AlfaSettings.linkGuard))
    entries.append(.toggle(3, next(), .blockAds, ui("Telegram reklamalarini yashirish"), AlfaSettings.blockAds))
    entries.append(.info(3, next(), ui("Soxta bank, Click, Payme yoki Telegram saytlari, APK yuklovchi va «sovg'a» va'da qiluvchi havolalarni ochishdan oldin ogohlantiradi.")))

    entries.append(.header(6, next(), ui("CHEKLOVSIZ")))
    entries.append(.toggle(6, next(), .unrestrictedSave, ui("Taqiqlangan chatlardan saqlash"), AlfaSettings.unrestrictedSave))
    entries.append(.info(6, next(), ui("Saqlash va nusxa olish yopilgan chatlarda ham rasm, video va matnni saqlash, skrinshot olish. Forward'ni Telegram serveri baribir bloklashi mumkin.")))

    entries.append(.header(4, next(), ui("TIL")))
    entries.append(.toggle(4, next(), .cyrillicUi, ui("Kirill alifbosi (Ўзбекча)"), AlfaSettings.cyrillicUi))
    entries.append(.toggle(4, next(), .sendCyrillic, ui("Lotincha yozsam, kirillda yuborilsin"), AlfaSettings.sendCyrillic))
    entries.append(.info(4, next(), ui("O'zbek tili tanlangan bo'lsa, ilova kirillda ko'rinadi. Tilni Sozlamalar → Til bo'limidan tanlang.")))

    entries.append(.header(5, next(), ui("ALFAGRAM")))
    entries.append(.action(5, next(), .helpGroup, ui("Yordam guruhi (@alfagram_chat)")))
    entries.append(.info(5, next(), ui("Savol, taklif va xatolar haqida yozing.")))
    return entries
}

public func alfaGramSettingsController(context: AccountContext) -> ViewController {
    let revisionPromise = ValuePromise<Int32>(0, ignoreRepeated: false)
    var pushImpl: ((ViewController) -> Void)?
    var openHelpImpl: (() -> Void)?

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
    openHelpImpl = { [weak controller] in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: "https://t.me/alfagram_chat", forceExternal: false, presentationData: presentationData, navigationController: controller?.navigationController as? NavigationController, dismissInput: {})
    }
    return controller
}
