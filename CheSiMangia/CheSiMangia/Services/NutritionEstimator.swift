import Foundation

struct IngredientParsed {
    let grams: Double
    let name: String
}

enum NutritionEstimator {
    // kcal per 100g (stima media, facile da estendere)
    static let kcal100: [(keys: [String], kcal: Double)] = [
        (["pasta","spaghetti","penne"], 350),
        (["riso"], 360),
        (["farro","orzo"], 340),
        (["pane"], 260),
        (["patate"], 80),
        (["pomodoro","pomodori"], 18),
        (["zucchine"], 17),
        (["melanzane"], 25),
        (["peperoni"], 31),
        (["cipolla","scalogno","porro"], 40),
        (["aglio"], 149),
        (["carote"], 41),
        (["spinaci"], 23),
        (["ceci","fagioli","lenticchie","borlotti","cannellini"], 120),   // cotti
        (["tonno","salmone","merluzzo","pesce"], 180),                    // media
        (["pollo","tacchino"], 165),
        (["manzo","bovino"], 250),
        (["maiale"], 242),
        (["uova","uovo"], 143),
        (["latte"], 64),
        (["yogurt"], 60),
        (["mozzarella"], 250),
        (["parmigiano","pecorino","grana"], 390),
        (["olio","olio evo","olio extravergine"], 884),
        (["burro"], 717),
        (["formaggio","ricotta"], 180),
        (["olive"], 115),
        (["capperi"], 23),
        (["tonno sott'olio"], 200)
    ]

    static func matchKcal100(for name: String) -> Double? {
        let n = name.lowercased()
        for e in kcal100 {
            if e.keys.contains(where: { n.contains($0) }) { return e.kcal }
        }
        return nil
    }

    // molto semplice: g/kg/ml/l + “cucchiaio/i” e “cucchiaino/i” (olio, semi-liquidi)
    static func parse(_ raw: String) -> IngredientParsed? {
        let s = raw.lowercased()
        // estrae numero + unità
        let regex = try! NSRegularExpression(
            pattern: #"^\s*([0-9]+(?:[.,][0-9]+)?)\s*(kg|g|l|ml|cucchiai|cucchiaio|cucchiaini|cucchiaino|uova|uovo|spicchi)?\s+(.*)$"#)
        guard let m = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let qR = Range(m.range(at: 1), in: s),
              let uR = Range(m.range(at: 2), in: s),
              let nameR = Range(m.range(at: 3), in: s)
        else { return nil }

        let q = Double(s[qR].replacingOccurrences(of: ",", with: ".")) ?? 0
        let unit = String(s[uR])
        let name = s[nameR].trimmingCharacters(in: .whitespaces)

        let grams: Double = {
            switch unit {
            case "kg": return q * 1000
            case "g":  return q
            case "l":  return q * 1000 * density(for: name)       // densità semplificate
            case "ml": return q * density(for: name)
            case "cucchiaio", "cucchiai":
                // 1 cucchiaio ≈ 10–15 ml: usiamo 12 ml
                return 12 * density(for: name) * q
            case "cucchiaino", "cucchiaini":
                // 1 cucchiaino ≈ 5 ml
                return 5 * density(for: name) * q
            case "uova","uovo":
                // 1 uovo medio ≈ 60 g
                return 60 * q
            default:
                // fallback: se non riconosciamo l'unità, ignora
                return 0
            }
        }()

        guard grams > 0 else { return nil }
        return IngredientParsed(grams: grams, name: name)
    }

    // densità approssimative (g/ml)
    static func density(for name: String) -> Double {
        let n = name.lowercased()
        if n.contains("olio") { return 0.91 }
        if n.contains("latte") || n.contains("yogurt") { return 1.03 }
        if n.contains("miele") { return 1.42 }
        return 1.0 // acqua / brodi / generici
    }

    /// kcal totali e per porzione
    static func kcalPerServing(ingredients: [String], servings: Int) -> Int? {
        guard servings > 0 else { return nil }
        var total: Double = 0
        for line in ingredients {
            guard let p = parse(line), let kcal100 = matchKcal100(for: p.name) else { continue }
            total += (p.grams * kcal100) / 100.0
        }
        guard total > 0 else { return nil }
        return Int((total / Double(servings)).rounded())
    }
}
