import Foundation

public func short(_ n: Int) -> String {
    if abs(n) < 1000 { return "\(n)" }
    let units: [(Double, String)] = [(1e12, "T"), (1e9, "B"), (1e6, "M"), (1e3, "K")]
    let v = Double(abs(n))
    for (i, (size, suffix)) in units.enumerated() where v >= size {
        let rounded = (v / size * 10).rounded() / 10
        if rounded >= 1000, i > 0 { return (n < 0 ? "-" : "") + trim(rounded / 1000) + units[i - 1].1 }   // 999.95K is 1M
        return (n < 0 ? "-" : "") + trim(rounded) + suffix
    }
    return "\(n)"
}

public func counted(_ n: Int, _ one: String) -> String {
    "\(short(n)) \(n == 1 ? one : one + "s")"
}

private func trim(_ d: Double) -> String {
    d == d.rounded() ? String(Int(d)) : String(format: "%.1f", d)
}

public func priceText(_ price: Int?) -> String {
    guard let price else { return "Off Sale" }
    return price == 0 ? "Free" : grouped(price)
}

public func grouped(_ n: Int) -> String {
    let digits = String(n.magnitude)
    var out = ""
    for (i, c) in digits.enumerated() {
        if i > 0, (digits.count - i) % 3 == 0 { out.append(",") }
        out.append(c)
    }
    return (n < 0 ? "-" : "") + out
}

public func digits(in text: String) -> String {
    String(text.filter { $0.isASCII && $0.isNumber }.prefix(15))
}

public func chatTime(_ at: Double, now: Date = Date(), zone: TimeZone = .current) -> String {
    let s = max(0, now.timeIntervalSince1970 - at)
    switch s {
    case ..<60: return "now"
    case ..<3600: return "\(Int(s / 60))m"
    case ..<86400: return "\(Int(s / 3600))h"
    case ..<(7 * 86400): return "\(Int(s / 86400))d"
    case ..<(28 * 86400): return "\(Int(s / (7 * 86400)))w"
    default:
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.timeZone = zone
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: Date(timeIntervalSince1970: at))
    }
}

public func number(from text: String) -> Int {
    Int(digits(in: text)) ?? 0
}

public func cleanUsername(_ text: String) -> String {
    String(text.filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }.prefix(20))
}
