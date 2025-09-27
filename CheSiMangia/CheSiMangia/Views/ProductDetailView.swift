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

    @State private var showNutriSheet = false
    @State private var showNovaSheet = false
    @State private var isEditingName = false
    @State private var tempName: String = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {

                // --- TITOLO PRODOTTO (al posto del "Prodotto") ---
                HStack {
                    if isEditingName {
                        TextField("Nome prodotto", text: $tempName, onCommit: saveName)
                            .font(.title)
                            .bold()
                            .focused($nameFocused)

                        Spacer()

                        Button {
                            saveName()
                        } label: {
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
                if let brand = product.brand, !brand.isEmpty {
                    Text(brand).foregroundStyle(.secondary)
                }
                
                
                // Badge Nutri-Score e Nova
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
                    if let nova = product.nova?.intValue, (1...4).contains(nova) {
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
                .padding(.bottom, 16)


                if product.nutrimentsJSON != nil {
                    NutritionFactsView(nutrimentsData: product.nutrimentsJSON)
                }

                if let allergens = product.allergens, !allergens.isEmpty {
                    Text("Allergeni").font(.headline)
                    WrapChips(items: allergens.split(separator: ",").map(String.init))
                }

                Text("Immagine").font(.headline)
                AsyncImage(url: URL(string: product.imageURL ?? "")) { $0.resizable().scaledToFit() } placeholder: {
                    Rectangle().fill(.gray.opacity(0.2)).frame(height: 160)
                }

                Button {
                    vm.generateRecipes(using: product)
                } label: {
                    Label("Genera ricette con questo prodotto", systemImage: "wand.and.stars")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .sheet(isPresented: $showNutriSheet) {
            NutriScoreInfoSheet(barcode: product.barcode ?? "", grade: product.nutriscore?.uppercased())
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showNovaSheet) {
            NovaInfoSheet(barcode: product.barcode ?? "", level: product.nova?.intValue)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func saveName() {
        let trimmed = tempName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            isEditingName = false
            return
        }
        product.name = trimmed
        try? ctx.save()
        isEditingName = false
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

// MARK: - Nutrition Facts (larghezza piena)

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

    // Helpers

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
        if let kj = value(dict, "energy-kj\(suffix)") ?? value(dict, "energy\(suffix)") {
            return kj / 4.184
        }
        return nil
    }

    private func format(_ x: Double?, unit: String) -> String {
        guard let x else { return "–" }
        if unit == "mg" || unit == "kcal" { return "\(Int(round(x))) \(unit)" }
        let v = x < 10 ? String(format: "%.1f", x) : String(format: "%.0f", x)
        return "\(v) \(unit)"
    }
}
