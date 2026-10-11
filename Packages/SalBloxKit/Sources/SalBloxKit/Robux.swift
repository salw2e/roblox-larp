import Foundation

public enum Ledger {
    public static let incoming = ["Sales of Goods", "Premium Stipends", "Premium Payouts", "Group Payouts", "Currency Purchases"]
    public static let outgoing = ["Purchases"]
    public static let pending = "Pending Robux"

    public static let periods = ["Past Day", "Past Week", "Past Month", "Past Year"]
    public static func amount(_ monthly: Int, in period: String) -> Int {
        switch period {
        case "Past Day": return monthly / 30
        case "Past Week": return monthly * 7 / 30
        case "Past Year": return monthly * 12
        default: return monthly
        }
    }
}

public enum Purchase: Equatable, Sendable { case bought, alreadyOwned, offSale, tooExpensive }

public func robuxPacksFor(shortfall: Int) -> [(robux: Int, price: String, better: Bool)] {
    let packs: [(Int, String)] = [(40, "$0.49"), (80, "$0.99"), (320, "$3.99"), (400, "$4.99"), (800, "$9.99"), (1_200, "$14.99"),
                                  (1_700, "$19.99"), (3_150, "$34.99"), (4_500, "$49.99"), (10_000, "$99.99"), (22_500, "$199.99")]
    guard shortfall > 0, let i = packs.firstIndex(where: { $0.0 >= shortfall }) else { return [] }
    var out = [(robux: packs[i].0, price: packs[i].1, better: false)]
    if i + 1 < packs.count { out.append((robux: packs[i + 1].0, price: packs[i + 1].1, better: true)) }
    return out
}
