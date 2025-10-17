//
//  AppViewModel.swift
//  CheSiMangia
//
//  Created by Matteo Costella on 25/09/25.
//
import Foundation
import CoreData
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    @Published var isScanning = false
    @Published var lastScanError: String?
    @Published var isGenerating = false
    @Published var generated: [Recipe] = []

    let pantry = PantryStore.shared
    var generator: RecipeGenerator = RecipeAPIService(
        baseURL: URL(string: "http://192.168.0.105:8000")! // server port (cambiare a ogni riavvio server)
    )

    private let ctx = PersistenceController.shared.container.viewContext

    init() {
        Task { await loadSavedRecipes() }
    }

    // MARK: - Scan
    func handleScanned(barcode: String) {
        let code = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else {
            lastScanError = "Barcode vuoto dopo la lettura."
            print("[SCAN] Vuoto dopo sanitizzazione")
            return
        }

        print("[SCAN] Letto barcode: \(code)")

        Task { [weak self] in
            guard let self else { return }
            do {
                let p = try await OFFClient.shared.fetchProduct(barcode: code)
                print("[OFF] Trovato prodotto: \(p.product_name ?? "—") (\(p.code ?? "—"))")
                do {
                    try self.pantry.addOFFProduct(p)
                    print("[STORE] Salvato prodotto OFF con barcode \(code)")
                } catch {
                    self.lastScanError = "Salvataggio prodotto OFF fallito: \(error.localizedDescription)"
                    print("[STORE][ERR] \(error)")
                }
            } catch OFFError.notFound {
                print("[OFF] NOT FOUND per \(code). Creo placeholder locale.")
                do {
                    try self.pantry.addManualProductFromBarcode(code)
                    print("[STORE] Creato placeholder locale per \(code)")
                } catch {
                    self.lastScanError = "Impossibile salvare placeholder (\(code)): \(error.localizedDescription)"
                    print("[STORE][ERR] \(error)")
                }
            } catch {
                self.lastScanError = "Errore rete/parsing per \(code): \(error.localizedDescription)"
                print("[OFF][ERR] \(error)")
            }
        }
    }

    // MARK: - Generazione ricette

    func generateRecipes(using product: CDProduct?) {
        guard let prefs = pantry.prefs else { return }
        let up = UserPrefs(
            vegetarian: prefs.vegetarian,
            lactoseFree: prefs.lactoseFree,
            peanutFree: prefs.peanutFree,
            maxMinutes: Int(prefs.maxMinutes),
            skill: prefs.skill ?? "beginner",
            servings: Int(prefs.servings)
        )

        let pantryNames = fetchPantryProductNames()
        let pantryDetailed = fetchPantryDetailed()
        let mustUse = [product?.name ?? pantryNames.first ?? "ingredienti"]

        let req = RecipeRequest(
            pantry: pantryNames,
            pantryDetailed: pantryDetailed,
            mustUse: mustUse,
            servings: up.servings,
            maxMinutes: up.maxMinutes,
            skill: up.skill,
            prefs: up
        )

        isGenerating = true
        Task { @MainActor in
            defer { isGenerating = false }
            do {
                let newOnes = try await self.generator.generate(req)

                // Post-process: kcal/porz + servings
                let servings = up.servings
                let processed = newOnes.map { r -> Recipe in
                    var out = r
                    if out.kcalPerServing == nil {
                        out.kcalPerServing = NutritionEstimator.kcalPerServing(
                            ingredients: r.ingredients,
                            servings: servings
                        )
                    }
                    out.servings = servings
                    return out
                }

                // MERGE (unico blocco) + dedup per id
                var seen = Set(self.generated.map(\.id))
                var merged = self.generated
                for r in processed where !seen.contains(r.id) {
                    merged.insert(r, at: 0)
                    seen.insert(r.id)
                }
                withAnimation { self.generated = merged }

                // Salva solo le nuove
                await self.persistGenerated(recipesToConsider: processed)

            } catch {
                print("[GEN][ERR] \(error)")
                // non svuotare self.generated in caso d’errore
            }
        }
    }


    // MARK: - Elimina tutte le ricette
    func deleteAllRecipes() {
        // Cancella da Core Data
        let fetch: NSFetchRequest<CDRecipe> = CDRecipe.fetchRequest()
        if let all = try? ctx.fetch(fetch) {
            for obj in all { ctx.delete(obj) }
            try? ctx.save()
        }

        // Svuota l'array pubblicato
        withAnimation {
            generated.removeAll()
        }
    }

    // MARK: - Helpers

    private func fetchPantryProductNames() -> [String] {
        let req: NSFetchRequest<CDProduct> = CDProduct.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        do {
            let items = try ctx.fetch(req)
            return items.compactMap { $0.name }
        } catch {
            print("[STORE][ERR] fetch names: \(error)")
            return []
        }
    }


    /// Carica le ricette salvate e popola `generated`
    func loadSavedRecipes() async {
        let req: NSFetchRequest<CDRecipe> = CDRecipe.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        do {
            let rows = try ctx.fetch(req)
            self.generated = rows.compactMap { Recipe(from: $0) }
        } catch {
            print("[RECIPES][ERR] load: \(error)")
        }
    }

    private func persistGenerated(recipesToConsider: [Recipe]) async {
        // ids già in Core Data
        let existingFetch: NSFetchRequest<CDRecipe> = CDRecipe.fetchRequest()
        let existing = (try? ctx.fetch(existingFetch)) ?? []
        let existingIDs = Set(existing.compactMap { $0.id })

        // salva solo le nuove
        for r in recipesToConsider where !existingIDs.contains(r.id) {
            let obj = CDRecipe(context: ctx)
            obj.apply(from: r)
        }
        do {
            try ctx.save()
        } catch {
            print("[RECIPES][ERR] save: \(error)")
        }
    }


    /// Elimina una ricetta (per swipe o bottone nel dettaglio)
    func deleteRecipe(_ r: Recipe) {
        let req: NSFetchRequest<CDRecipe> = CDRecipe.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", r.id as CVarArg)
        req.fetchLimit = 1
        if let obj = try? ctx.fetch(req).first {
            ctx.delete(obj)
            try? ctx.save()
        }
        if let i = generated.firstIndex(where: { $0.id == r.id }) {
            generated.remove(at: i)
        }
    }
    
    private func fetchPantryDetailed() -> [PantryNameQty] {
        let req: NSFetchRequest<CDProduct> = CDProduct.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        let items = (try? ctx.fetch(req)) ?? []

        return items.map { p in
            PantryNameQty(
                name: p.name ?? "Senza nome",
                quantity: p.totalDisplay // es. "300 g" o "1.5 l"
            )
        }

    }

}
