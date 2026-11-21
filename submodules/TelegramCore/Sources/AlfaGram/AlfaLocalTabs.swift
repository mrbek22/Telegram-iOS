import Foundation
import Postbox
import SwiftSignalKit

/// AlfaGram: automatic chat list tabs (Personal / Mutual contacts / Groups / Channels / Bots) that live only on
/// this device. They are never written to the account's folders, and they are shown only while the user has no
/// folders of their own — as soon as the account has a real folder, the user's folders are shown untouched.
public enum AlfaLocalTabs {
    /// Local tab ids: far outside the server's folder id range (2…255).
    public static let personalId: Int32 = 1_000_001
    public static let mutualId: Int32 = 1_000_002
    public static let groupsId: Int32 = 1_000_003
    public static let channelsId: Int32 = 1_000_004
    public static let botsId: Int32 = 1_000_005

    public static func isLocal(_ id: Int32) -> Bool {
        return id >= personalId && id <= botsId
    }

    public static func isLocal(_ filter: ChatListFilter) -> Bool {
        return isLocal(filter.id)
    }

    /// The monochrome icon (SF Symbol) a local tab shows in the chat list instead of its emoji title.
    public static func symbolName(_ id: Int32) -> String? {
        switch id {
        case personalId:
            return "person.fill"
        case groupsId:
            return "person.2.fill"
        case channelsId:
            return "megaphone.fill"
        case botsId:
            return "face.smiling"
        default:
            return nil
        }
    }

    /// Telegram's own folder icon (TelegramUI asset) a local tab shows in the chat list — the same icons as
    /// Telegram's folder types: a person, two people (groups), a megaphone (channels), a robot (bots).
    public static func iconName(_ id: Int32) -> String? {
        switch id {
        case personalId:
            return "Chat List/Filters/Contact"
        case groupsId:
            return "Chat List/Filters/Group"
        case channelsId:
            return "Chat List/Filters/Channel"
        case botsId:
            return "Chat List/Filters/Bot"
        default:
            return nil
        }
    }

    /// Removes the local tabs (for screens that edit the account's real folders).
    public static func withoutLocal(_ filters: [ChatListFilter]) -> [ChatListFilter] {
        return filters.filter { !isLocal($0.id) }
    }

    static func hasOwnFolders(_ filters: [ChatListFilter]) -> Bool {
        for filter in filters {
            if case .filter = filter {
                return true
            }
        }
        return false
    }

    private static func tab(id: Int32, icon: String, categories: ChatListFilterPeerCategories, includePeers: [PeerId] = []) -> ChatListFilter {
        return .filter(
            id: id,
            title: ChatFolderTitle(text: icon, entities: [], enableAnimations: true),
            emoticon: icon,
            data: ChatListFilterData(
                isShared: false,
                hasSharedLinks: false,
                categories: categories,
                excludeMuted: false,
                excludeRead: false,
                excludeArchived: true,
                includePeers: ChatListFilterIncludePeers(peers: includePeers, pinnedPeers: []),
                excludePeers: [],
                color: nil
            )
        )
    }

    /// People / Groups / Channels / Bots (the mutual-contacts tab was dropped, user 2026-11-21).
    static func tabs() -> [ChatListFilter] {
        var result: [ChatListFilter] = []
        result.append(tab(id: personalId, icon: "👤", categories: [.contacts, .nonContacts]))
        result.append(tab(id: groupsId, icon: "👥", categories: [.groups]))
        result.append(tab(id: channelsId, icon: "📢", categories: [.channels]))
        result.append(tab(id: botsId, icon: "🤖", categories: [.bots]))
        return result
    }
}

/// Adds the local tabs to the account's chat list filters while the account has no folders of its own.
func alfaWithLocalChatListTabs(postbox: Postbox, _ filters: Signal<[ChatListFilter], NoError>) -> Signal<[ChatListFilter], NoError> {
    let _ = postbox
    return filters
    |> map { filters -> [ChatListFilter] in
        if AlfaLocalTabs.hasOwnFolders(filters) {
            return filters
        }
        var result = filters
        if !result.contains(where: { if case .allChats = $0 { return true } else { return false } }) {
            result.insert(.allChats, at: 0)
        }
        result.append(contentsOf: AlfaLocalTabs.tabs())
        return result
    }
    |> distinctUntilChanged
}
