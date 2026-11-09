import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi

// AlfaGram: on-device logs of what other people do — online sessions, profile changes, "typed but did not send".
// Everything stays on this device (Application Support/alfagram/*.json); nothing is sent anywhere.

/// A small JSON file kept in memory and written back (debounced) on its own queue.
final class AlfaJSONFile<T: Codable> {
    private let lock = NSLock()
    private let url: URL?
    private var value: T
    private var loaded = false
    private var saveScheduled = false
    private let makeEmpty: () -> T

    init(name: String, empty: @escaping () -> T) {
        self.makeEmpty = empty
        self.value = empty()
        if let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let dir = base.appendingPathComponent("alfagram", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
            self.url = dir.appendingPathComponent(name + ".json")
        } else {
            self.url = nil
        }
    }

    private func loadIfNeeded() {
        if self.loaded {
            return
        }
        self.loaded = true
        if let url = self.url, let data = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode(T.self, from: data) {
            self.value = decoded
        }
    }

    func read<R>(_ f: (T) -> R) -> R {
        self.lock.lock()
        defer { self.lock.unlock() }
        self.loadIfNeeded()
        return f(self.value)
    }

    func modify(_ f: (inout T) -> Void) {
        self.lock.lock()
        self.loadIfNeeded()
        f(&self.value)
        let schedule = !self.saveScheduled
        self.saveScheduled = true
        self.lock.unlock()
        if schedule {
            alfaLogsQueue.asyncAfter(deadline: .now() + 8.0, execute: { [weak self] in
                self?.save()
            })
        }
    }

    func reset() {
        self.modify { value in
            value = self.makeEmpty()
        }
    }

    private func save() {
        self.lock.lock()
        self.saveScheduled = false
        let snapshot = self.value
        self.lock.unlock()
        guard let url = self.url, let data = try? JSONEncoder().encode(snapshot) else {
            return
        }
        try? data.write(to: url, options: [.atomic])
    }
}

private let alfaLogsQueue = DispatchQueue(label: "uz.alfagram.logs")

/// Posted (main queue) when any AlfaGram log gets a new entry.
public let alfaLogsDidChangeNotification = Notification.Name("AlfaLogsDidChange")

private func alfaNotifyLogsChanged() {
    DispatchQueue.main.async {
        NotificationCenter.default.post(name: alfaLogsDidChangeNotification, object: nil)
    }
}

/// Whether a user is someone the account knows: a contact or a private chat.
private func alfaIsRelevantUser(transaction: Transaction, peerId: PeerId) -> Bool {
    guard peerId.namespace == Namespaces.Peer.CloudUser else {
        return false
    }
    if transaction.isPeerContact(peerId: peerId) {
        return true
    }
    return transaction.getPeerChatListIndex(peerId) != nil
}

// MARK: - Online sessions

public enum AlfaOnlineLog {
    public struct Session: Codable, Equatable {
        public var start: Int32
        /// 0 — still online (or tracking stopped; see `seen`)
        public var end: Int32
        /// the last time the user was seen online
        public var seen: Int32
    }

    struct Storage: Codable {
        /// "<accountPeerId>" → "<userId>" → sessions, newest last
        var accounts: [String: [String: [Session]]] = [:]
    }

    /// A session not confirmed for this long is considered over (the app was not connected meanwhile).
    public static let gap: Int32 = 6 * 60
    private static let maxSessionsPerUser = 60
    static let file = AlfaJSONFile<Storage>(name: "online", empty: { Storage() })

