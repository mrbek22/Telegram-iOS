import Foundation
import SwiftSignalKit
import TelegramCore
import AccountContext

/// AlfaGram: one tap creates the folders Shaxsiy, Guruhlar, Kanallar, Botlar, O'qilmagan (skipping those that
/// already exist, within the 10-folder limit). The result is the number of folders added.
public func alfaCreateAutoFolders(context: AccountContext) -> Signal<Int, NoError> {
    let all: ChatListFilterPeerCategories = [.contacts, .nonContacts, .groups, .channels, .bots]
    let templates: [(String, String, ChatListFilterPeerCategories, Bool)] = [
        ("Shaxsiy", "👤", [.contacts, .nonContacts], false),
        ("Guruhlar", "👥", [.groups], false),
        ("Kanallar", "📢", [.channels], false),
        ("Botlar", "🤖", [.bots], false),
        ("O'qilmagan", "✅", all, true)
    ]
    let maxFolders = 10
    let added = Atomic<Int>(value: 0)
    return context.engine.peers.updateChatListFiltersInteractively { filters in
        var filters = filters
        var existingTitles = Set<String>()
        var count = 0
        var nextId: Int32 = 2
        for filter in filters {
            if case let .filter(id, title, _, _) = filter {
                existingTitles.insert(title.text.lowercased())
                count += 1
                nextId = max(nextId, id + 1)
            }
        }
        var addedCount = 0
        for (rawTitle, emoticon, categories, excludeRead) in templates {
            let title = AlfaCyrillic.ui(rawTitle)
            if existingTitles.contains(title.lowercased()) || existingTitles.contains(rawTitle.lowercased()) {
                continue
            }
            if count >= maxFolders {
                break
            }
            let data = ChatListFilterData(isShared: false, hasSharedLinks: false, categories: categories, excludeMuted: false, excludeRead: excludeRead, excludeArchived: true, includePeers: ChatListFilterIncludePeers(), excludePeers: [], color: nil)
            filters.append(.filter(id: nextId, title: ChatFolderTitle(text: title, entities: [], enableAnimations: true), emoticon: emoticon, data: data))
            nextId += 1
            count += 1
            addedCount += 1
        }
        let _ = added.swap(addedCount)
        return filters
    }
    |> map { _ -> Int in
        return added.with { $0 }
    }
}
