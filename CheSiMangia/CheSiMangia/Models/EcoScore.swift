//
//  EcoScore.swift
//  CheSiMangia
//
//  Created by Matteo Costella on 25/09/25.
//


import Foundation

enum EcoScore { static func score(for ingredients: [String]) -> Int {
    let weights: [(String, Int)] = [
        ("manzo", 5),("bovino",5),("maiale",3),("pollo",2),("tacchino",2),("pesce",2),
        ("lattic",2),("uova",1),("legumi",1),("ceci",1),("fagioli",1),("lenticchie",1)
    ]
    let total = ingredients.reduce(0) { sum, ing in
        let l = ing.lowercased()
        let add = weights.first(where: { l.contains($0.0) })?.1 ?? 1
        return sum + add
    }
    return min(10, max(1, total / max(1, ingredients.count)))
} }
