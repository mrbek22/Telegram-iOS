import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit

/// AlfaGram: one message of a chat export.
public struct AlfaExportedMessage {
    public enum MediaKind {
        case photo
        case video
        case voice
        case roundVideo
        case sticker
        case gif
        case file(String)
        case service
        case other
    }

    public let id: Int32
    public let date: Int32
    public let author: String
    public let isOutgoing: Bool
    public let text: String
    public let media: MediaKind?
}

private func alfaExportPeerTitle(_ peer: Peer) -> String {
    if let user = peer as? TelegramUser {
        let name = [user.firstName ?? "", user.lastName ?? ""].filter { !$0.isEmpty }.joined(separator: " ")
        if !name.isEmpty {
            return name
        }
        return user.addressName ?? ""
    } else if let group = peer as? TelegramGroup {
        return group.title
    } else if let channel = peer as? TelegramChannel {
        return channel.title
    }
    return ""
}

private func alfaExportMediaKind(_ media: [Media]) -> AlfaExportedMessage.MediaKind? {
    for item in media {
        if item is TelegramMediaImage {
            return .photo
        } else if let file = item as? TelegramMediaFile {
            if file.isVoice {
                return .voice
            } else if file.isInstantVideo {
                return .roundVideo
            } else if file.isSticker {
                return .sticker
            } else if file.isAnimated {
                return .gif
            } else if file.isVideo {
                return .video
            } else {
                return .file(file.fileName ?? "")
            }
        } else if item is TelegramMediaAction {
            return .service
        } else if !(item is TelegramMediaWebpage) {
            return .other
        }
    }
    return nil
}

/// AlfaGram: downloads a chat's history from the server, newest first, up to `limit` messages (pages of 100).
public func alfaFetchChatHistoryForExport(account: Account, peerId: PeerId, limit: Int) -> Signal<[AlfaExportedMessage], NoError> {
    return account.postbox.transaction { transaction -> (Peer, Api.InputPeer)? in
        guard let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) else {
            return nil
        }
        return (peer, inputPeer)
    }
    |> mapToSignal { data -> Signal<[AlfaExportedMessage], NoError> in
        guard let data else {
            return .single([])
        }
        return alfaFetchExportPage(account: account, peer: data.0, inputPeer: data.1, offsetId: 0, collected: [], limit: limit)
    }
}

private func alfaFetchExportPage(account: Account, peer: Peer, inputPeer: Api.InputPeer, offsetId: Int32, collected: [AlfaExportedMessage], limit: Int) -> Signal<[AlfaExportedMessage], NoError> {
    return account.network.request(Api.functions.messages.getHistory(peer: inputPeer, offsetId: offsetId, offsetDate: 0, addOffset: 0, limit: 100, maxId: 0, minId: 0, hash: 0))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.messages.Messages?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<[AlfaExportedMessage], NoError> in
        guard let result else {
            return .single(collected)
        }
        let messages: [Api.Message]
        let chats: [Api.Chat]
        let users: [Api.User]
        switch result {
        case let .messages(messagesData):
            messages = messagesData.messages
            chats = messagesData.chats
            users = messagesData.users
        case let .messagesSlice(messagesSliceData):
            messages = messagesSliceData.messages
            chats = messagesSliceData.chats
            users = messagesSliceData.users
        case let .channelMessages(channelMessagesData):
            messages = channelMessagesData.messages
            chats = channelMessagesData.chats
            users = channelMessagesData.users
        case .messagesNotModified:
            messages = []
            chats = []
            users = []
        }

        var peers: [PeerId: Peer] = [peer.id: peer]
        for chat in chats {
            if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                peers[groupOrChannel.id] = groupOrChannel
            }
        }
        for user in users {
            let telegramUser = TelegramUser(user: user)
            peers[telegramUser.id] = telegramUser
        }

        var batch: [AlfaExportedMessage] = []
        var oldestId: Int32 = 0
        for apiMessage in messages {
            guard let storeMessage = StoreMessage(apiMessage: apiMessage, accountPeerId: account.peerId, peerIsForum: peer.isForum), case let .Id(id) = storeMessage.id else {
                continue
            }
            oldestId = id.id
            var author = ""
            if let authorId = storeMessage.authorId, let authorPeer = peers[authorId] {
                author = alfaExportPeerTitle(authorPeer)
            } else {
                author = alfaExportPeerTitle(peer)
            }
            batch.append(AlfaExportedMessage(id: id.id, date: storeMessage.timestamp, author: author, isOutgoing: !storeMessage.flags.contains(.Incoming), text: storeMessage.text, media: alfaExportMediaKind(storeMessage.media)))
        }

        let updated = collected + batch
        if batch.isEmpty || oldestId == 0 || updated.count >= limit {
            return .single(updated)
        }
        return alfaFetchExportPage(account: account, peer: peer, inputPeer: inputPeer, offsetId: oldestId, collected: updated, limit: limit)
    }
}
