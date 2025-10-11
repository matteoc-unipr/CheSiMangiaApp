//
//  Recipe+CoreData.swift
//  CheSiMangia
//
//  Created by Matteo Costella on 11/10/25.
//

import Foundation
import CoreData

extension Recipe {
    init?(from cd: CDRecipe) {
        guard let title = cd.title,
              let ingData = cd.ingredientsJSON,
              let stepsData = cd.stepsJSON,
              let createdAt = cd.createdAt,
              let id = cd.id else { return nil }

        let ingredients = (try? JSONDecoder().decode([String].self, from: ingData)) ?? []
        let steps = (try? JSONDecoder().decode([String].self, from: stepsData)) ?? []
        let variants: [String]
        if let v = cd.variantsJSON {
            variants = (try? JSONDecoder().decode([String].self, from: v)) ?? []
        } else {
            variants = []
        }

        self.init(
            title: title,
            ingredients: ingredients,
            steps: steps,
            minutes: Int(cd.minutes),
            kcalPerServing: cd.kcalPerServing == 0 ? nil : Int(cd.kcalPerServing),
            variants: variants
        )
    }
}

extension CDRecipe {
    func apply(from r: Recipe, now: Date = .now) {
        self.id = r.id
        self.title = r.title
        self.minutes = Int16(r.minutes)
        self.kcalPerServing = Int32(r.kcalPerServing ?? 0)
        self.createdAt = now
        self.ingredientsJSON = try? JSONEncoder().encode(r.ingredients)
        self.stepsJSON = try? JSONEncoder().encode(r.steps)
        self.variantsJSON = r.variants.isEmpty ? nil : (try? JSONEncoder().encode(r.variants))
    }
}
