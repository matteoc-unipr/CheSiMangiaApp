//
//  Models.swift
//  CheSiMangia
//
//  Created by Matteo Costella on 25/09/25.
//

import Foundation


struct Nutriments: Codable { let energyKcal: Double?; let proteins: Double?; let fat: Double?; let carbs: Double? }


struct OFFProduct: Decodable {
let status: Int
let product: Product?
struct Product: Decodable {
let code: String?; let product_name: String?; let brands: String?
let ingredients_text: String?; let allergens: String?
let image_url: String?; let nutriscore_grade: String?; let nova_group: Int?
let nutriments: [String: Double]?
}
}


struct Recipe: Identifiable, Codable { let id: UUID = .init(); let title: String; let ingredients: [String]; let steps: [String]; let minutes: Int; let kcalPerServing: Int?; let variants: [String] }


struct RecipeRequest { let pantry: [String]; let mustUse: [String]; let servings: Int; let maxMinutes: Int; let skill: String; let prefs: UserPrefs }


struct UserPrefs: Codable { var vegetarian: Bool; var lactoseFree: Bool; var peanutFree: Bool; var maxMinutes: Int; var skill: String }
