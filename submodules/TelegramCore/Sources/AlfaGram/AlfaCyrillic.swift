import Foundation

/// AlfaGram: Uzbek Latin → Cyrillic transliteration (the same rules as the Android client's AlfaCyrillic).
public enum AlfaCyrillic {
    /// Parts that are never converted: format specifiers, tags, {…}, links, @names, brand and product names.
    private static let protectedPattern: NSRegularExpression? = try? NSRegularExpression(
        pattern: "%%|%(\\d+\\$)?[-#+ 0,(]*\\d*(\\.\\d+)?[a-zA-Z@]|<[^>]*>|\\{[^}]*\\}|(https?|tg)://\\S+|@\\w+|\\bun\\d\\b|AlfaGram|\\b(Ghost|PIN|TTL|ID|Premium|Stars|Business|Android|iOS|iPhone|Wi-?Fi|Enter|APK)\\b",
        options: []
    )

    private static let loanwords: [(String, String)] = [
        ("Screenshot", "Skrinshot"), ("screenshot", "skrinshot"),
        ("Stories", "Storis"), ("stories", "storis"), ("Story", "Stori"), ("story", "stori"),
        ("caption", "izoh"), ("Caption", "Izoh"),
        ("Debug", "Debag"), ("compact", "kompakt"), ("silent", "ovozsiz"),
        ("sentabr", "sentyabr"), ("oktabr", "oktyabr")
    ]

    private static let apostrophes: Set<Character> = ["'", "‘", "’", "ʻ", "ʼ", "`"]

    /// AlfaGram's own texts: converted while the Cyrillic interface is on.
    public static func ui(_ s: String) -> String {
        return AlfaSettings.cyrillicUi ? toCyrillic(s) : s
    }

    public static func hasCyrillic(_ s: String) -> Bool {
        for c in s.unicodeScalars {
            if c.value >= 0x0400 && c.value <= 0x04FF {
                return true
            }
        }
        return false
    }

    private static let cyrillicToLatin: [Character: String] = [
        "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ё": "yo",
        "ж": "j", "з": "z", "и": "i", "й": "y", "к": "k", "л": "l", "м": "m",
        "н": "n", "о": "o", "п": "p", "р": "r", "с": "s", "т": "t", "у": "u",
        "ф": "f", "х": "x", "ц": "ts", "ч": "ch", "ш": "sh", "щ": "sh", "ъ": "’",
        "ы": "i", "ь": "", "э": "e", "ю": "yu", "я": "ya", "ў": "o‘", "қ": "q",
        "ғ": "g‘", "ҳ": "h"
    ]

    /// Uzbek Cyrillic → Latin (word-initial "е" → "ye"; an all-caps word stays all caps).
    public static func toLatin(_ input: String) -> String {
        if input.isEmpty {
            return input
        }
        let chars = Array(input)
        var result = ""
        for i in 0 ..< chars.count {
            let c = chars[i]
            let lowerString = String(c).lowercased()
            guard lowerString.count == 1, let lc = lowerString.first, var r = cyrillicToLatin[lc] else {
                result.append(c)
                continue
            }
            if lc == "е" {
                let prev: Character? = i > 0 ? chars[i - 1] : nil
                if prev == nil || !(prev!.isLetter) {
                    r = "ye"
                }
            }
            if c.isUppercase && !r.isEmpty {
                let next: Character? = i + 1 < chars.count ? chars[i + 1] : nil
                let wordUp = next != nil && next!.isLetter && next!.isUppercase
                if wordUp {
                    r = r.uppercased()
                } else {
                    r = r.prefix(1).uppercased() + String(r.dropFirst())
                }
            }
            result.append(r)
        }
        return result
    }

    public static func hasLatinLetters(_ s: String) -> Bool {
        for c in s.unicodeScalars {
            if (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") {
                return true
            }
        }
        return false
    }

    public static func toCyrillic(_ input: String) -> String {
        if input.isEmpty || !hasLatinLetters(input) {
            return input
        }
        var s = input
        for (from, to) in loanwords where s.contains(from) {
            s = s.replacingOccurrences(of: "\\b" + NSRegularExpression.escapedPattern(for: from) + "\\b", with: to, options: .regularExpression)
        }
        guard let regex = protectedPattern else {
            return convertChunk(s)
        }
        let ns = s as NSString
        var out = ""
        var last = 0
        for match in regex.matches(in: s, options: [], range: NSRange(location: 0, length: ns.length)) {
            if match.range.location > last {
                out += convertChunk(ns.substring(with: NSRange(location: last, length: match.range.location - last)))
            }
            out += ns.substring(with: match.range)
            last = match.range.location + match.range.length
        }
        if last < ns.length {
            out += convertChunk(ns.substring(from: last))
        }
        return out
    }

