import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext

private final class AlfaGramSettingsControllerArguments {
    let toggle: (AlfaSettings.Key, Bool) -> Void

    init(toggle: @escaping (AlfaSettings.Key, Bool) -> Void) {
        self.toggle = toggle
    }
}

private enum AlfaGramSettingsSection: Int32 {
    case messages
    case ghost
}

private enum AlfaGramSettingsEntry: ItemListNodeEntry, Equatable {
    case messagesHeader(String)
    case toggle(Int32, AlfaSettings.Key, String, Bool)
    case messagesInfo(String)
    case ghostHeader(String)
    case ghostInfo(String)

    var section: ItemListSectionId {
        switch self {
        case .messagesHeader, .messagesInfo:
            return AlfaGramSettingsSection.messages.rawValue
        case .ghostHeader, .ghostInfo:
            return AlfaGramSettingsSection.ghost.rawValue
        case let .toggle(_, key, _, _):
            switch key {
            case .saveDeletedMessages, .saveEditHistory:
                return AlfaGramSettingsSection.messages.rawValue
            case .ghostOnline, .ghostTyping, .ghostRead:
                return AlfaGramSettingsSection.ghost.rawValue
            }
        }
    }

    var stableId: Int32 {
        switch self {
        case .messagesHeader:
            return 0
        case let .toggle(id, _, _, _):
            return id
        case .messagesInfo:
            return 10
        case .ghostHeader:
            return 11
        case .ghostInfo:
            return 30
        }
    }

    static func <(lhs: AlfaGramSettingsEntry, rhs: AlfaGramSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AlfaGramSettingsControllerArguments
        switch self {
        case let .messagesHeader(text), let .ghostHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .toggle(_, key, title, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(key, value)
            })
        case let .messagesInfo(text), let .ghostInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func alfaGramSettingsEntries() -> [AlfaGramSettingsEntry] {
    var entries: [AlfaGramSettingsEntry] = []
    entries.append(.messagesHeader("XABARLAR"))
    entries.append(.toggle(1, .saveDeletedMessages, "O'chirilgan xabarlarni saqlash", AlfaSettings.saveDeletedMessages))
    entries.append(.toggle(2, .saveEditHistory, "Tahrir tarixini saqlash", AlfaSettings.saveEditHistory))
    entries.append(.messagesInfo("Suhbatdosh o'chirgan xabar chatda qoladi va vaqti yonida 🗑 belgisi chiqadi. Tahrirlangan xabarni bosib turing → \"Tahrir tarixi\" — oldingi matnlar."))
    entries.append(.ghostHeader("GHOST REJIM"))
    entries.append(.toggle(12, .ghostOnline, "Onlayn ko'rinmaslik", AlfaSettings.ghostOnline))
    entries.append(.toggle(13, .ghostTyping, "\"Yozyapti...\" ni yubormaslik", AlfaSettings.ghostTyping))
    entries.append(.toggle(14, .ghostRead, "O'qilganini bildirmaslik", AlfaSettings.ghostRead))
    entries.append(.ghostInfo("Yoqilganda boshqalar sizni onlayn, yozayotgan yoki xabarini o'qigan holda ko'rmaydi. O'qilganlik belgisi faqat shaxsiy chat va guruhlarga tegishli."))
    return entries
}

public func alfaGramSettingsController(context: AccountContext) -> ViewController {
    let revisionPromise = ValuePromise<Int32>(0, ignoreRepeated: false)

    let arguments = AlfaGramSettingsControllerArguments(toggle: { key, value in
        AlfaSettings.setValue(key, value)
        revisionPromise.set(0)
    })

    let signal = combineLatest(context.sharedContext.presentationData, revisionPromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("AlfaGram"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: alfaGramSettingsEntries(), style: .blocks, animateChanges: false)

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    return controller
}
