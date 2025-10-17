//
//  OFFQuantityNormalizer.swift
//  CheSiMangia
//
//  Created by Matteo Costella on 16/10/25.
//

import Foundation

enum OFFUnit: String { case g, kg, ml, l }

private func toDouble(_ v: JSONValue?) -> Double? {
    guard let v else { return nil }
    switch v {
    case .number(let n): return n
    case .string(let s): return Double(s.replacingOccurrences(of: ",", with: "."))
    default: return nil
    }
}

private func normalizeUnit(_ raw: String?) -> OFFUnit? {
    guard let s = raw?.lowercased() else { return nil }
    switch s {
    case "g", "gr", "gram", "grams", "grammi": return .g
    case "kg", "kilogram", "chilogrammi": return .kg
    case "ml", "milliliter", "milliliters", "millilitri": return .ml
    case "l", "lt", "liter", "liters", "litri": return .l
    default: return nil
    }
}

/// Prova a ricavare per-unità da product_quantity/unit.
/// Se mancano, tenta un parse di `quantity` tipo "6 x 125 g" → per unità 125 g.
func extractPerUnit(from p: OFFProduct.Product) -> (value: Double, unit: OFFUnit)? {
    if let v = toDouble(p.product_quantity), let u = normalizeUnit(p.product_quantity_unit) {
        return (v, u)
    }
    // fallback: quantity testo libero "6 x 125 g", "2×200 ml" → prendi la parte per unità
    if let q = p.quantity?.lowercased() {
        // cerca "125 g" o "200 ml"
        if let m = q.range(of: #"(\d+(?:[.,]\d+)?)\s*(kg|g|ml|l|lt|gr)"#,
                           options: .regularExpression) {
            let sub = String(q[m])
            let comps = sub.replacingOccurrences(of: ",", with: ".").split(separator: " ")
            if comps.count >= 2, let num = Double(comps[0]) {
                let unit = normalizeUnit(String(comps[1])) ?? (String(comps[1]) == "lt" ? .l : nil)
                if let u = unit { return (num, u) }
            }
        }
    }
    return nil
}

/// Converte a g/ml come comodo display
func display(_ value: Double, unit: OFFUnit) -> String {
    switch unit {
    case .g:
        return value >= 1000 ? String(format: "%.0f kg", value/1000) : "\(Int(value)) g"
    case .kg:
        return value >= 1 ? String(format: "%.2f kg", value) : "\(Int(value*1000)) g"
    case .ml:
        return value >= 1000 ? String(format: "%.0f l", value/1000) : "\(Int(value)) ml"
    case .l:
        return value >= 1 ? String(format: "%.2f l", value) : "\(Int(value*1000)) ml"
    }
}
