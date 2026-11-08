import Foundation
import Postbox

/// AlfaGram: set on a stored message the server reported deleted while `AlfaSettings.saveDeletedMessages` was on.
/// The message is kept instead of deleted; `date` is when the deletion arrived.
public final class AlfaDeletedMessageAttribute: MessageAttribute {
    public let date: Int32

    public init(date: Int32) {
        self.date = date
    }

    required public init(decoder: PostboxDecoder) {
        self.date = decoder.decodeInt32ForKey("d", orElse: 0)
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.date, forKey: "d")
    }
}

/// AlfaGram: the earlier texts of an edited message, oldest first, each with the time it was replaced.
public final class AlfaEditHistoryMessageAttribute: MessageAttribute {
    public struct Entry: Equatable {
        public let text: String
        public let date: Int32

        public init(text: String, date: Int32) {
            self.text = text
            self.date = date
        }
    }

    public let entries: [Entry]

    public init(entries: [Entry]) {
        self.entries = entries
    }

    required public init(decoder: PostboxDecoder) {
        let texts = decoder.decodeStringArrayForKey("t")
        let dates = decoder.decodeInt32ArrayForKey("d")
        var entries: [Entry] = []
        for i in 0 ..< min(texts.count, dates.count) {
            entries.append(Entry(text: texts[i], date: dates[i]))
        }
        self.entries = entries
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeStringArray(self.entries.map { $0.text }, forKey: "t")
        encoder.encodeInt32Array(self.entries.map { $0.date }, forKey: "d")
    }
}

public extension Message {
    /// AlfaGram: when the server reported this message deleted, if it was kept.
    var alfaDeletedDate: Int32? {
        for attribute in self.attributes {
            if let attribute = attribute as? AlfaDeletedMessageAttribute {
                return attribute.date
            }
        }
        return nil
    }

    /// AlfaGram: the earlier texts of this message, oldest first.
    var alfaEditHistory: [AlfaEditHistoryMessageAttribute.Entry] {
        for attribute in self.attributes {
            if let attribute = attribute as? AlfaEditHistoryMessageAttribute {
                return attribute.entries
            }
        }
        return []
    }
}

/// The most edit-history entries a message keeps; older ones are dropped.
private let alfaEditHistoryLimit = 20

private func alfaStoreMessage(_ message: Message, attributes: [MessageAttribute]) -> StoreMessage {
    return StoreMessage(id: message.id, customStableId: nil, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, threadId: message.threadId, timestamp: message.timestamp, flags: StoreMessageFlags(message.flags), tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo.flatMap(StoreMessageForwardInfo.init), authorId: message.author?.id, text: message.text, attributes: attributes, media: message.media)
}

private func alfaCanKeepDeletedMessage(_ id: MessageId) -> Bool {
    guard id.namespace == Namespaces.Message.Cloud else {
        return false
    }
    switch id.peerId.namespace {
    case Namespaces.Peer.CloudUser, Namespaces.Peer.CloudGroup, Namespaces.Peer.CloudChannel:
        return true
    default:
        return false
    }
}

/// AlfaGram: with `AlfaSettings.saveDeletedMessages` on, keeps the stored Cloud messages among `ids` (private chats,
/// groups, channels) and marks them `AlfaDeletedMessageAttribute` instead of letting them be deleted. Returns the ids
/// that must still be deleted the usual way: all of them with the setting off, else the ones not stored here or in
/// another namespace (scheduled, quick replies, local). A message already marked is left as it is.
func alfaKeepDeletedMessages(transaction: Transaction, ids: [MessageId]) -> [MessageId] {
    if ids.isEmpty || !AlfaSettings.saveDeletedMessages {
        return ids
    }
    let timestamp = Int32(Date().timeIntervalSince1970)
    var remaining: [MessageId] = []
    for id in ids {
        guard alfaCanKeepDeletedMessage(id), let message = transaction.getMessage(id) else {
            remaining.append(id)
            continue
        }
        if message.alfaDeletedDate != nil {
            continue
        }
        transaction.updateMessage(id, update: { current in
            var attributes = current.attributes
            attributes.append(AlfaDeletedMessageAttribute(date: timestamp))
            return .update(alfaStoreMessage(current, attributes: attributes))
        })
    }
    return remaining
}

/// AlfaGram: `updated` (the server's copy of an edited message) with the text it replaces added to its edit
/// history, when `AlfaSettings.saveEditHistory` is on and the text changed.
func alfaMessageWithEditHistory(previous: Message, updated: StoreMessage) -> StoreMessage {
    if !AlfaSettings.saveEditHistory || previous.text == updated.text || previous.text.isEmpty {
        return updated
    }
    var entries = previous.alfaEditHistory
    let replacedAt = updated.attributes.compactMap({ ($0 as? EditedMessageAttribute)?.date }).first ?? Int32(Date().timeIntervalSince1970)
    entries.append(AlfaEditHistoryMessageAttribute.Entry(text: previous.text, date: replacedAt))
    if entries.count > alfaEditHistoryLimit {
        entries.removeFirst(entries.count - alfaEditHistoryLimit)
    }
    var attributes = updated.attributes.filter { !($0 is AlfaEditHistoryMessageAttribute) }
    attributes.append(AlfaEditHistoryMessageAttribute(entries: entries))
    return updated.withUpdatedAttributes(attributes)
}

/// AlfaGram: keeps an edit history across every update of a stored message (the server's copy never carries it);
/// called from `SeedConfiguration.mergeMessageAttributes`.
func alfaMergeMessageAttributes(previous: [MessageAttribute], updated: inout [MessageAttribute]) {
    if updated.contains(where: { $0 is AlfaEditHistoryMessageAttribute }) {
        return
    }
    for attribute in previous {
        if let attribute = attribute as? AlfaEditHistoryMessageAttribute {
            updated.append(attribute)
            return
        }
    }
}