    private static func isLatinLetter(_ c: Character?) -> Bool {
        guard let c = c, let scalar = c.unicodeScalars.first, c.unicodeScalars.count == 1 else {
            return false
        }
        return (scalar >= "a" && scalar <= "z") || (scalar >= "A" && scalar <= "Z")
    }

    private static func isVowel(_ c: Character?) -> Bool {
        guard let c = c else {
            return false
        }
        return "aeiouAEIOU".contains(c)
    }

    private static func isApostrophe(_ c: Character?) -> Bool {
        guard let c = c else {
            return false
        }
        return apostrophes.contains(c)
    }

    private static func lower(_ c: Character?) -> Character? {
        guard let c = c else {
            return nil
        }
        return Character(String(c).lowercased().first.map(String.init) ?? String(c))
    }

    private static func cased(_ r: String, _ upper: Bool) -> String {
        return upper ? r.uppercased() : r
    }

    private static func single(_ c: Character) -> String? {
        switch c {
        case "a": return "а"
        case "b": return "б"
        case "c": return "ц"
        case "d": return "д"
        case "f": return "ф"
        case "g": return "г"
        case "h": return "ҳ"
        case "i": return "и"
        case "j": return "ж"
        case "k": return "к"
        case "l": return "л"
        case "m": return "м"
        case "n": return "н"
        case "o": return "о"
        case "p": return "п"
        case "q": return "қ"
        case "r": return "р"
        case "s": return "с"
        case "t": return "т"
        case "u": return "у"
        case "v": return "в"
        case "w": return "в"
        case "x": return "х"
        case "y": return "й"
        case "z": return "з"
        default: return nil
        }
    }

    private static func matchesIya(_ chars: [Character], from index: Int) -> Bool {
        if index + 2 >= chars.count {
            return false
        }
        return lower(chars[index]) == "i" && lower(chars[index + 1]) == "y" && lower(chars[index + 2]) == "a"
    }

    private static func convertChunk(_ s: String) -> String {
        let chars = Array(s)
        let n = chars.count
        var out = ""
        var i = 0
        while i < n {
            let c = chars[i]
            let next: Character? = i + 1 < n ? chars[i + 1] : nil
            let prev: Character? = i > 0 ? chars[i - 1] : nil
            let up = c.isUppercase
            guard let lc = lower(c) else {
                i += 1
                continue
            }
            let ln = lower(next)

            if (lc == "o" || lc == "g") && isApostrophe(next) {
                out += cased(lc == "o" ? "ў" : "ғ", up)
                i += 2
                continue
            }
            // foreign words: animatsiya → анимация, funksiya → функция
            if lc == "t" && ln == "s" && matchesIya(chars, from: i + 2) {
                out += cased("ц", up)
                i += 2
                continue
            }
            if lc == "s" && lower(prev) == "k" && matchesIya(chars, from: i + 1) {
                out += cased("ц", up)
                i += 1
                continue
            }
            if lc == "s" && ln == "h" {
                out += cased("ш", up)
                i += 2
                continue
            }
            if lc == "c" && ln == "h" {
                out += cased("ч", up)
                i += 2
                continue
            }
            // "yo'" is й + ў (Yo'q → Йўқ), not "yo"
            let yoApostrophe = lc == "y" && ln == "o" && i + 2 < n && isApostrophe(chars[i + 2])
            if lc == "y" && !yoApostrophe, let ln = ln, ln == "o" || ln == "u" || ln == "a" || ln == "e" {
                let r: String
                switch ln {
                case "o": r = "ё"
                case "u": r = "ю"
                case "a": r = "я"
                default: r = "е"
                }
                out += cased(r, up)
                i += 2
                continue
            }
            if isApostrophe(c) {
                // between letters: ъ (before/after a vowel); otherwise kept as is
                if isLatinLetter(prev) && isLatinLetter(next) {
                    if isVowel(next) || isVowel(prev) {
                        out += "ъ"
                    }
                } else {
                    out.append(c)
                }
                i += 1
                continue
            }
            if lc == "e" {
                let wordStart = !isLatinLetter(prev) && !isApostrophe(prev)
                out += cased(wordStart || isVowel(prev) ? "э" : "е", up)
                i += 1
                continue
            }
            if isLatinLetter(c), let r = single(lc) {
                out += cased(r, up)
            } else {
                out.append(c)
            }
            i += 1
        }
        return out
    }

    /// Converts every value of a localization table (dates' format patterns keep their letters).
    public static func convertLocalization(_ dict: [String: String]) -> [String: String] {
        var result: [String: String] = [:]
        result.reserveCapacity(dict.count)
        for (key, value) in dict {
            if key.hasPrefix("Time.") || key.contains("DateFormat") || key.contains("Formatter") {
                result[key] = value
            } else {
                result[key] = toCyrillic(value)
            }
        }
        return result
    }
}
