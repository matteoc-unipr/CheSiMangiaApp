//
//  ProductDetailView.swift
//  CheSiMangia
//
//  Created by Matteo Costella on 25/09/25.
//


import SwiftUI

struct ProductDetailView: View {
    let product: CDProduct
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                AsyncImage(url: URL(string: product.imageURL ?? "")) { $0.resizable().scaledToFit() } placeholder: { Rectangle().fill(.gray.opacity(0.2)).frame(height: 160) }
                Text(product.name ?? "").font(.title2).bold()
                if let brand = product.brand, !brand.isEmpty { Text(brand).foregroundStyle(.secondary) }
                HStack(spacing: 8) {
                    if let ns = product.nutriscore?.uppercased() { Badge(text: "Nutri‑Score \(ns)") }
                    if product.nova > 0 { Badge(text: "NOVA \(product.nova)") }
                }
                if let allergens = product.allergens, !allergens.isEmpty {
                    Text("Allergeni").font(.headline)
                    WrapChips(items: allergens.split(separator: ",").map(String.init))
                }
                Button { vm.generateRecipes(using: product) } label: { Label("Genera ricette con questo prodotto", systemImage: "wand.and.stars") }
                    .buttonStyle(.borderedProminent)
            }.padding()
        }.navigationTitle("Prodotto")
    }
}

struct WrapChips: View { let items: [String]; var body: some View { FlowLayout(items: items) { Text($0.replacingOccurrences(of: "en:", with: "")).padding(6).background(.ultraThinMaterial, in: Capsule()) } } }
