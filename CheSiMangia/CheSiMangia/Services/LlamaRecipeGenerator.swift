//
//  LlamaRecipeGenerator.swift
//  CheSiMangia
//
//  Created by Matteo Costella on 05/10/25.
//
// LlamaRecipeGenerator.swift

import Foundation

// MARK: - DTO per decodificare l'output del modello
private struct GenResponse: Decodable {
    let recipes: [GenRecipe]
    struct GenRecipe: Decodable {
        let title: String
        let minutes: LossyInt?
        let kcalPerServing: LossyInt?
        let ingredients: [String]
        let steps: [String]
        let variants: [String]?
    }
}

// MARK: - Generator
@MainActor
final class LlamaRecipeGenerator: RecipeGenerator {
    
    private let llama: LlamaState
    
    init(llama: LlamaState) {
        self.llama = llama
    }
    
    // MARK: RecipeGenerator
    func generate(_ req: RecipeRequest) async throws -> [Recipe] {
        // 1) Prompt con marker finale <END_JSON> (assicurati che makePrompt lo aggiunga nelle RULES)
        let prompt = makePrompt(req: req)

        // 2) Run del modello con stop sul marker
        await llama.clear()
        await llama.completion_init(text: prompt)

        var buffer = ""
        var steps = 0
        let endMarker = "<END_JSON>"

        while await !llama.is_done {
            let chunk = await llama.completion_loop()
            buffer += chunk

            if let r = buffer.range(of: endMarker) {
                buffer = String(buffer[..<r.lowerBound]) // taglia il marker e tutto ciò che segue
                break
            }

            steps += 1
            if steps > 8000 { break } // hard stop di sicurezza
        }

        // 3) Parsing JSON robusto
        guard let json = extractJSONObject(from: buffer) else {
            print("[LLAMA] JSON non trovato nell'output:\n\(buffer)")
            throw RecipeGenError.failed
        }

        let decoded: GenResponse
        do {
            decoded = try JSONDecoder().decode(GenResponse.self, from: Data(json.utf8))
        } catch {
            print("[LLAMA] Decode fallito: \(error)\nJSON:\n\(json)")
            throw RecipeGenError.failed
        }

        // 4) Mapping (lascia il tuo come già fatto)
        let mapped: [Recipe] = decoded.recipes.prefix(5).map {
            Recipe(
                title: $0.title.trimmingCharacters(in: .whitespacesAndNewlines),
                ingredients: $0.ingredients.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
                steps: $0.steps.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
                minutes: max(1, min(req.maxMinutes, $0.minutes?.value ?? req.maxMinutes)),
                kcalPerServing: $0.kcalPerServing?.value,
                variants: ($0.variants ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            )
        }

        return mapped
    }

    
    // MARK: Prompting
    private func makePrompt(req: RecipeRequest) -> String {
        let staples = [
            "sale", "pepe", "olio extravergine di oliva", "acqua",
            "aglio", "cipolla", "erbe secche", "limone", "aceto"
        ]
        
        let pantryList = (req.pantry + staples).uniqueStable().joined(separator: "\n- ")
        let must = req.mustUse.uniqueStable().joined(separator: ", ")
        let vegetarian = req.prefs.vegetarian ? "true" : "false"
        let lactoseFree = req.prefs.lactoseFree ? "true" : "false"
        let peanutFree = req.prefs.peanutFree ? "true" : "false"
        
        return """
        <SYSTEM>
        You are an expert Italian cooking assistant. 
        Your goal is to create realistic and appealing recipes inspired by traditional Italian and Mediterranean cuisine.
        The recipes must be written in Italian, using natural and authentic culinary language.
        Avoid fancy gourmet style; prefer simple, home-style dishes that real people can cook.
        
        Focus on:
        - Mediterranean ingredients, olive oil, herbs, seasonal vegetables, grains, legumes, and fish or dairy (when allowed)
        - Italian naming conventions (titles, ingredients, and steps all in Italian)
        - Practical and realistic preparation steps
        </SYSTEM>
        
        <USER>
        AVAILABLE INGREDIENTS (use mainly these; small amounts of pantry staples are allowed):
        - \(pantryList)
        
        MUST-HAVE INGREDIENTS (use at least one of these): \(must)
        
        DIETARY CONSTRAINTS:
        - vegetarian: \(vegetarian)
        - lactose-free: \(lactoseFree)
        - peanut-free: \(peanutFree)
        - maximum time: \(req.maxMinutes) minutes
        - skill level: \(req.skill)
        - servings: \(req.servings)
        
            
        OUTPUT FORMAT:
        Return ONLY valid JSON, without any extra text, formatted exactly like this:
        {
            "recipes": [
            {
                "title": "string",
                "minutes": number,
                "kcalPerServing": number|null,
                "ingredients": ["string", "..."],
                "steps": ["string", "..."],
                "variants": ["string", "..."]
            }
            ]
        }
         
        RULES:
        - Generate between 3 and 5 recipes.
        - Do NOT add introductions, explanations, or commentary outside the JSON.
        - Recipes must be written entirely in Italian.
        - Each recipe should reflect Italian or Mediterranean style.
        - Ingredients must be consistent with the available list (plus pantry staples: sale, olio, pepe, aglio, cipolla, limone, aceto, erbe secche).
        - Steps should be clear, concise, and sequential.
        - The total preparation time must not exceed \(req.maxMinutes) minutes.
        - After the JSON, print exactly the string <END_JSON> and nothing else.
        </USER>
        """
    }
    
    
    // MARK: JSON extraction helper
    private func extractJSONObject(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{") else { return nil }
        var candidate = String(text[start...])
        
        // 1) Bilancia parentesi graffe e quadre
        func balanced(_ s: String) -> String {
            var openCurly = 0, openSquare = 0
            for ch in s {
                if ch == "{" { openCurly += 1 }
                else if ch == "}" { openCurly = max(0, openCurly - 1) }
                else if ch == "[" { openSquare += 1 }
                else if ch == "]" { openSquare = max(0, openSquare - 1) }
            }
            var fixed = s
            
            // 2) Toglie eventuale virgola finale prima della chiusura
            func trimTrailingComma(_ s: inout String) {
                while s.last?.isWhitespace == true { s.removeLast() }
                if s.last == "," { s.removeLast() }
            }
            
            // Chiudi prima i quadretti, poi le graffe (ordine plausibile per il nostro schema)
            for _ in 0..<openSquare {
                trimTrailingComma(&fixed)
                fixed.append("]")
            }
            for _ in 0..<openCurly {
                trimTrailingComma(&fixed)
                fixed.append("}")
            }
            return fixed
        }
        
        // Se già completo, torna subito
        var depth = 0
        var closedAt: String.Index?
        for i in candidate.indices {
            let ch = candidate[i]
            if ch == "{" { depth += 1 }
            else if ch == "}" {
                depth -= 1
                if depth == 0 { closedAt = i; break }
            }
        }
        if let end = closedAt { return String(candidate[candidate.startIndex...end]) }
        
        // Altrimenti prova a riparare
        candidate = balanced(candidate)
        
        // Verifica di nuovo
        depth = 0; closedAt = nil
        for i in candidate.indices {
            let ch = candidate[i]
            if ch == "{" { depth += 1 }
            else if ch == "}" {
                depth -= 1
                if depth == 0 { closedAt = i; break }
            }
        }
        return closedAt.map { String(candidate[candidate.startIndex...$0]) }
    }
}

extension Array where Element: Hashable {
    /// Mantiene il primo ordine d’apparizione.
    func uniqueStable() -> [Element] {
        var seen = Set<Element>()
        return self.filter { seen.insert($0).inserted }
    }
}

/// Accetta Int, Double o String e prova a estrarre un intero sensato.
/// Esempi validi: 20, 20.0, "22", "22-25", "30 min", "≈15"
private struct LossyInt: Decodable {
    let value: Int?
    
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        
        if let i = try? c.decode(Int.self) {
            value = i
            return
        }
        if let d = try? c.decode(Double.self) {
            value = Int(d.rounded())
            return
        }
        if let s = try? c.decode(String.self) {
            // prendi la prima sequenza di cifre
            if let match = s.range(of: #"(?<!\d)\d{1,4}(?!\d)"#, options: .regularExpression) {
                value = Int(s[match])
            } else {
                value = nil
            }
            return
        }
        value = nil
    }
}
