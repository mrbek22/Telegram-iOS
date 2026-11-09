import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import LocalizedPeerData
import TextFormat

// AlfaGram: on-device log screens — profile changes, online history, "typed but did not send".

private final class AlfaLogArguments {
    let context: AccountContext
    let openPeer: (EnginePeer) -> Void
    let openSessions: (EnginePeer) -> Void

    init(context: AccountContext, openPeer: @escaping (EnginePeer) -> Void, openSessions: @escaping (EnginePeer) -> Void) {
        self.context = context
        self.openPeer = openPeer
        self.openSessions = openSessions
    }
}

private enum AlfaLogEntry: ItemListNodeEntry, Equatable {
    case header(Int32, Int32, String)
    case row(Int32, Int32, EnginePeer?, String, String, String, Bool)
    case info(Int32, Int32, String)

    var section: ItemListSectionId {
        switch self {
        case let .header(section, _, _), let .row(section, _, _, _, _, _, _), let .info(section, _, _):
            return section
        }
    }

    var stableId: Int32 {
        switch self {
        case let .header(_, id, _), let .row(_, id, _, _, _, _, _), let .info(_, id, _):
            return id
        }
    }

    static func <(lhs: AlfaLogEntry, rhs: AlfaLogEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AlfaLogArguments
        switch self {
        case let .header(_, _, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .row(_, _, peer, title, label, detail, opensSessions):
            var action: (() -> Void)?
            if let peer = peer {
                action = {
                    if opensSessions {
                        arguments.openSessions(peer)
                    } else {
                        arguments.openPeer(peer)
                    }
                }
            }
            let itemContext: AccountContext? = peer == nil ? nil : arguments.context
            let detailLabel: String? = detail.isEmpty ? nil : detail
            let disclosure: ItemListDisclosureStyle = opensSessions ? .arrow : .none
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, context: itemContext, iconPeer: peer, title: title, label: label, additionalDetailLabel: detailLabel, sectionId: self.section, style: .blocks, disclosureStyle: disclosure, action: action)
        case let .info(_, _, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func alfaUi(_ s: String) -> String {
    return AlfaCyrillic.ui(s)
}

private func alfaDayTitle(_ timestamp: Int32) -> String {
    let calendar = Calendar.current
    let date = Date(timeIntervalSince1970: Double(timestamp))
    if calendar.isDateInToday(date) {
        return alfaUi("Bugun")
    }
    if calendar.isDateInYesterday(date) {
        return alfaUi("Kecha")
    }
    let formatter = DateFormatter()
    formatter.dateFormat = "dd.MM.yyyy"
    return formatter.string(from: date)
}

private func alfaDayKey(_ timestamp: Int32) -> Int {
    let components = Calendar.current.dateComponents([.year, .month, .day], from: Date(timeIntervalSince1970: Double(timestamp)))
    return (components.year ?? 0) * 10000 + (components.month ?? 0) * 100 + (components.day ?? 0)
}

private func alfaDuration(_ seconds: Int32) -> String {
    let minutes = max(1, Int(seconds) / 60)
    if minutes < 60 {
        return alfaUi("\(minutes) daq")
    }
    return alfaUi("\(minutes / 60) soat \(minutes % 60) daq")
}

private func alfaPeerName(_ peer: EnginePeer?, _ peerId: EnginePeer.Id, _ presentationData: PresentationData) -> String {
    if let peer = peer {
        let title = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
        if !title.isEmpty {
            return title
        }
    }
    return "ID \(peerId.id._internalGetInt64Value())"
}

private func alfaLogUpdates() -> Signal<Void, NoError> {
    let updates = Signal<Void, NoError> { subscriber in
        let token = NotificationCenter.default.addObserver(forName: alfaLogsDidChangeNotification, object: nil, queue: OperationQueue.main, using: { _ in
            subscriber.putNext(Void())
        })
        return ActionDisposable {
            NotificationCenter.default.removeObserver(token)
        }
    }
    return .single(Void()) |> then(updates)
}

private func alfaPeers(context: AccountContext, ids: [EnginePeer.Id]) -> Signal<[EnginePeer.Id: EnginePeer], NoError> {
    if ids.isEmpty {
        return .single([:])
    }
    return context.engine.data.get(EngineDataMap(ids.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:))))
    |> map { result -> [EnginePeer.Id: EnginePeer] in
        var peers: [EnginePeer.Id: EnginePeer] = [:]
        for (id, peer) in result {
            if let peer = peer {
                peers[id] = peer
            }
        }
        return peers
    }
}

private func alfaOpenChat(context: AccountContext, controller: ViewController?, peer: EnginePeer) {
    guard let navigationController = controller?.navigationController as? NavigationController else {
        return
    }
    context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer)))
}

