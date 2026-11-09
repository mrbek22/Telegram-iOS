import Foundation

/// AlfaGram: the client-side feature switches, kept in the app's standard `UserDefaults` (under `alfa_<key>`).
/// Read from any queue: `UserDefaults` is thread-safe.
public enum AlfaSettings {
    public enum Key: String, CaseIterable {
        /// A message deleted by its sender (or an admin) stays in the chat, marked as deleted.
        case saveDeletedMessages
        /// An edited message keeps its earlier texts (`AlfaEditHistoryMessageAttribute`).
        case saveEditHistory
        /// The account is never reported online (`account.updateStatus(offline: true)` only).
        case ghostOnline
        /// No "typing…" or other input activity is sent.
        case ghostTyping
        /// Reading a private chat or a group does not tell the server (no `messages.readHistory`).
        case ghostRead
        /// Stories are viewed without telling their author (no `stories.readStories` / `incrementStoryViews`).
        case stealthStories
        /// Sponsored messages in channels are not loaded.
        case blockAds
        /// A suspicious link (lookalike bank/Telegram domain, APK download, punycode, raw IP…) asks before opening.
        case linkGuard
        /// "Copy ID" in the message context menu.
        case showMessageId
        /// Contacts' online sessions are recorded on this device (`AlfaOnlineLog`).
        case onlineLog
        /// Contacts' username / photo / phone / name changes are recorded on this device (`AlfaProfileLog`).
        case profileLog
        /// "Typed but did not send" in private chats is recorded on this device (`AlfaTypingLog`).
        case typingLog
        /// Uzbek interface in Cyrillic script (with the Uzbek language selected).
        case cyrillicUi
        /// Text typed in Latin is sent in Cyrillic.
        case sendCyrillic
        /// Saving and forwarding from chats that restrict it.
        case unrestrictedSave
        /// The stories row above the chat list is not shown.
        case hideStories
        /// Every outgoing message is sent without a notification sound.
        case silentSend

        public var defaultValue: Bool {
            switch self {
            case .saveDeletedMessages, .saveEditHistory, .blockAds, .linkGuard, .showMessageId, .onlineLog, .profileLog, .typingLog:
                return true
            case .ghostOnline, .ghostTyping, .ghostRead, .stealthStories, .cyrillicUi, .sendCyrillic, .unrestrictedSave, .hideStories, .silentSend:
                return false
            }
        }

        var defaultsKey: String {
            return "alfa_" + self.rawValue
        }
    }

    /// Posted on the main queue's notification center after any switch changes.
    public static let didChangeNotification = Notification.Name("AlfaSettingsDidChange")

    public static func value(_ key: Key) -> Bool {
        if let value = UserDefaults.standard.object(forKey: key.defaultsKey) as? NSNumber {
            return value.boolValue
        }
        return key.defaultValue
    }

    public static func setValue(_ key: Key, _ value: Bool) {
        UserDefaults.standard.set(value, forKey: key.defaultsKey)
        NotificationCenter.default.post(name: AlfaSettings.didChangeNotification, object: nil, userInfo: ["key": key.rawValue])
    }

    public static var saveDeletedMessages: Bool {
        return value(.saveDeletedMessages)
    }

    public static var saveEditHistory: Bool {
        return value(.saveEditHistory)
    }

    public static var ghostOnline: Bool {
        return value(.ghostOnline)
    }

    public static var ghostTyping: Bool {
        return value(.ghostTyping)
    }

    public static var ghostRead: Bool {
        return value(.ghostRead)
    }

    public static var stealthStories: Bool {
        return value(.stealthStories)
    }

    public static var blockAds: Bool {
        return value(.blockAds)
    }

    public static var linkGuard: Bool {
        return value(.linkGuard)
    }

    public static var showMessageId: Bool {
        return value(.showMessageId)
    }

    public static var onlineLog: Bool {
        return value(.onlineLog)
    }

    public static var profileLog: Bool {
        return value(.profileLog)
    }

    public static var typingLog: Bool {
        return value(.typingLog)
    }

    public static var cyrillicUi: Bool {
        return value(.cyrillicUi)
    }

    public static var sendCyrillic: Bool {
        return value(.sendCyrillic)
    }

    public static var hideStories: Bool {
        return value(.hideStories)
    }

    public static var silentSend: Bool {
        return value(.silentSend)
    }

    public static var unrestrictedSave: Bool {
        return value(.unrestrictedSave)
    }

    // MARK: - Small persistent counters and flags (not switches)

    public static func integer(_ name: String) -> Int {
        return UserDefaults.standard.integer(forKey: "alfa_n_" + name)
    }

    public static func setInteger(_ name: String, _ value: Int) {
        UserDefaults.standard.set(value, forKey: "alfa_n_" + name)
    }

    public static func flag(_ name: String) -> Bool {
        return UserDefaults.standard.bool(forKey: "alfa_f_" + name)
    }

    public static func setFlag(_ name: String, _ value: Bool) {
        UserDefaults.standard.set(value, forKey: "alfa_f_" + name)
    }
}