    /// Called inside presence transactions (`updatePeerPresences*`).
    static func record(transaction: Transaction, accountPeerId: PeerId, presences: [PeerId: PeerPresence]) {
        if !AlfaSettings.onlineLog || presences.isEmpty {
            return
        }
        let now = Int32(Date().timeIntervalSince1970)
        var changes: [(Int64, Bool, Int32)] = []
        for (peerId, presence) in presences {
            guard peerId != accountPeerId, let presence = presence as? TelegramUserPresence, alfaIsRelevantUser(transaction: transaction, peerId: peerId) else {
                continue
            }
            if case let .present(until) = presence.status {
                if until > now {
                    changes.append((peerId.id._internalGetInt64Value(), true, now))
                } else {
                    changes.append((peerId.id._internalGetInt64Value(), false, min(until, now)))
                }
            }
        }
        if changes.isEmpty {
            return
        }
        let accountKey = "\(accountPeerId.id._internalGetInt64Value())"
        self.file.modify { storage in
            var users = storage.accounts[accountKey] ?? [:]
            for (userId, online, time) in changes {
                let userKey = "\(userId)"
                var sessions = users[userKey] ?? []
                let lastIndex = sessions.count - 1
                let isOpen = lastIndex >= 0 && sessions[lastIndex].end == 0
                if online {
                    if isOpen && time - sessions[lastIndex].seen <= self.gap {
                        sessions[lastIndex].seen = time
                    } else {
                        if isOpen {
                            sessions[lastIndex].end = sessions[lastIndex].seen
                        }
                        sessions.append(Session(start: time, end: 0, seen: time))
                    }
                } else if isOpen {
                    let end = max(sessions[lastIndex].start, min(time, sessions[lastIndex].seen + self.gap))
                    sessions[lastIndex].end = end
                    sessions[lastIndex].seen = end
                } else if time > 0 && (lastIndex < 0 || sessions[lastIndex].end < time - 60) {
                    // only the "last seen" point is known
                    sessions.append(Session(start: time, end: time, seen: time))
                }
                if sessions.count > self.maxSessionsPerUser {
                    sessions.removeFirst(sessions.count - self.maxSessionsPerUser)
                }
                users[userKey] = sessions
            }
            storage.accounts[accountKey] = users
        }
        alfaNotifyLogsChanged()
    }

    /// Sessions of one user, newest first.
    public static func sessions(accountPeerId: EnginePeer.Id, userId: EnginePeer.Id) -> [Session] {
        let accountKey = "\(accountPeerId.id._internalGetInt64Value())"
        let userKey = "\(userId.id._internalGetInt64Value())"
        return self.file.read { storage in
            return Array((storage.accounts[accountKey]?[userKey] ?? []).reversed())
        }
    }

    /// Users with any session, most recently seen first.
    public static func users(accountPeerId: EnginePeer.Id) -> [(peerId: EnginePeer.Id, lastSeen: Int32, isOnline: Bool)] {
        let accountKey = "\(accountPeerId.id._internalGetInt64Value())"
        let now = Int32(Date().timeIntervalSince1970)
        let result: [(peerId: EnginePeer.Id, lastSeen: Int32, isOnline: Bool)] = self.file.read { storage in
            var list: [(peerId: EnginePeer.Id, lastSeen: Int32, isOnline: Bool)] = []
            for (userKey, sessions) in storage.accounts[accountKey] ?? [:] {
                guard let id = Int64(userKey), let last = sessions.last else {
                    continue
                }
                let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(id))
                list.append((peerId: peerId, lastSeen: last.seen, isOnline: last.end == 0 && now - last.seen <= self.gap))
            }
            return list
        }
        return result.sorted(by: { $0.lastSeen > $1.lastSeen })
    }

    public static func clear(accountPeerId: EnginePeer.Id) {
        let accountKey = "\(accountPeerId.id._internalGetInt64Value())"
        self.file.modify { storage in
            storage.accounts[accountKey] = nil
        }
        alfaNotifyLogsChanged()
    }

    // MARK: polling

    private static let pollLock = NSLock()
    private static var pollTimers: [Int64: SwiftSignalKit.Timer] = [:]

    /// Asks the server for the contacts' statuses every 45 s while the app runs: in ghost mode (or with the app
    /// offline) the server does not push status updates, the poll still answers.
    public static func startPolling(account: Account) {
        let key = account.peerId.id._internalGetInt64Value()
        self.pollLock.lock()
        defer { self.pollLock.unlock() }
        if self.pollTimers[key] != nil {
            return
        }
        let timer = SwiftSignalKit.Timer(timeout: 45.0, repeat: true, completion: { [weak account] in
            guard let account = account, AlfaSettings.onlineLog else {
                return
            }
            let _ = alfaPollContactStatuses(postbox: account.postbox, network: account.network, accountPeerId: account.peerId).start()
        }, queue: Queue.concurrentDefaultQueue())
        self.pollTimers[key] = timer
        timer.start()
        let _ = alfaPollContactStatuses(postbox: account.postbox, network: account.network, accountPeerId: account.peerId).start()
    }
}