private func alfaConfirmClear(context: AccountContext, controller: ViewController?, clear: @escaping () -> Void) {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    controller?.present(textAlertController(context: context, title: alfaUi("Tarixni tozalash"), text: alfaUi("Barcha yozuvlar o'chiriladi. Yangilari yozilishda davom etadi."), actions: [
        TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
        TextAlertAction(type: .destructiveAction, title: alfaUi("Tozalash"), action: {
            clear()
        })
    ]), in: .window(.root))
}

/// The common list screen: `build` turns the presentation data and the resolved peers into entries.
private func alfaLogController(
    context: AccountContext,
    title: String,
    peerIds: @escaping () -> [EnginePeer.Id],
    build: @escaping (PresentationData, [EnginePeer.Id: EnginePeer]) -> [AlfaLogEntry],
    clear: (() -> Void)?,
    openSessions: ((ViewController?, EnginePeer) -> Void)? = nil
) -> ViewController {
    var controllerRef: (() -> ViewController?)?
    let arguments = AlfaLogArguments(context: context, openPeer: { peer in
        alfaOpenChat(context: context, controller: controllerRef?(), peer: peer)
    }, openSessions: { peer in
        openSessions?(controllerRef?(), peer)
    })

    let data = alfaLogUpdates()
    |> mapToSignal { _ -> Signal<[EnginePeer.Id: EnginePeer], NoError> in
        return alfaPeers(context: context, ids: peerIds())
    }

    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, data)
    |> map { presentationData, peers -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var rightButton: ItemListNavigationButton?
        if let clear = clear {
            rightButton = ItemListNavigationButton(content: .text(alfaUi("Tozalash")), style: .regular, enabled: true, action: {
                alfaConfirmClear(context: context, controller: controllerRef?(), clear: clear)
            })
        }
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: nil, rightNavigationButton: rightButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: build(presentationData, peers), style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    controllerRef = { [weak controller] in
        return controller
    }
    return controller
}

// MARK: - Profile changes

private func alfaDescribe(_ entry: AlfaProfileLog.Entry) -> String {
    switch entry.field {
    case .name:
        return alfaUi("Ismini o'zgartirdi: ") + entry.oldValue + " → " + entry.newValue
    case .username:
        if entry.oldValue.isEmpty {
            return alfaUi("Username qo'ydi: ") + "@" + entry.newValue
        }
        if entry.newValue.isEmpty {
            return alfaUi("Username'ni olib tashladi: ") + "@" + entry.oldValue
        }
        return "@" + entry.oldValue + " → @" + entry.newValue
    case .photo:
        return alfaUi("Profil rasmini o'zgartirdi")
    case .photoRemoved:
        return alfaUi("Profil rasmini olib tashladi yoki yashirdi")
    case .phone:
        return alfaUi("Telefon raqami o'zgardi: ") + "+" + entry.oldValue + " → +" + entry.newValue
    }
}

public func alfaProfileLogController(context: AccountContext) -> ViewController {
    let accountPeerId = context.account.peerId
    return alfaLogController(context: context, title: alfaUi("Profil o'zgarishlari"), peerIds: {
        return Array(Set(AlfaProfileLog.entries(accountPeerId: accountPeerId).map { $0.peerId }))
    }, build: { presentationData, peers in
        let entries = AlfaProfileLog.entries(accountPeerId: accountPeerId)
        var result: [AlfaLogEntry] = []
        var id: Int32 = 0
        if entries.isEmpty {
            result.append(.info(0, 0, alfaUi("Hozircha o'zgarish yo'q. Kontaktlaringiz yoki yozishgan odamlaringiz username'ini, profil rasmini yoki raqamini o'zgartirsa, shu yerda ko'rinadi. Ma'lumot faqat telefoningizda saqlanadi.")))
            return result
        }
        var section: Int32 = -1
        var lastDay = -1
        for entry in entries {
            let day = alfaDayKey(entry.time)
            if day != lastDay {
                lastDay = day
                section += 1
                id += 1
                result.append(.header(section, id, alfaDayTitle(entry.time).uppercased()))
            }
            id += 1
            let peer = peers[entry.peerId]
            let time = stringForMessageTimestamp(timestamp: entry.time, dateTimeFormat: presentationData.dateTimeFormat)
            result.append(.row(section, id, peer, alfaPeerName(peer, entry.peerId, presentationData), time, alfaDescribe(entry), false))
        }
        return result
    }, clear: {
        AlfaProfileLog.clear(accountPeerId: accountPeerId)
    })
}

// MARK: - Online history

