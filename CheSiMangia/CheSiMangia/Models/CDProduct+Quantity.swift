//
//  CDProduct+Quantity.swift
//  CheSiMangia
//
//  Created by Matteo Costella on 16/10/25.
//

import Foundation

extension CDProduct {
    struct ParsedQuantity {
        let value: Double     // nella sua unità normalizzata
        let unit: String      // "g","kg","ml","l"
        let display: String   // es. "150 g" o "0.5 kg"
    }

    var perUnitQuantity: ParsedQuantity? {
        guard let u = perUnitUnit, let v = (perUnitValue as NSNumber?)?.doubleValue, v > 0 else {
            return nil
        }
        // display carino
        let shown: String
        switch u {
        case "g":
            shown = v >= 1000 ? String(format: "%.0f kg", v/1000) : "\(Int(v)) g"
        case "kg":
            shown = v >= 1 ? String(format: "%.2f kg", v) : "\(Int(v*1000)) g"
        case "ml":
            shown = v >= 1000 ? String(format: "%.0f l", v/1000) : "\(Int(v)) ml"
        case "l":
            shown = v >= 1 ? String(format: "%.2f l", v) : "\(Int(v*1000)) ml"
        default:
            shown = "\(v) \(u)"
        }
        return ParsedQuantity(value: v, unit: u, display: shown)
    }

    var totalQuantity: ParsedQuantity? {
        guard let per = perUnitQuantity else { return nil }
        let pieces = max(1, Int(self.quantity)) // numero di pezzi
        let totalValue: Double
        switch per.unit {
        case "kg", "l":
            totalValue = per.value * Double(pieces)
        case "g", "ml":
            totalValue = per.value * Double(pieces)
        default:
            totalValue = per.value * Double(pieces)
        }
        // render finale
        let disp: String
        switch per.unit {
        case "g":
            disp = totalValue >= 1000 ? String(format: "%.0f kg", totalValue/1000) : "\(Int(totalValue)) g"
        case "kg":
            disp = totalValue >= 1 ? String(format: "%.2f kg", totalValue) : "\(Int(totalValue*1000)) g"
        case "ml":
            disp = totalValue >= 1000 ? String(format: "%.0f l", totalValue/1000) : "\(Int(totalValue)) ml"
        case "l":
            disp = totalValue >= 1 ? String(format: "%.2f l", totalValue) : "\(Int(totalValue*1000)) ml"
        default:
            disp = "\(totalValue) \(per.unit)"
        }
        return ParsedQuantity(value: totalValue, unit: per.unit, display: disp)
    }

    var perUnitDisplay: String? { perUnitQuantity?.display }
    var totalDisplay: String? { totalQuantity?.display }
}
