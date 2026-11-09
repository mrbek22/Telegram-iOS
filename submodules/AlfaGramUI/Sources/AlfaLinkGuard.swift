import Foundation
import TelegramCore

/// AlfaGram: checks a link before it is opened. Same rules as the Android client: an APK download, a punycode
/// (lookalike letters) host, a raw IP address, a site posing as a bank / Telegram / payment service, a cheap domain
/// promising gifts or bonuses.
public enum AlfaLinkGuard {
    private static let official: [[String]] = [
        ["telegram", "telegram.org", "t.me", "telegram.me", "telegra.ph", "telesco.pe", "fragment.com", "tdesktop.com"],
        ["click", "click.uz"],
        ["payme", "payme.uz", "paycom.uz"],
        ["uzum", "uzum.uz", "uzumbank.uz", "uzum.com"],
        ["paynet", "paynet.uz"],
        ["humo", "humocard.uz", "humo.uz"],
        ["uzcard", "uzcard.uz"],
        ["apelsin", "apelsin.uz"],
        ["kapitalbank", "kapitalbank.uz"],
        ["agrobank", "agrobank.uz"],
        ["hamkorbank", "hamkorbank.uz"],
        ["anorbank", "anorbank.uz"],
        ["soliq", "soliq.uz"],
        ["mygov", "my.gov.uz"],
        ["whatsapp", "whatsapp.com", "whatsapp.net", "wa.me"],
        ["instagram", "instagram.com"],
        ["alfagram", "anonimbot.uz", "alfagram.uz"]
    ]

    private static let badTlds: Set<String> = ["top", "xyz", "icu", "buzz", "click", "rest", "monster", "cfd", "sbs", "online",
        "site", "live", "fun", "pw", "tk", "ml", "ga", "cf", "gq", "cyou", "lat", "bond", "today", "info", "su", "vip", "work"]

    private static let lureWords: [String] = ["gift", "sovg", "bonus", "premium", "stars", "yutuq", "aksiya", "free", "bepul",
        "prize", "airdrop", "nft", "promo", "reward", "claim", "verify", "login", "jarima"]

    private static var bypassUrl: String?

    private static func hostHasBrand(_ labels: [String], _ token: String) -> Bool {
        for label in labels where !label.isEmpty {
            if token == "click" {
                // not clickup, clickhouse… — only the exact forms
                if ["click", "clickuz", "myclick", "clickpay", "uzclick"].contains(label) {
                    return true
                }
            } else if label.contains(token) {
                return true
            }
        }
        return false
    }

    /// Reasons the link looks dangerous (empty — looks fine).
    public static func reasons(for urlString: String) -> [String] {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return []
        }
        let scheme = url.scheme?.lowercased() ?? ""
        guard scheme == "http" || scheme == "https" else {
            return []
        }
        var host = url.host?.lowercased() ?? ""
        if host.hasPrefix("www.") {
            host = String(host.dropFirst(4))
        }
        if host.isEmpty {
            return []
        }
        let path = url.path.lowercased()
        var result: [String] = []
        if path.hasSuffix(".apk") || path.hasSuffix(".apks") || path.hasSuffix(".xapk") {
            result.append("Havola dastur (APK) yuklab beradi")
        }
        if host.hasPrefix("xn--") || host.contains(".xn--") {
            result.append("Manzil boshqa alifbo harflari bilan niqoblangan (\(host))")
        }
        let ipParts = host.split(separator: ".")
        if ipParts.count == 4 && ipParts.allSatisfy({ !$0.isEmpty && $0.count <= 3 && $0.allSatisfy({ $0.isNumber }) }) {
            result.append("Manzil sayt nomi emas, raqamli IP")
        }
        let labels = host.split(whereSeparator: { $0 == "." || $0 == "-" }).map(String.init)
        for item in official {
            let brand = item[0]
            if !hostHasBrand(labels, brand) {
                continue
            }
            var isOfficial = false
            for domain in item.dropFirst() {
                if host == domain || host.hasSuffix("." + domain) {
                    isOfficial = true
                    break
                }
            }
            if brand == "mygov" && host.hasSuffix(".gov.uz") {
                isOfficial = true
            }
            if !isOfficial {
                result.append("Sayt o'zini «\(brand)» qilib ko'rsatyapti, lekin rasmiy manzil emas (\(host))")
            }
            break
        }
        let tld = host.split(separator: ".").last.map(String.init) ?? ""
        if badTlds.contains(tld) {
            let haystack = host + path
            if lureWords.contains(where: { haystack.contains($0) }) {
                result.append("Sovg'a/bonus/premium va'da qiluvchi shubhali sayt")
            }
        }
        return result
    }

    /// The warning text for an alert, or nil when the link may open without asking.
    public static func warningText(for url: String) -> String? {
        if !AlfaSettings.linkGuard {
            return nil
        }
        if let bypass = bypassUrl, bypass == url {
            bypassUrl = nil
            return nil
        }
        let found = reasons(for: url)
        if found.isEmpty {
            return nil
        }
        var text = (url.count > 120 ? String(url.prefix(120)) + "…" : url) + "\n\n"
        for reason in found {
            text += "• " + reason + "\n"
        }
        text += "\nBunday saytlar Telegram akkauntingiz, karta ma'lumotlaringiz yoki SMS kodingizni o'g'irlashi mumkin. Kodni hech kimga bermang."
        return AlfaCyrillic.ui(text)
    }

    /// "Open anyway": the next check of this link passes.
    public static func allowOnce(_ url: String) {
        bypassUrl = url
    }
}
