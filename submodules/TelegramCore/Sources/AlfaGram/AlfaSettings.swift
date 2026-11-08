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

        public var defaultValue: Bool {
            switch self {
            case .saveDeletedMessages, .saveEditHistory:
                return true
            case .ghostOnline, .ghostTyping, .ghostRead:
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
        NotificationCenter.default.post(name: AlfaSettings.didChangeNotification, object: nil)
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
}
