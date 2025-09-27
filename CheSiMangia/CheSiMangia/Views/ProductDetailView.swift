//
//  ProductDetailView.swift
//  CheSiMangia
//
//  Created by Matteo Costella on 25/09/25.
//

import SwiftUI
import CoreData

struct ProductDetailView: View {
    @ObservedObject var product: CDProduct
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    @State private var showNutriSheet = false
    @State private var showNovaSheet = false
    @State private var isEditingName = false
    @State private var tempName: String = ""
    @FocusState private var nameFocused: Bool
    @State private var showDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {

                // --- TITOLO PRODOTTO ---
                HStack {
                    if isEditingName {
                        TextField("Nome prodotto", text: $tempName, onCommit: saveName)
                            .font(.title)
                            .bold()
                            .focused($nameFocused)

                        Spacer()

                        Button { saveName() } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                        }
                    } else {
                        Text(product.name ?? "Senza nome")
                            .font(.title)
                            .bold()

                        Spacer()

                        Button {
                            tempName = product.name ?? ""
                            isEditingName = true
                            nameFocused = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2)
                        }
                    }
                }

                // Brand
                if let brand = product.brand, !brand.isEmpty {
                    Text(brand).foregroundStyle(.secondary)
                }

                // --- CONTATORE QUANTITÀ ---
                HStack {
                    Spacer()
                    QuantityCounter(
                        value: quantity,
                        onIncrement: { setQuantity(quantity + 1) },
                        onDecrement: {
                            if quantity > 1 { setQuantity(quantity - 1) }
                            else { showDeleteAlert = true }
                        }
                    )
                    Spacer()
                }
                .padding(.vertical, 20) // più distacco sopra/sotto

                // Badge Nutri-Score & NOVA
                HStack(spacing: 12) {
                    if let ns = product.nutriscore?.uppercased() {
                        HStack(spacing: 4) {
                            Text("Nutri-Score:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button { showNutriSheet = true } label: {
                                NutriScoreDot(grade: ns)
                            }.buttonStyle(.plain)
                        }
                    }
                    if let nova = (product.value(forKey: "nova") as? NSNumber)?.intValue, (1...4).contains(nova) {
                        HStack(spacing: 4) {
                            Text("NOVA:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button { showNovaSheet = true } label: {
                                NovaDot(level: nova)
                            }.buttonStyle(.plain)
                        }
                    }
                }
                
                // Valori nutrizionali
                if product.nutrimentsJSON != nil {
                    NutritionFactsView(nutrimentsData: product.nutrimentsJSON)
                }

                // Allergeni
                if let allergens = product.allergens, !allergens.isEmpty {
                    Text("Allergeni").font(.headline)
                    WrapChips(items: allergens.split(separator: ",").map(String.init))
                }

                // Immagine
                Text("Immagine").font(.headline)
                AsyncImage(url: URL(string: product.imageURL ?? "")) {
                    $0.resizable().scaledToFit()
                } placeholder: {
                    Rectangle().fill(.gray.opacity(0.2)).frame(height: 160)
                }

                // Genera ricette
                Button {
                    vm.generateRecipes(using: product)
                } label: {
                    Label("Genera ricette con questo prodotto", systemImage: "wand.and.stars")
                }
                .buttonStyle(.borderedProminent)

                // --- ELIMINA PRODOTTO (in fondo) ---
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label("Elimina prodotto dalla dispensa", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .padding(.top, 24)
            }
            .padding()
        }
        // Sheet Nutri-Score
        .sheet(isPresented: $showNutriSheet) {
            NutriScoreInfoSheet(barcode: product.barcode ?? "", grade: product.nutriscore?.uppercased())
                .presentationDetents([.medium, .large], selection: .constant(.medium))
                .presentationDragIndicator(.visible)
        }
        // Sheet NOVA
        .sheet(isPresented: $showNovaSheet) {
            NovaInfoSheet(barcode: product.barcode ?? "", level: (product.value(forKey: "nova") as? NSNumber)?.intValue)
                .presentationDetents([.medium, .large], selection: .constant(.medium))
                .presentationDragIndicator(.visible)
        }
        // Conferma eliminazione (bottone rosso)
        .alert("Eliminare questo prodotto dalla dispensa?", isPresented: $showDeleteAlert) {
            Button("Annulla", role: .cancel) {}
            Button("Elimina", role: .destructive) { deleteProduct() }
        } message: {
            Text("“\(product.name ?? "Prodotto")” verrà rimosso definitivamente dalla dispensa.")
        }
    }

    // MARK: - Helpers quantità (compatibili con Int16 opzionale/non opzionale)
    private var quantity: Int {
        (product.value(forKey: "quantity") as? NSNumber)?.intValue ?? 1
    }

    private func setQuantity(_ newValue: Int) {
        product.setValue(Int16(max(0, newValue)), forKey: "quantity")
        try? ctx.save()
    }

    // MARK: - Actions

    private func saveName() {
        let trimmed = tempName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { isEditingName = false; return }
        product.name = trimmed
        try? ctx.save()
        isEditingName = false
    }

    private func deleteProduct() {
        ctx.delete(product)
        try? ctx.save()
        dismiss()
    }
}

