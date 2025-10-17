//
//  RecipeAPIService.swift
//  CheSiMangia
//
//  Created by Matteo Costella on 11/10/25.
//

import Foundation

// MARK: - Schema request/response del server FastAPI

private struct APIConstraints: Codable {
    var servings: Int
    var max_minutes: Int?
    var diet: String?
    var cuisine: String?
    var avoid: [String]?
    var appliances: [String]?
    var language: String
    var style: String?
}

private struct APIPantryItem: Codable {
    let name: String
    let quantity: String?
}

private struct APIGenerateRequest: Codable {
    let pantry: [APIPantryItem]
    let count: Int
    let constraints: APIConstraints
}

private struct APIRecipe: Codable {
    let title: String
    let ingredients: [String]
    let instructions: [String]
    let estimated_minutes: Int?
    let servings: Int?
    let notes: String?
}

private struct APIGenerateResponse: Codable {
    let recipes: [APIRecipe]
}

// MARK: - Implementazione concreta del tuo protocollo

final class RecipeAPIService: RecipeGenerator {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func generate(_ req: RecipeRequest) async throws -> [Recipe] {
        // Mappa pantry in nome + (opzionale) quantità; qui usiamo solo il nome
        let items: [APIPantryItem]
        if let det = req.pantryDetailed {
            items = det.map { APIPantryItem(name: $0.name, quantity: $0.quantity) }
        } else {
            items = req.pantry.map { APIPantryItem(name: $0, quantity: nil) }
        }

        // Mappa preferenze dell'app nel contratto del server
        var avoid: [String] = []
        if req.prefs.peanutFree { avoid.append("arachidi") }
        if req.prefs.lactoseFree { avoid.append(contentsOf: ["latte", "formaggio", "burro"]) }

        let diet: String? = req.prefs.vegetarian ? "vegetariana" : nil

        let constraints = APIConstraints(
            servings: req.servings,
            max_minutes: req.maxMinutes,
            diet: diet,
            cuisine: nil,                 // se vuoi, passa una preferenza di cucina qui
            avoid: avoid.isEmpty ? nil : avoid,
            appliances: ["fornello"],     // opzionale: modifica in base alle tue capacità
            language: "it",
            style: req.skill              // "beginner", "home", "gourmet"… lo usiamo come style
        )

        let body = APIGenerateRequest(
            pantry: items,
            count: 3,
            constraints: constraints
        )
        
        var urlReq = URLRequest(url: baseURL.appending(path: "/recipes/generate"))
        urlReq.httpMethod = "POST"
        urlReq.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlReq.httpBody = try JSONEncoder().encode(body)

        // timeout un po’ più alto perché il modello locale può essere lento
        let (data, resp) = try await session.data(for: urlReq, delegate: nil)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw RecipeGenError.failed
        }

        let decoded = try JSONDecoder().decode(APIGenerateResponse.self, from: data)

        // Adatta lo schema del server al tuo modello UI
        let mapped: [Recipe] = decoded.recipes.map { r in
            Recipe(
                title: r.title,
                ingredients: r.ingredients,
                steps: r.instructions,
                minutes: r.estimated_minutes ?? req.maxMinutes,
                kcalPerServing: nil,          // il server non le fornisce (per ora)
                variants: []                  // puoi popolarle da r.notes se vuoi
            )
        }

        // Metti in testa le ricette che contengono gli “mustUse” nella UI (se presenti)
        let must = req.mustUse.map { $0.lowercased() }
        let scored = mapped.sorted { a, b in
            let sa = score(recipe: a, must: must)
            let sb = score(recipe: b, must: must)
            return sa > sb
        }
        return scored
    }

    private func score(recipe: Recipe, must: [String]) -> Int {
        guard !must.isEmpty else { return 0 }
        let title = recipe.title.lowercased()
        let ing = recipe.ingredients.joined(separator: " ").lowercased()
        return must.reduce(0) { acc, m in
            acc + (title.contains(m) ? 2 : 0) + (ing.contains(m) ? 1 : 0)
        }
    }
}
