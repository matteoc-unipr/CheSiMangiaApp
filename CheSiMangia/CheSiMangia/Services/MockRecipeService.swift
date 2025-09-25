//
//  MockRecipeService.swift
//  CheSiMangia
//
//  Created by Matteo Costella on 25/09/25.
//


import Foundation

final class MockRecipeService: RecipeGenerator {
    func generate(_ req: RecipeRequest) async throws -> [Recipe] {
        // Filtri preferenze semplici
        func pass(_ name: String) -> Bool {
            let l = name.lowercased()
            if req.prefs.vegetarian && (l.contains("pollo") || l.contains("manzo") || l.contains("pesce")) { return false }
            if req.prefs.lactoseFree && (l.contains("latte") || l.contains("formaggio") || l.contains("burro")) { return false }
            if req.prefs.peanutFree && l.contains("arachidi") { return false }
            return true
        }
        let must = req.mustUse.joined(separator: ", ")
        let base = [
            Recipe(title: "\(must) saltato express", ingredients: ["\(must)", "olio", "sale", "pepe"], steps: ["Taglia", "Salta in padella", "Servi"], minutes: min(15, req.maxMinutes), kcalPerServing: 450, variants: ["Aggiungi peperoncino", "Con limone"]),
            Recipe(title: "Insalata con \(must)", ingredients: ["\(must)", "insalata mista", "olio", "aceto"], steps: ["Lava", "Condisci", "Mescola"], minutes: 10, kcalPerServing: 350, variants: ["Con semi di zucca"]),
            Recipe(title: "Pasta con \(must)", ingredients: ["pasta", "\(must)", "olio", "sale"], steps: ["Cuoci pasta", "Salta con condimento", "Servi"], minutes: 20, kcalPerServing: 600, variants: ["Con pomodorini"])
        ].filter { pass($0.title) }
        return Array(base.prefix(3))
    }
}