public func alfaOnlineLogController(context: AccountContext) -> ViewController {
    let accountPeerId = context.account.peerId
    AlfaOnlineLog.startPolling(account: context.account)
    return alfaLogController(context: context, title: alfaUi("Onlayn tarixi"), peerIds: {
        return AlfaOnlineLog.users(accountPeerId: accountPeerId).map { $0.peerId }
    }, build: { presentationData, peers in
        let users = AlfaOnlineLog.users(accountPeerId: accountPeerId)
        var result: [AlfaLogEntry] = []
        if users.isEmpty {
            result.append(.info(0, 0, alfaUi("Hozircha yozuv yo'q. Kontaktlaringiz qachon onlayn bo'lgani ilova internetga ulangan paytda yozib boriladi. Ma'lumot faqat telefoningizda saqlanadi.")))
            return result
        }
        var id: Int32 = 1
        result.append(.header(0, id, alfaUi("KONTAKTLAR")))
        for user in users {
            id += 1
            let peer = peers[user.peerId]
            let label: String
            if user.isOnline {
                label = alfaUi("onlayn")
            } else {
                label = alfaDayTitle(user.lastSeen) + " " + stringForMessageTimestamp(timestamp: user.lastSeen, dateTimeFormat: presentationData.dateTimeFormat)
            }
            result.append(.row(0, id, peer, alfaPeerName(peer, user.peerId, presentationData), label, "", true))
        }
        id += 1
        result.append(.info(0, id, alfaUi("Bosing — o'sha odam qachon va qancha vaqt onlayn bo'lgani.")))
        return result
    }, clear: {
        AlfaOnlineLog.clear(accountPeerId: accountPeerId)
    }, openSessions: { controller, peer in
        controller?.push(alfaOnlineSessionsController(context: context, peer: peer))
    })
}

public func alfaOnlineSessionsController(context: AccountContext, peer: EnginePeer) -> ViewController {
    let accountPeerId = context.account.peerId
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    return alfaLogController(context: context, title: alfaPeerName(peer, peer.id, presentationData), peerIds: {
        return []
    }, build: { presentationData, _ in
        let sessions = AlfaOnlineLog.sessions(accountPeerId: accountPeerId, userId: peer.id)
        var result: [AlfaLogEntry] = []
        if sessions.isEmpty {
            result.append(.info(0, 0, alfaUi("Hozircha yozuv yo'q.")))
            return result
        }
        let now = Int32(Date().timeIntervalSince1970)
        var section: Int32 = -1
        var lastDay = -1
        var id: Int32 = 0
        for session in sessions {
            let day = alfaDayKey(session.start)
            if day != lastDay {
                lastDay = day
                section += 1
                id += 1
                result.append(.header(section, id, alfaDayTitle(session.start).uppercased()))
            }
            id += 1
            let startText = stringForMessageTimestamp(timestamp: session.start, dateTimeFormat: presentationData.dateTimeFormat)
            let title: String
            let label: String
            if session.end == 0 && now - session.seen <= AlfaOnlineLog.gap {
                title = startText + " — " + alfaUi("hozir")
                label = alfaUi("onlayn")
            } else if session.end == session.start && session.seen == session.start {
                title = alfaUi("Oxirgi marta: ") + startText
                label = ""
            } else {
                let end = session.end == 0 ? session.seen : session.end
                title = startText + " — " + stringForMessageTimestamp(timestamp: end, dateTimeFormat: presentationData.dateTimeFormat)
                label = alfaDuration(end - session.start)
            }
            result.append(.row(section, id, nil, title, label, "", false))
        }
        return result
    }, clear: nil)
}

// MARK: - Typed but did not send

public func alfaTypingLogController(context: AccountContext) -> ViewController {
    let accountPeerId = context.account.peerId
    return alfaLogController(context: context, title: alfaUi("Yozdi, yubormadi"), peerIds: {
        return Array(Set(AlfaTypingLog.unsent(accountPeerId: accountPeerId).map { $0.peerId }))
    }, build: { presentationData, peers in
        let entries = AlfaTypingLog.unsent(accountPeerId: accountPeerId)
        var result: [AlfaLogEntry] = []
        if entries.isEmpty {
            result.append(.info(0, 0, alfaUi("Hozircha yozuv yo'q. Kimdir shaxsiy chatda sizga yozishni boshlab, keyin yubormasa, shu yerda ko'rinadi.")))
            return result
        }
        var section: Int32 = -1
        var lastDay = -1
        var id: Int32 = 0
        for entry in entries {
            let day = alfaDayKey(entry.time)
            if day != lastDay {
                lastDay = day
                section += 1
                id += 1
                result.append(.header(section, id, alfaDayTitle(entry.time).uppercased()))
            }
            id += 1
            let peer = peers[entry.peerId]
            let time = stringForMessageTimestamp(timestamp: entry.time, dateTimeFormat: presentationData.dateTimeFormat)
            let seconds = max(1, entry.lastTyping - entry.time)
            result.append(.row(section, id, peer, alfaPeerName(peer, entry.peerId, presentationData), time, alfaUi("Yozdi (\(seconds) soniya), lekin yubormadi"), false))
        }
        return result
    }, clear: {
        AlfaTypingLog.clear(accountPeerId: accountPeerId)
    })
}
