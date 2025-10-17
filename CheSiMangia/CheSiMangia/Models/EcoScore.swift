//
//  EcoScore.swift
//  CheSiMangia
//
//  Created by Matteo Costella on 25/09/25.
//


import Foundation

enum EcoScore {
    // kg CO2e per kg alimento (fonti medie pubbliche; semplificate)
    private static let kgCO2ePerKg: [(keys: [String], val: Double)] = [
        (["manzo","bovino"], 27),
        (["agnello"], 24),
        (["formaggio","parmigiano","pecorino","grana","mozzarella"], 13.5),
        (["maiale"], 12),
        (["pollo","tacchino","carne bianca"], 6),
        (["pesce","tonno","salmone","merluzzo"], 6),
        (["uova","uovo"], 4.8),
        (["riso"], 4),
        (["olio","olio evo","olio extravergine"], 5),
        (["burro"], 12),
        (["pasta","farro","orzo","pane"], 1.8),
        (["latte","yogurt"], 3),
        (["legumi","ceci","fagioli","lenticchie","borlotti","cannellini"], 0.9),
        (["verdura","zucchine","pomodoro","spinaci","melanzane","peperoni","cipolla","carote","insalata"], 0.5),
        (["frutta","limone","arancia","mela"], 0.7),
        (["olive","capperi"], 1.2)
    ]

    private static func impactPerKg(for name: String) -> Double? {
        let n = name.lowercased()
        for e in kgCO2ePerKg {
            if e.keys.contains(where: { n.contains($0) }) { return e.val }
        }
        return nil
    }

    /// Ritorna un punteggio 1 (peggiore) … 5 (migliore) per porzione
    static func score(for ingredients: [String], servings: Int) -> Int {
        var totalKgCO2e: Double = 0
        for line in ingredients {
            guard let p = NutritionEstimator.parse(line),
                  let kg = impactPerKg(for: p.name)
            else { continue }
            totalKgCO2e += (p.grams / 1000.0) * kg
        }
        guard servings > 0, totalKgCO2e > 0 else { return 3 } // neutro

        let perServing = totalKgCO2e / Double(servings)

        // Soglie semplici (adatta se vuoi)
        switch perServing {
        case ..<0.5:   return 5   // molto basso impatto
        case ..<1.0:   return 4
        case ..<2.0:   return 3
        case ..<3.5:   return 2
        default:       return 1   // alto impatto
        }
    }
}
