//
//  PantryStore.swift
//  CheSiMangia
//
//  Created by Matteo Costella on 25/09/25.
//


import CoreData

@MainActor
final class PantryStore: ObservableObject {
    static let shared = PantryStore(ctx: PersistenceController.shared.container.viewContext)
    private let ctx: NSManagedObjectContext
    @Published var products: [CDProduct] = []
    @Published var prefs: CDPrefs?

    init(ctx: NSManagedObjectContext) { self.ctx = ctx; refresh() }

    func refresh() {
        let req: NSFetchRequest<CDProduct> = CDProduct.fetchRequest(); req.sortDescriptors = [.init(key: "createdAt", ascending: false)]
        products = (try? ctx.fetch(req)) ?? []
        let r2: NSFetchRequest<CDPrefs> = CDPrefs.fetchRequest()
        prefs = (try? ctx.fetch(r2))?.first ?? {
            let p = CDPrefs(context: ctx); p.vegetarian=false; p.lactoseFree=false; p.peanutFree=false; p.maxMinutes=30; p.skill="beginner"; try? ctx.save(); return p
        }()
    }

    /// Aggiunge un prodotto partendo dai dati di OFF
    func addOFFProduct(_ p: OFFProduct.Product) throws {
        let obj = CDProduct(context: ctx)
        obj.barcode = p.code ?? "manual:\(UUID().uuidString)" // fallback se manca
        obj.isManual = (p.code == nil)
        obj.name = p.product_name ?? "Senza nome"
        obj.brand = p.brands
        obj.imageURL = p.image_url
        obj.nutriscore = p.nutriscore_grade
        if let g = p.nova_group { obj.nova = Int16(g) }
        obj.allergens = p.allergens
        if let n = p.nutriments { obj.nutrimentsJSON = try JSONSerialization.data(withJSONObject: n) }
        obj.createdAt = .now
        try ctx.save(); refresh()
    }

    /// Aggiunge un prodotto inserito manualmente (soluzione A: barcode surrogato manual:UUID)
    func addManualProduct(name: String, brand: String? = nil) throws {
        let obj = CDProduct(context: ctx)
        obj.barcode = "manual:\(UUID().uuidString)" // obbligatorio e unico
        obj.isManual = true
        obj.name = name
        obj.brand = brand
        obj.createdAt = .now
        try ctx.save(); refresh()
    }

    func delete(_ product: CDProduct) { ctx.delete(product); try? ctx.save(); refresh() }
}
