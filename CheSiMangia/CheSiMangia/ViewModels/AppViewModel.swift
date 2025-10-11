//
//  AppViewModel.swift
//  CheSiMangia
//
//  Created by Matteo Costella on 25/09/25.
//
import Foundation
import CoreData

@MainActor
final class AppViewModel: ObservableObject {
    @Published var isScanning = false
    @Published var lastScanError: String?
    @Published var isGenerating = false
    @Published var generated: [Recipe] = []

    let pantry = PantryStore.shared
    var generator: RecipeGenerator = RecipeAPIService(
        baseURL: URL(string: "http://192.168.0.104:8000")! // server port (cambiare a ogni riavvio server)
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
            skill: prefs.skill ?? "beginner"
        )

        let pantryNames = fetchPantryProductNames()
        let mustUse = [product?.name ?? pantryNames.first ?? "ingredienti"]

        let req = RecipeRequest(
            pantry: pantryNames,
            mustUse: mustUse,
            servings: 2,
            maxMinutes: up.maxMinutes,
            skill: up.skill,
            prefs: up
        )

        isGenerating = true
        Task { [weak self] in
            guard let self else { return }
            defer { self.isGenerating = false }
            do {
                self.generated = try await self.generator.generate(req)

                await self.persistGenerated()
            } catch {
                self.generated = []
            }
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

    /// Salva in Core Data le ricette presenti in `generated` evitando duplicati per id
    private func persistGenerated() async {
        // Legge gli id già presenti
        let existingFetch: NSFetchRequest<CDRecipe> = CDRecipe.fetchRequest()
        let existing = (try? ctx.fetch(existingFetch)) ?? []
        let existingIDs = Set(existing.compactMap { $0.id })

        for r in generated where !existingIDs.contains(r.id) {
            let obj = CDRecipe(context: ctx)
            obj.apply(from: r)
        }
        do { try ctx.save() } catch { print("[RECIPES][ERR] save: \(error)") }
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
}
