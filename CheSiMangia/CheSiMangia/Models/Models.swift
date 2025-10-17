//
//  Models.swift
//  CheSiMangia
//
//  Created by Matteo Costella on 25/09/25.
//

import Foundation

import Foundation

enum JSONValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let arr = try? c.decode([JSONValue].self) { self = .array(arr) }
        else if let obj = try? c.decode([String: JSONValue].self) { self = .object(obj) }
        else { throw DecodingError.typeMismatch(JSONValue.self, .init(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON type")) }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let n): try c.encode(n)
        case .bool(let b): try c.encode(b)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        case .null: try c.encodeNil()
        }
    }
}

struct OFFProduct: Decodable {
    let status: Int
    let product: Product?
    struct Product: Decodable {
        let code: String?
        let product_name: String?
        let brands: String?
        let ingredients_text: String?
        let allergens: String?
        let image_url: String?
        let nutriscore_grade: String?
        let nova_group: Int?
        let nutriments: [String: JSONValue]?   
        let product_quantity: JSONValue?       // es. 150 (spesso numero, ma può arrivare come string)
        let product_quantity_unit: String?     // es. "g" o "ml"
        let quantity: String?
    }
}


struct Nutriments: Codable { let energyKcal: Double?; let proteins: Double?; let fat: Double?; let carbs: Double? }


struct Recipe: Identifiable, Codable { let id: UUID = .init(); let title: String; let ingredients: [String]; let steps: [String]; let minutes: Int; var kcalPerServing: Int?; let variants: [String]; var servings: Int = 1  }


struct RecipeRequest { let pantry: [String]; let pantryDetailed: [PantryNameQty]?; let mustUse: [String]; let servings: Int; let maxMinutes: Int; let skill: String; let prefs: UserPrefs }


struct UserPrefs: Codable { var vegetarian: Bool; var lactoseFree: Bool; var peanutFree: Bool; var maxMinutes: Int; var skill: String; var servings: Int  }

struct PantryNameQty: Codable {
    let name: String
    let quantity: String? // es. "300 g" o "500 ml"
}
