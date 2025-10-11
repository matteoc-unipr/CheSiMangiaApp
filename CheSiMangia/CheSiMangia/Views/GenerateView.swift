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
                if vm.isGenerating {
                    ProgressView("Creo ricette...")
                }
                List(vm.generated) { r in
                    NavigationLink(value: r.id) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(r.title).font(.headline)
                                Spacer()
                                Badge(text: "Eco \(EcoScore.score(for: r.ingredients))")
                            }
                            Text("\(r.minutes) min • \(r.kcalPerServing ?? 0) kcal/porz")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            vm.deleteRecipe(r)
                        } label: {
                            Label("Elimina", systemImage: "trash")
                        }
                    }
                    .tint(.red)
                }
                .overlay {
                    if vm.generated.isEmpty && !vm.isGenerating {
                        ContentUnavailableView(
                            "Nessuna ricetta",
                            systemImage: "fork.knife",
                            description: Text("Scansiona un prodotto o premi ‘Genera’ per usare la dispensa.")
                        )
                    }
                }
            }
            .padding(.top, 1)
            .navigationTitle("Ricette")
            .navigationDestination(for: UUID.self) { id in
                if let r = vm.generated.first(where: { $0.id == id }) {
                    RecipeDetailView(recipe: r)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // genera partendo dall’intera dispensa (nessun prodotto focalizzato)
                        vm.generateRecipes(using: nil)
                    } label: {
                        Label("Genera", systemImage: "sparkles")
                    }
                    .disabled(vm.isGenerating)
                }
            }
        }
    }
}


struct RecipeDetailView: View {
    let recipe: Recipe
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(recipe.title).font(.title2).bold()

                Text("Ingredienti").font(.headline)
                ForEach(recipe.ingredients, id: \.self) { Text("• \($0)") }

                Text("Passi").font(.headline)
                ForEach(recipe.steps.indices, id: \.self) { i in
                    Text("\(i+1). \(recipe.steps[i])")
                }

                if !recipe.variants.isEmpty {
                    Text("Varianti").font(.headline)
                    ForEach(recipe.variants, id: \.self) { Text("– \($0)") }
                }

                // ---- Bottone elimina in basso ----
                Button(role: .destructive) {
                    vm.deleteRecipe(recipe)
                } label: {
                    Label("Elimina ricetta", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .padding(.top, 12)
            }
            .padding()
        }
    }
}
