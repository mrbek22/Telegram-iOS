import Foundation
import Postbox
import SwiftSignalKit

/// The App Group's defaults ("group.<app bundle id>"), shared by the app and its extensions
/// (the notification service reads the locked chats and hidden accounts from here).
enum AlfaSharedDefaults {
    static let value: UserDefaults = {
        var bundleId = Bundle.main.bundleIdentifier ?? ""
        if Bundle.main.bundlePath.hasSuffix(".appex"), let lastDot = bundleId.range(of: ".", options: .backwards) {
            bundleId = String(bundleId[..<lastDot.lowerBound])
        }
        return UserDefaults(suiteName: "group." + bundleId) ?? UserDefaults.standard
    }()
}

/// AlfaGram: chats locked behind Face ID / Touch ID / the device passcode.
/// A locked chat opens only after authentication and stays open until the app goes to the background.
/// Kept in the app's standard `UserDefaults`, as "<account peer id>:<chat peer id>" strings.
public enum AlfaChatLock {
    private static let lockedKey = "alfa_locked_chats"
    private static let unlockedKey = "alfa_unlocked_chats"

    private static func entry(_ accountPeerId: PeerId, _ peerId: PeerId) -> String {
        return "\(accountPeerId.toInt64()):\(peerId.toInt64())"
    }

    /// The locked list is shared with the extensions; "unlocked for now" stays in the app.
    private static func defaults(_ key: String) -> UserDefaults {
        return key == lockedKey ? AlfaSharedDefaults.value : UserDefaults.standard
    }

    private static func list(_ key: String) -> [String] {
        return defaults(key).stringArray(forKey: key) ?? []
    }

    // Every chat list row asks isLocked (twice): keep the locked set in memory instead of re-reading UserDefaults.
    // Only this process writes it (the extensions only read), so setLocked refreshes the cache.
    private static let cacheLock = NSLock()
    private static var lockedCache: Set<String>?

    private static func lockedSet() -> Set<String> {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let lockedCache {
            return lockedCache
        }
        let value = Set(list(lockedKey))
        lockedCache = value
        return value
    }

    public static func isLocked(accountPeerId: PeerId, peerId: PeerId) -> Bool {
        let set = lockedSet()
        if set.isEmpty {
            return false
        }
        return set.contains(entry(accountPeerId, peerId))
    }

    /// Locked and not yet unlocked in this foreground session.
    public static func needsUnlock(accountPeerId: PeerId, peerId: PeerId) -> Bool {
        let value = entry(accountPeerId, peerId)
        return lockedSet().contains(value) && !list(unlockedKey).contains(value)
    }

    public static func setLocked(accountPeerId: PeerId, peerId: PeerId, locked: Bool) {
        let value = entry(accountPeerId, peerId)
        var items = list(lockedKey).filter { $0 != value }
        if locked {
            items.append(value)
        }
        AlfaSharedDefaults.value.set(items, forKey: lockedKey)
        cacheLock.lock()
        lockedCache = Set(items)
        cacheLock.unlock()
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

/// AlfaGram: "paused" accounts — no notifications at all until resumed, as if logged out on this phone.
public enum AlfaPausedAccounts {
    private static let key = "alfa_paused_accounts"

    public static func ids() -> Set<Int64> {
        let values = AlfaSharedDefaults.value.array(forKey: key) as? [NSNumber] ?? []
        return Set(values.map { $0.int64Value })
    }

    public static func isPaused(accountPeerId: PeerId) -> Bool {
        return ids().contains(accountPeerId.toInt64())
    }

    public static func setPaused(accountPeerId: PeerId, paused: Bool) {
        var values = ids()
        if paused {
            values.insert(accountPeerId.toInt64())
        } else {
            values.remove(accountPeerId.toInt64())
        }
        AlfaSharedDefaults.value.set(values.map { NSNumber(value: $0) }, forKey: key)
        NotificationCenter.default.post(name: AlfaSettings.didChangeNotification, object: nil, userInfo: ["key": "pausedAccounts"])
    }
}

/// AlfaGram: accounts hidden from the accounts list, the account switcher and quick actions.
/// They are reached only from AlfaGram settings → «Maxfiy akkauntlar» after Face ID / the passcode.
public enum AlfaHiddenAccounts {
    private static let key = "alfa_hidden_accounts"

    public static func ids() -> Set<Int64> {
        let values = AlfaSharedDefaults.value.array(forKey: key) as? [NSNumber] ?? []
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
        AlfaSharedDefaults.value.set(values.map { NSNumber(value: $0) }, forKey: key)
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
