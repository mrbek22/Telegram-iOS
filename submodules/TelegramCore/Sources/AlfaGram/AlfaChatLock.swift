import Foundation
import Postbox
import SwiftSignalKit

/// AlfaGram: chats locked behind Face ID / Touch ID / the device passcode.
/// A locked chat opens only after authentication and stays open until the app goes to the background.
/// Kept in the app's standard `UserDefaults`, as "<account peer id>:<chat peer id>" strings.
public enum AlfaChatLock {
    private static let lockedKey = "alfa_locked_chats"
    private static let unlockedKey = "alfa_unlocked_chats"

    private static func entry(_ accountPeerId: PeerId, _ peerId: PeerId) -> String {
        return "\(accountPeerId.toInt64()):\(peerId.toInt64())"
    }

    private static func list(_ key: String) -> [String] {
        return UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    public static func isLocked(accountPeerId: PeerId, peerId: PeerId) -> Bool {
        return list(lockedKey).contains(entry(accountPeerId, peerId))
    }

    /// Locked and not yet unlocked in this foreground session.
    public static func needsUnlock(accountPeerId: PeerId, peerId: PeerId) -> Bool {
        let value = entry(accountPeerId, peerId)
        return list(lockedKey).contains(value) && !list(unlockedKey).contains(value)
    }

    public static func setLocked(accountPeerId: PeerId, peerId: PeerId, locked: Bool) {
        let value = entry(accountPeerId, peerId)
        var items = list(lockedKey).filter { $0 != value }
        if locked {
            items.append(value)
        }
        UserDefaults.standard.set(items, forKey: lockedKey)
        UserDefaults.standard.set(list(unlockedKey).filter { $0 != value }, forKey: unlockedKey)
        NotificationCenter.default.post(name: AlfaSettings.didChangeNotification, object: nil, userInfo: ["key": "chatLock"])
    }

    public static func markUnlocked(accountPeerId: PeerId, peerId: PeerId) {
        let value = entry(accountPeerId, peerId)
        var items = list(unlockedKey)
        if !items.contains(value) {
            items.append(value)
        }
        UserDefaults.standard.set(items, forKey: unlockedKey)
    }

    /// Every locked chat asks again (the app went to the background or was relaunched).
    public static func relockAll() {
        UserDefaults.standard.removeObject(forKey: unlockedKey)
    }
}

/// AlfaGram: accounts hidden from the accounts list, the account switcher and quick actions.
/// They are reached only from AlfaGram settings → «Maxfiy akkauntlar» after Face ID / the passcode.
public enum AlfaHiddenAccounts {
    private static let key = "alfa_hidden_accounts"

    public static func ids() -> Set<Int64> {
        let values = UserDefaults.standard.array(forKey: key) as? [NSNumber] ?? []
        return Set(values.map { $0.int64Value })
    }

    public static func isHidden(accountPeerId: PeerId) -> Bool {
        return ids().contains(accountPeerId.toInt64())
    }

    public static func setHidden(accountPeerId: PeerId, hidden: Bool) {
        var values = ids()
        if hidden {
            values.insert(accountPeerId.toInt64())
        } else {
            values.remove(accountPeerId.toInt64())
        }
        UserDefaults.standard.set(values.map { NSNumber(value: $0) }, forKey: key)
        NotificationCenter.default.post(name: AlfaSettings.didChangeNotification, object: nil, userInfo: ["key": "hiddenAccounts"])
    }

    /// The hidden account ids now and after every change.
    public static func idsSignal() -> Signal<Set<Int64>, NoError> {
        return Signal { subscriber in
            subscriber.putNext(AlfaHiddenAccounts.ids())
            let observer = NotificationCenter.default.addObserver(forName: AlfaSettings.didChangeNotification, object: nil, queue: nil, using: { _ in
                subscriber.putNext(AlfaHiddenAccounts.ids())
            })
            return ActionDisposable {
                NotificationCenter.default.removeObserver(observer)
            }
        }
        |> distinctUntilChanged
    }
}
