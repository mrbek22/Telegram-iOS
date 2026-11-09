import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import AccountContext

/// AlfaGram: "Xayrli tong, Davron ☀️" in place of the chat list title for ~3 s — only when the app is entered
/// (a cold start, or back after at least 30 s in another app), not when returning from a chat.
final class AlfaChatListGreeting {
    static let shared = AlfaChatListGreeting()

    let text = ValuePromise<String?>(nil, ignoreRepeated: true)

    private var started = false
    private var resignedAt: Double?
    private var observers: [NSObjectProtocol] = []
    private weak var context: AccountContext?
    private var hideTimer: SwiftSignalKit.Timer?
    private let disposable = MetaDisposable()

    func attach(context: AccountContext) {
        self.context = context
        if self.started {
            return
        }
        self.started = true
        self.observers.append(NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: OperationQueue.main, using: { [weak self] _ in
            self?.resignedAt = CFAbsoluteTimeGetCurrent()
        }))
        self.observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: OperationQueue.main, using: { [weak self] _ in
            guard let self = self, let resignedAt = self.resignedAt else {
                return
            }
            self.resignedAt = nil
            if CFAbsoluteTimeGetCurrent() - resignedAt >= 30.0 {
                self.show(after: 0.4)
            }
        }))
        // cold start: after the opening animation
        self.show(after: 1.3)
    }

    private static func greeting(name: String) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let text: String
        let emoji: String
        if hour >= 5 && hour < 11 {
            text = "Xayrli tong"
            emoji = "☀️"
        } else if hour >= 11 && hour < 17 {
            text = "Xayrli kun"
            emoji = "🌤"
        } else if hour >= 17 && hour < 22 {
            text = "Xayrli kech"
            emoji = "🌆"
        } else {
            text = "Xayrli tun"
            emoji = "🌙"
        }
        var result = AlfaCyrillic.ui(text)
        var first = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let space = first.firstIndex(of: " ") {
            first = String(first[first.startIndex ..< space])
        }
        if first.count > 14 {
            first = String(first.prefix(13)) + "…"
        }
        if !first.isEmpty {
            result += ", " + first
        }
        return result + " " + emoji
    }

    private func show(after: Double) {
        guard let context = self.context else {
            return
        }
        self.disposable.set((context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
        |> delay(after, queue: Queue.mainQueue())
        |> deliverOnMainQueue).start(next: { [weak self] peer in
            guard let self = self else {
                return
            }
            var name = ""
            if case let .user(user)? = peer {
                name = user.firstName ?? ""
            }
            self.text.set(AlfaChatListGreeting.greeting(name: name))
            self.hideTimer?.invalidate()
            let timer = SwiftSignalKit.Timer(timeout: 3.0, repeat: false, completion: { [weak self] in
                self?.text.set(nil)
            }, queue: Queue.mainQueue())
            self.hideTimer = timer
            timer.start()
        }))
    }
}
