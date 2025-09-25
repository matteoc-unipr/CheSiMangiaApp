//
//  AppViewModel.swift
//  CheSiMangia
//
//  Created by Matteo Costella on 25/09/25.
//


import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published var isScanning = false
    @Published var lastScanError: String?
    @Published var isGenerating = false
    @Published var generated: [Recipe] = []

    let pantry = PantryStore.shared
    var generator: RecipeGenerator = MockRecipeService() // sostituibile in runtime

    func handleScanned(barcode: String) {
        Task {
            do { let p = try await OFFClient.shared.fetchProduct(barcode: barcode); try pantry.addOFFProduct(p) }
            catch { lastScanError = "Prodotto non trovato o errore rete." }
        }
    }

    func generateRecipes(using product: CDProduct?) {
        guard let prefs = pantry.prefs else { return }
        let up = UserPrefs(vegetarian: prefs.vegetarian, lactoseFree: prefs.lactoseFree, peanutFree: prefs.peanutFree, maxMinutes: Int(prefs.maxMinutes), skill: prefs.skill ?? "beginner")
        let pantryNames = pantry.products.map { $0.name ?? "" }
        let mustUse = [product?.name ?? pantry.products.first?.name ?? "ingredienti"]
        let req = RecipeRequest(pantry: pantryNames, mustUse: mustUse, servings: 2, maxMinutes: up.maxMinutes, skill: up.skill, prefs: up)
        isGenerating = true
        Task { [weak self] in
            defer { self?.isGenerating = false }
            do { self?.generated = try await self?.generator.generate(req) ?? [] } catch { self?.generated = [] }
        }
    }
}
