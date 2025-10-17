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
    @Published var prefs: CDPrefs?
    @Published var products: [CDProduct] = []

    init(ctx: NSManagedObjectContext) {
        self.ctx = ctx
        loadPrefs()
    }

    private func loadPrefs() {
        let r: NSFetchRequest<CDPrefs> = CDPrefs.fetchRequest()
        if let p = try? ctx.fetch(r).first {
            prefs = p
        } else {
            let p = CDPrefs(context: ctx)
            p.vegetarian = false
            p.lactoseFree = false
            p.peanutFree = false
            p.maxMinutes = 30
            p.skill = "beginner"
            p.servings = 2
            try? ctx.save()
            prefs = p
        }
    }
    
    func refresh() {
        let req: NSFetchRequest<CDProduct> = CDProduct.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        products = (try? ctx.fetch(req)) ?? []
        
        // prefs come prima…
        let r: NSFetchRequest<CDPrefs> = CDPrefs.fetchRequest()
        if let p = try? ctx.fetch(r).first {
            prefs = p
        } else {
            let p = CDPrefs(context: ctx)
            p.vegetarian = false
            p.lactoseFree = false
            p.peanutFree = false
            p.maxMinutes = 30
            p.skill = "beginner"
            try? ctx.save()
            prefs = p
        }
    }

    /// Aggiunge un prodotto partendo dai dati di OFF (con validazioni safe)
    func addOFFProduct(_ p: OFFProduct.Product) throws {
        let obj = CDProduct(context: ctx)

        obj.barcode = p.code ?? "manual:\(UUID().uuidString)"
        obj.isManual = (p.code == nil)

        // name/brand/image
        let name = (p.product_name?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
        obj.name = name ?? "Senza nome"
        obj.brand = (p.brands?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
        obj.imageURL = (p.image_url?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }

        // Nutri-Score (solo A..E altrimenti nil)
        if let raw = p.nutriscore_grade?.uppercased(), ["A","B","C","D","E"].contains(raw) {
            obj.nutriscore = raw
        } else {
            obj.nutriscore = nil
        }

        // NOVA (solo 1..4; se 0 o altro -> nil per rispettare la validazione del modello)
        if let g = p.nova_group, (1...4).contains(g) {
            obj.nova = NSNumber(value: g)
        } else {
            obj.nova = nil
        }

        // Allergeni
        obj.allergens = (p.allergens?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }

        // Nutriments: JSON “leniente”
        if let n = p.nutriments {
            obj.nutrimentsJSON = try JSONEncoder().encode(n)   // usa il tuo JSONValue
        }
        
        if let (val, unit) = extractPerUnit(from: p) {
            obj.perUnitValue = val
            obj.perUnitUnit = unit.rawValue   // "g", "kg", "ml", "l"
        } else {
            obj.perUnitValue = 0
            obj.perUnitUnit = nil
        }

        obj.createdAt = .now
        try ctx.save()
    }


    /// Aggiunge un prodotto manuale
    func addManualProduct(name: String, brand: String? = nil) throws {
        let obj = CDProduct(context: ctx)
        obj.barcode = "manual:\(UUID().uuidString)"
        obj.isManual = true
        obj.name = name
        obj.brand = brand
        obj.createdAt = .now
        try ctx.save()
    }

    func addManualProductFromBarcode(_ code: String) throws {
        if let _ = try fetchProduct(byBarcode: code) { return }
        let obj = CDProduct(context: ctx)
        obj.barcode = code
        obj.isManual = true
        obj.name = "Prodotto (\(code))"
        obj.createdAt = .now
        try ctx.save()
    }

    private func fetchProduct(byBarcode code: String) throws -> CDProduct? {
        let req: NSFetchRequest<CDProduct> = CDProduct.fetchRequest()
        req.predicate = NSPredicate(format: "barcode == %@", code)
        req.fetchLimit = 1
        return try ctx.fetch(req).first
    }

    func delete(_ product: CDProduct) {
        ctx.delete(product)
        try? ctx.save()
    }
    
    func incrementQuantity(for product: CDProduct) {
        product.quantity += 1
        try? ctx.save()
        refresh()
    }
}
