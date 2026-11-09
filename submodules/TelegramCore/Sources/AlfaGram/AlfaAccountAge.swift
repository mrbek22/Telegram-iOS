import Foundation

/// AlfaGram: when an account was registered, ESTIMATED from its user id (ids grow over time; linear between
/// known points). Shown only to the month: "~ 2022-yil oktabr".
public enum AlfaAccountAge {
    private static let points: [(Int64, Int64)] = [
        (2768409, 1383264000),
        (7679610, 1388448000),
        (11538514, 1391212000),
        (44634663, 1399334000),
        (54845238, 1411257000),
        (63263518, 1414454000),
        (101260938, 1425600000),
        (130029930, 1441324000),
        (171295414, 1457481000),
        (222021233, 1465344000),
        (278941742, 1473465000),
        (337808429, 1487707000),
        (400169472, 1501459000),
        (805158066, 1563208000),
        (1974255900, 1634000000),
        (5000000000, 1640995200),
        (6000000000, 1677628800),
        (7000000000, 1706745600),
        (7500000000, 1727740800),
        (8000000000, 1748736000)
    ]

    /// Estimated unix time, or nil.
    public static func estimate(userId: Int64) -> Int64? {
        if userId <= 0 {
            return nil
        }
        if userId <= points[0].0 {
            return points[0].1
        }
        for i in 1 ..< points.count {
            if userId <= points[i].0 {
                let a = points[i - 1]
                let b = points[i]
                let f = Double(userId - a.0) / Double(b.0 - a.0)
                return a.1 + Int64(Double(b.1 - a.1) * f)
            }
        }
        let a = points[points.count - 2]
        let b = points[points.count - 1]
        let rate = Double(b.1 - a.1) / Double(b.0 - a.0)
        let t = b.1 + Int64(Double(userId - b.0) * rate)
        return min(t, Int64(Date().timeIntervalSince1970))
    }

    public static func format(userId: Int64) -> String? {
        guard let t = estimate(userId: userId) else {
            return nil
        }
        let months = ["yanvar", "fevral", "mart", "aprel", "may", "iyun", "iyul", "avgust", "sentyabr", "oktyabr", "noyabr", "dekabr"]
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: Date(timeIntervalSince1970: Double(t)))
        let month = max(1, min(12, components.month ?? 1))
        return AlfaCyrillic.ui("~ \(components.year ?? 0)-yil \(months[month - 1])")
    }
}
