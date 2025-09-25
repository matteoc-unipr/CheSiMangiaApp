//
//  GenerateView.swift
//  CheSiMangia
//
//  Created by Matteo Costella on 25/09/25.
//


import SwiftUI

struct GenerateView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if vm.isGenerating { ProgressView("Creo ricette...") }
                List(vm.generated) { r in
                    NavigationLink(value: r.id) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack { Text(r.title).font(.headline); Spacer(); Badge(text: "Eco \(EcoScore.score(for: r.ingredients))") }
                            Text("\(r.minutes) min • \(r.kcalPerServing ?? 0) kcal/porz").foregroundStyle(.secondary)
                        }
                    }
                }.overlay { if vm.generated.isEmpty { ContentUnavailableView("Nessuna ricetta", systemImage: "fork.knife", description: Text("Scansiona un prodotto o apri un prodotto e premi ‘Genera ricette’.")) } }
            }.padding(.top, 1)
            .navigationTitle("Ricette")
            .navigationDestination(for: UUID.self) { id in if let r = vm.generated.first(where: { $0.id == id }) { RecipeDetailView(recipe: r) } }
        }
    }
}

struct RecipeDetailView: View { let recipe: Recipe; var body: some View { ScrollView { VStack(alignment: .leading, spacing: 12) { Text(recipe.title).font(.title2).bold(); Text("Ingredienti").font(.headline); ForEach(recipe.ingredients, id: \.self, content: { Text("• \($0)") }); Text("Passi").font(.headline); ForEach(recipe.steps.indices, id: \.self) { i in Text("\(i+1). \(recipe.steps[i])") }; if !recipe.variants.isEmpty { Text("Varianti").font(.headline); ForEach(recipe.variants, id: \.self) { Text("– \($0)") } } }.padding() } } }
