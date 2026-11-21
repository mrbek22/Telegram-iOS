import Foundation
import Postbox
import CryptoKit

/// AlfaGram: hidden chats — gone from the chat lists (and the forward picker), muted, and without notifications.
/// They show again after the user enters the hidden chats' own code (a 4-digit PIN or a password) — until the app
/// goes to the background. The list lives in the App Group's defaults, so the NotificationService sees it too.
public enum AlfaHiddenChats {
    private static let listKey = "alfa_hidden_chats"
    private static let codeKey = "alfa_hidden_chats_code"
    private static let numericKey = "alfa_hidden_chats_numeric"

    /// Posted by the chat list title's long press: the chat list asks for the code.
    public static let revealRequestNotification = Notification.Name("AlfaHiddenChatsRevealRequest")
    /// Posted when the hidden list or the revealed state changes: the chat lists redraw.
    public static let didChangeNotification = Notification.Name("AlfaHiddenChatsDidChange")

    private static let cacheLock = NSLock()
    private static var listCache: Set<String>?
    private static var revealed = false

    private static func entry(_ accountPeerId: PeerId, _ peerId: PeerId) -> String {
        return "\(accountPeerId.toInt64()):\(peerId.toInt64())"
    }

    private static func hash(_ code: String) -> String {
        let digest = SHA256.hash(data: Data(("alfagram.hidden." + code).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: code

    /// The feature is on once a code is set.
    public static var isEnabled: Bool {
        return AlfaSharedDefaults.value.string(forKey: codeKey) != nil
    }

    /// The code is a 4-digit PIN (otherwise a letters-and-digits password).
    public static var isNumericCode: Bool {
        return AlfaSharedDefaults.value.bool(forKey: numericKey)
    }

    public static func setCode(_ code: String, numeric: Bool) {
        AlfaSharedDefaults.value.set(hash(code), forKey: codeKey)
        AlfaSharedDefaults.value.set(numeric, forKey: numericKey)
        notifyChanged()
    }

    public static func checkCode(_ code: String) -> Bool {
        guard let stored = AlfaSharedDefaults.value.string(forKey: codeKey) else {
            return false
        }
        return stored == hash(code)
    }

    /// Turns the feature off: the code is removed and every hidden chat shows again.
    public static func disable() {
        AlfaSharedDefaults.value.removeObject(forKey: codeKey)
        AlfaSharedDefaults.value.removeObject(forKey: numericKey)
        AlfaSharedDefaults.value.removeObject(forKey: listKey)
        cacheLock.lock()
        listCache = []
        revealed = false
        cacheLock.unlock()
        notifyChanged()
    }

    // MARK: revealed state (this app session only)

    public static var isRevealed: Bool {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return revealed
    }

    public static func setRevealed(_ value: Bool) {
        cacheLock.lock()
        let changed = revealed != value
        revealed = value
        cacheLock.unlock()
        if changed {
            notifyChanged()
        }
    }

    // MARK: the list

    private static func list() -> Set<String> {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let listCache {
            return listCache
        }
        let value = Set(AlfaSharedDefaults.value.stringArray(forKey: listKey) ?? [])
        listCache = value
        return value
    }

    public static func isHidden(accountPeerId: PeerId, peerId: PeerId) -> Bool {
        let set = list()
        if set.isEmpty {
            return false
        }
        return set.contains(entry(accountPeerId, peerId))
    }

    /// Hidden and not revealed right now: the chat lists leave it out.
    public static func isHiddenNow(accountPeerId: PeerId, peerId: PeerId) -> Bool {
        if isRevealed {
            return false
        }
        return isHidden(accountPeerId: accountPeerId, peerId: peerId)
    }

    public static func setHidden(accountPeerId: PeerId, peerId: PeerId, hidden: Bool) {
        let value = entry(accountPeerId, peerId)
        var items = list()
        if hidden {
            items.insert(value)
        } else {
            items.remove(value)
        }
        AlfaSharedDefaults.value.set(Array(items), forKey: listKey)
        cacheLock.lock()
        listCache = items
        cacheLock.unlock()
        notifyChanged()
    }

    private static func notifyChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: didChangeNotification, object: nil)
        }
    }
}
