import Foundation

public func short(_ n: Int) -> String {
    if abs(n) < 1000 { return "\(n)" }
    let units: [(Double, String)] = [(1e9, "B"), (1e6, "M"), (1e3, "K")]
    let v = Double(abs(n))
    for (i, (size, suffix)) in units.enumerated() where v >= size {
        let rounded = (v / size * 10).rounded() / 10
        if rounded >= 1000, i > 0 { return (n < 0 ? "-" : "") + trim(rounded / 1000) + units[i - 1].1 }   // 999.95K is 1M
        return (n < 0 ? "-" : "") + trim(rounded) + suffix
    }
    return "\(n)"
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

public func number(from text: String) -> Int {
    let digits = text.filter(\.isNumber).prefix(15)
    return Int(digits) ?? 0
}