private func alfaPollContactStatuses(postbox: Postbox, network: Network, accountPeerId: PeerId) -> Signal<Never, NoError> {
    return network.request(Api.functions.contacts.getStatuses())
    |> `catch` { _ -> Signal<[Api.ContactStatus], NoError> in
        return .single([])
    }
    |> mapToSignal { statuses -> Signal<Never, NoError> in
        if statuses.isEmpty {
            return .complete()
        }
        return postbox.transaction { transaction -> Void in
            var peerPresences: [PeerId: UpdatedApiPresence] = [:]
            for status in statuses {
                switch status {
                case let .contactStatus(contactStatusData):
                    let (userId, status) = (contactStatusData.userId, contactStatusData.status)
                    peerPresences[PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))] = UpdatedApiPresence(status: status, isMin: false)
                }
            }
            updatePeerPresencesClean(transaction: transaction, accountPeerId: accountPeerId, peerPresences: peerPresences)
        }
        |> ignoreValues
    }
}

// MARK: - Profile changes

public enum AlfaProfileLog {
    public enum Field: String, Codable {
        case name
        case username
        case photo
        case photoRemoved
        case phone
    }

    public struct Entry: Codable, Equatable {
        public var userId: Int64
        public var time: Int32
        public var field: Field
        public var oldValue: String
        public var newValue: String

        public var peerId: EnginePeer.Id {
            return PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(self.userId))
        }
    }

    struct Storage: Codable {
        var accounts: [String: [Entry]] = [:]
    }

    private static let maxEntries = 1000
    static let file = AlfaJSONFile<Storage>(name: "profile", empty: { Storage() })

    private static func photoKey(_ user: TelegramUser) -> String? {
        guard let first = user.photo.first else {
            return ""
        }
        if first.isPersonal {
            return nil
        }
        return first.resource.id.stringRepresentation
    }

    private static func fullName(_ user: TelegramUser) -> String {
        return [user.firstName ?? "", user.lastName ?? ""].filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Called from `updatePeers` with the stored user and the server's (non-min) copy.
    static func compare(transaction: Transaction, accountPeerId: PeerId, previous: TelegramUser?, updated: TelegramUser) {
        guard AlfaSettings.profileLog, let previous = previous, updated.id != accountPeerId, !updated.flags.contains(.isSupport) else {
            return
        }
        if updated.botInfo != nil || !alfaIsRelevantUser(transaction: transaction, peerId: updated.id) {
            return
        }
        let now = Int32(Date().timeIntervalSince1970)
        let userId = updated.id.id._internalGetInt64Value()
        var entries: [Entry] = []

        // the name: only for non-contacts — a contact's name is the one saved in your contacts
        if !transaction.isPeerContact(peerId: updated.id) {
            let oldName = fullName(previous)
            let newName = fullName(updated)
            if !oldName.isEmpty && !newName.isEmpty && oldName != newName {
                entries.append(Entry(userId: userId, time: now, field: .name, oldValue: oldName, newValue: newName))
            }
        }
        let oldUsername = previous.addressName ?? ""
        let newUsername = updated.addressName ?? ""
        if oldUsername.lowercased() != newUsername.lowercased() {
            entries.append(Entry(userId: userId, time: now, field: .username, oldValue: oldUsername, newValue: newUsername))
        }
        if let oldPhoto = photoKey(previous), let newPhoto = photoKey(updated), oldPhoto != newPhoto {
            if newPhoto.isEmpty {
                entries.append(Entry(userId: userId, time: now, field: .photoRemoved, oldValue: "", newValue: ""))
            } else if !oldPhoto.isEmpty {
                entries.append(Entry(userId: userId, time: now, field: .photo, oldValue: "", newValue: ""))
            }
        }
        let oldPhone = previous.phone ?? ""
        let newPhone = updated.phone ?? ""
        if !oldPhone.isEmpty && !newPhone.isEmpty && oldPhone != newPhone {
            entries.append(Entry(userId: userId, time: now, field: .phone, oldValue: oldPhone, newValue: newPhone))
        }
        if entries.isEmpty {
            return
        }
        let accountKey = "\(accountPeerId.id._internalGetInt64Value())"
        self.file.modify { storage in
            var list = storage.accounts[accountKey] ?? []
            list.append(contentsOf: entries)
            if list.count > self.maxEntries {
                list.removeFirst(list.count - self.maxEntries)
            }
            storage.accounts[accountKey] = list
        }
        alfaNotifyLogsChanged()
    }

    /// Newest first; `userId` nil — everyone.
    public static func entries(accountPeerId: EnginePeer.Id, userId: EnginePeer.Id? = nil) -> [Entry] {
        let accountKey = "\(accountPeerId.id._internalGetInt64Value())"
        let filterId = userId?.id._internalGetInt64Value()
        return self.file.read { storage in
            let list = storage.accounts[accountKey] ?? []
            return Array(list.filter { filterId == nil || $0.userId == filterId }.reversed())
        }
    }

    public static func clear(accountPeerId: EnginePeer.Id) {
        let accountKey = "\(accountPeerId.id._internalGetInt64Value())"
        self.file.modify { storage in
            storage.accounts[accountKey] = nil
        }
        alfaNotifyLogsChanged()
    }
}

