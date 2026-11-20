import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import OverlayStatusController
import AccountContext
import LocalizedPeerData
import AlertUI

/// AlfaGram: «Export chat» — the chat's history (up to 5000 latest messages) as an HTML page or a plain text file,
/// handed to the share sheet (Save to Files, send to Saved Messages, AirDrop…).
extension ChatControllerImpl {
    func alfaExportChat() {
        guard let peerId = self.chatLocation.peerId else {
            return
        }
        let presentationData = self.presentationData
        let actionSheet = ActionSheetController(presentationData: presentationData)
        actionSheet.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetTextItem(title: AlfaCyrillic.ui("Chatni eksport qilish: oxirgi 5000 tagacha xabar. Formatni tanlang.")),
                ActionSheetButtonItem(title: AlfaCyrillic.ui("HTML sahifa"), color: .accent, action: { [weak self, weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    self?.alfaRunChatExport(peerId: peerId, html: true)
                }),
                ActionSheetButtonItem(title: AlfaCyrillic.ui("Matn fayl (TXT)"), color: .accent, action: { [weak self, weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    self?.alfaRunChatExport(peerId: peerId, html: false)
                })
            ]),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])
        ])
        self.chatDisplayNode.dismissInput()
        self.present(actionSheet, in: .window(.root))
    }

    private func alfaRunChatExport(peerId: EnginePeer.Id, html: Bool) {
        let presentationData = self.presentationData
        var chatTitle = "Chat"
        if let peer = self.presentationInterfaceState.renderedPeer?.chatMainPeer {
            chatTitle = EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
        }

        let statusController = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
        self.present(statusController, in: .window(.root))

        let _ = (alfaFetchChatHistoryForExport(account: self.context.account, peerId: peerId, limit: 5000)
        |> deliverOnMainQueue).startStandalone(next: { [weak self, weak statusController] messages in
            statusController?.dismiss()
            guard let self else {
                return
            }
            if messages.isEmpty {
                self.present(textAlertController(context: self.context, title: nil, text: AlfaCyrillic.ui("Eksport qilish uchun xabar topilmadi."), actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                return
            }
            // Oldest first, as a chat is read.
            let ordered = Array(messages.reversed())
            let content = html ? alfaChatExportHTML(title: chatTitle, messages: ordered) : alfaChatExportText(title: chatTitle, messages: ordered)

            var safeName = chatTitle.components(separatedBy: CharacterSet(charactersIn: "/:?*<>|\"")).joined(separator: "_")
            if safeName.isEmpty {
                safeName = "chat"
            }
            let path = NSTemporaryDirectory() + safeName + (html ? ".html" : ".txt")
            do {
                try content.write(toFile: path, atomically: true, encoding: .utf8)
            } catch {
                return
            }
            let activity = UIActivityViewController(activityItems: [URL(fileURLWithPath: path)], applicationActivities: nil)
            if let popover = activity.popoverPresentationController {
                popover.sourceView = self.view
                popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 1.0, height: 1.0)
            }
            self.present(activity, animated: true, completion: nil)
        })
    }
}

private func alfaChatExportDate(_ timestamp: Int32) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd.MM.yyyy HH:mm"
    return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
}

private func alfaChatExportMediaLabel(_ media: AlfaExportedMessage.MediaKind) -> String {
    switch media {
    case .photo:
        return AlfaCyrillic.ui("[Rasm]")
    case .video:
        return AlfaCyrillic.ui("[Video]")
    case .voice:
        return AlfaCyrillic.ui("[Ovozli xabar]")
    case .roundVideo:
        return AlfaCyrillic.ui("[Dumaloq video]")
    case .sticker:
        return AlfaCyrillic.ui("[Stiker]")
    case .gif:
        return "[GIF]"
    case let .file(name):
        return AlfaCyrillic.ui("[Fayl]") + (name.isEmpty ? "" : " " + name)
    case .service:
        return AlfaCyrillic.ui("[Xizmat xabari]")
    case .other:
        return AlfaCyrillic.ui("[Media]")
    }
}

private func alfaChatExportText(title: String, messages: [AlfaExportedMessage]) -> String {
    var lines: [String] = []
    lines.append(title)
    lines.append(AlfaCyrillic.ui("AlfaGram eksporti") + " — " + alfaChatExportDate(Int32(Date().timeIntervalSince1970)))
    lines.append("")
    for message in messages {
        var body = message.text
        if let media = message.media {
            body = alfaChatExportMediaLabel(media) + (body.isEmpty ? "" : " " + body)
        }
        lines.append("[" + alfaChatExportDate(message.date) + "] " + message.author + ": " + body)
    }
    return lines.joined(separator: "\n")
}

private func alfaHTMLEscape(_ text: String) -> String {
    return text
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "\n", with: "<br>")
}

private func alfaChatExportHTML(title: String, messages: [AlfaExportedMessage]) -> String {
    var html = "<!doctype html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
    html += "<title>" + alfaHTMLEscape(title) + "</title><style>"
    html += "body{font-family:-apple-system,Helvetica,Arial,sans-serif;background:#eef1f5;margin:0;padding:16px;color:#111}"
    html += "h1{font-size:20px;margin:0 0 4px}.sub{color:#777;font-size:13px;margin-bottom:16px}"
    html += ".m{max-width:75%;margin:6px 0;padding:8px 12px;border-radius:14px;background:#fff;box-shadow:0 1px 1px rgba(0,0,0,.08)}"
    html += ".o{margin-left:auto;background:#dcf3ff}.a{font-weight:600;font-size:13px;color:#2563eb}.t{font-size:15px;line-height:1.35;word-wrap:break-word}"
    html += ".d{font-size:11px;color:#999;text-align:right;margin-top:2px}.md{font-style:italic;color:#555}"
    html += "@media (prefers-color-scheme:dark){body{background:#0e1621;color:#eee}.m{background:#182533}.o{background:#2b5278}.sub,.d{color:#8a99a8}.md{color:#aab}}"
    html += "</style></head><body>"
    html += "<h1>" + alfaHTMLEscape(title) + "</h1>"
    html += "<div class=\"sub\">" + alfaHTMLEscape(AlfaCyrillic.ui("AlfaGram eksporti")) + " — " + alfaChatExportDate(Int32(Date().timeIntervalSince1970)) + " · " + String(messages.count) + "</div>"
    for message in messages {
        html += "<div class=\"m" + (message.isOutgoing ? " o" : "") + "\">"
        html += "<div class=\"a\">" + alfaHTMLEscape(message.author) + "</div>"
        if let media = message.media {
            html += "<div class=\"t md\">" + alfaHTMLEscape(alfaChatExportMediaLabel(media)) + "</div>"
        }
        if !message.text.isEmpty {
            html += "<div class=\"t\">" + alfaHTMLEscape(message.text) + "</div>"
        }
        html += "<div class=\"d\">" + alfaChatExportDate(message.date) + "</div></div>"
    }
    html += "</body></html>"
    return html
}