// MARK: - Contatore UI

private struct QuantityCounter: View {
    let value: Int
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onDecrement) {
                Image(systemName: "minus")
                    .font(.body)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.bordered)
            .clipShape(Circle())

            Text("\(value)")
                .font(.title3).bold()
                .monospacedDigit()
                .frame(minWidth: 36)

            Button(action: onIncrement) {
                Image(systemName: "plus")
                    .font(.body)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderedProminent)
            .clipShape(Circle())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Quantità")
        .accessibilityValue("\(value)")
    }
}


// MARK: - WrapChips

struct WrapChips: View {
    let items: [String]
    var body: some View {
        FlowLayout(items: items) {
            Text($0.replacingOccurrences(of: "en:", with: ""))
                .padding(6)
                .background(.ultraThinMaterial, in: Capsule())
        }
    }
}

// MARK: - Nutrition Facts (come già in uso)

private struct NutritionFactsView: View {
    let nutrimentsData: Data?

    var body: some View {
        let dict = decodeNutriments(nutrimentsData)
        if dict.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 8) {
                Label("Valori nutrizionali", systemImage: "scalemass")
                    .font(.headline)

                VStack(spacing: 0) {
                    headerRow()
                    Divider()
                    groupRow("Energia", key: "energy-kcal", unit: "kcal", dict: dict, isEnergy: true)
                    Divider()
                    groupRow("Grassi", key: "fat", unit: "g", dict: dict)
                    groupRow("  Saturi", key: "saturated-fat", unit: "g", dict: dict)
                    groupRow("Carboidrati", key: "carbohydrates", unit: "g", dict: dict)
                    groupRow("  Zuccheri", key: "sugars", unit: "g", dict: dict)
                    groupRow("Fibre", key: "fiber", unit: "g", dict: dict)
                    groupRow("Proteine", key: "proteins", unit: "g", dict: dict)
                    groupRow("Sale", key: "salt", unit: "g", dict: dict)
                    groupRow("Calcio", key: "calcium", unit: "mg", dict: dict)
                }
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator, lineWidth: 0.5))
            }
            .padding(.top, 8)
        }
    }

    private func headerRow() -> some View {
        HStack {
            Text("Nutriente").frame(maxWidth: .infinity, alignment: .leading)
            Text("per 100 g").frame(maxWidth: .infinity, alignment: .trailing)
            Text("per porz.").frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.subheadline.bold())
        .padding(.horizontal, 12).padding(.vertical, 10)
    }

    private func groupRow(_ title: String, key: String, unit: String, dict: [String: JSONValue], isEnergy: Bool = false) -> some View {
        let v100 = isEnergy ? energyKcal(dict, suffix: "_100g") : value(dict, "\(key)_100g")
        let vServ = isEnergy ? energyKcal(dict, suffix: "_serving") : value(dict, "\(key)_serving")

        return HStack {
            Text(title).frame(maxWidth: .infinity, alignment: .leading)
            Text(format(v100, unit: unit)).frame(maxWidth: .infinity, alignment: .trailing).monospacedDigit()
            Text(format(vServ, unit: unit)).frame(maxWidth: .infinity, alignment: .trailing).monospacedDigit()
        }
        .font(.callout)
        .padding(.horizontal, 12).padding(.vertical, 10)
    }

    private func decodeNutriments(_ data: Data?) -> [String: JSONValue] {
        guard let data else { return [:] }
        return (try? JSONDecoder().decode([String: JSONValue].self, from: data)) ?? [:]
    }
    private func value(_ dict: [String: JSONValue], _ key: String) -> Double? {
        guard let v = dict[key] else { return nil }
        switch v {
        case .number(let d): return d
        case .string(let s): return Double(s.replacingOccurrences(of: ",", with: "."))
        default: return nil
        }
    }
    private func energyKcal(_ dict: [String: JSONValue], suffix: String) -> Double? {
        if let kcal = value(dict, "energy-kcal\(suffix)") { return kcal }
        if let kj = value(dict, "energy-kj\(suffix)") ?? value(dict, "energy\(suffix)") { return kj / 4.184 }
        return nil
    }
    private func format(_ x: Double?, unit: String) -> String {
        guard let x else { return "–" }
        if unit == "mg" || unit == "kcal" { return "\(Int(round(x))) \(unit)" }
        let v = x < 10 ? String(format: "%.1f", x) : String(format: "%.0f", x)
        return "\(v) \(unit)"
    }
}