// MARK: - Typed but did not send

public enum AlfaTypingLog {
    public struct Entry: Codable, Equatable {
        public var userId: Int64
        /// when the typing started
        public var time: Int32
        /// the last typing signal of this burst
        public var lastTyping: Int32

        public var peerId: EnginePeer.Id {
            return PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(self.userId))
        }
    }

    struct Storage: Codable {
        var accounts: [String: [Entry]] = [:]
        /// "<account>:<user>" → the last incoming message time
        var lastMessage: [String: Int32] = [:]
    }

    /// A burst of typing ends when no signal comes for this long.
    private static let burstGap: Int32 = 25
    /// A message within this long after the last typing signal counts as "sent".
    public static let sendWindow: Int32 = 90
    private static let maxEntries = 500
    static let file = AlfaJSONFile<Storage>(name: "typing", empty: { Storage() })

    /// A user started (or keeps) typing in the private chat with the account.
    static func typing(accountPeerId: PeerId, userId: PeerId) {
        guard AlfaSettings.typingLog, userId.namespace == Namespaces.Peer.CloudUser, userId != accountPeerId else {
            return
        }
        let now = Int32(Date().timeIntervalSince1970)
        let accountKey = "\(accountPeerId.id._internalGetInt64Value())"
        let id = userId.id._internalGetInt64Value()
        self.file.modify { storage in
            var list = storage.accounts[accountKey] ?? []
            if let index = list.lastIndex(where: { $0.userId == id }), now - list[index].lastTyping <= self.burstGap {
                list[index].lastTyping = now
            } else {
                list.append(Entry(userId: id, time: now, lastTyping: now))
            }
            if list.count > self.maxEntries {
                list.removeFirst(list.count - self.maxEntries)
            }
            storage.accounts[accountKey] = list
        }
    }

    /// An incoming message from `userId` in the private chat.
    static func messageReceived(accountPeerId: PeerId, userId: PeerId, timestamp: Int32) {
        guard AlfaSettings.typingLog else {
            return
        }
        let key = "\(accountPeerId.id._internalGetInt64Value()):\(userId.id._internalGetInt64Value())"
        self.file.modify { storage in
            storage.lastMessage[key] = max(storage.lastMessage[key] ?? 0, timestamp)
        }
    }

    /// Typing bursts after which no message came, newest first (only bursts older than the send window).
    public static func unsent(accountPeerId: EnginePeer.Id) -> [Entry] {
        let accountKey = "\(accountPeerId.id._internalGetInt64Value())"
        let now = Int32(Date().timeIntervalSince1970)
        return self.file.read { storage in
            let list = storage.accounts[accountKey] ?? []
            var result: [Entry] = []
            for entry in list.reversed() {
                if now - entry.lastTyping < self.sendWindow {
                    continue
                }
                let last = storage.lastMessage["\(accountKey):\(entry.userId)"] ?? 0
                if last >= entry.time - 5 && last <= entry.lastTyping + self.sendWindow {
                    continue
                }
                result.append(entry)
            }
            return result
        }
    }

    public static func clear(accountPeerId: EnginePeer.Id) {
        let accountKey = "\(accountPeerId.id._internalGetInt64Value())"
        self.file.modify { storage in
            storage.accounts[accountKey] = nil
        }
        alfaNotifyLogsChanged()
    }
}
