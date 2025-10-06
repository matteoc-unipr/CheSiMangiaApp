//
//  GenerateView.swift
//  CheSiMangia
//
//  Created by Matteo Costella on 25/09/25.
//

import SwiftUI
import CoreData

struct GenerateView: View {
    @EnvironmentObject var vm: AppViewModel

    // Abilita se non sta generando e c'è almeno 1 prodotto in dispensa
    private var canGenerate: Bool {
        !vm.isGenerating && hasPantryItems()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if vm.isGenerating {
                    ProgressView("Creo ricette...")
                        .padding(.top, 8)
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
                }
                .listStyle(.plain)
                .overlay {
                    if vm.generated.isEmpty {
                        VStack(spacing: 12) {
                            ContentUnavailableView(
                                "Nessuna ricetta",
                                systemImage: "fork.knife",
                                description: Text("Scansiona prodotti o premi ‘Genera ricette’ per usare la dispensa.")
                            )
                            Button {
                                let h = UIImpactFeedbackGenerator(style: .soft)
                                h.impactOccurred()
                                vm.generateRecipes(using: nil) // usa l'intera dispensa
                            } label: {
                                Label("Genera ricette", systemImage: "wand.and.stars")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!canGenerate)
                        }
                        .padding(.top, 16)
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
                        let h = UIImpactFeedbackGenerator(style: .soft)
                        h.impactOccurred()
                        vm.generateRecipes(using: nil)
                    } label: {
                        Label("Genera ricette", systemImage: "wand.and.stars")
                    }
                    .disabled(!canGenerate)
                }
            }
            .onAppear {
                vm.pantry.refresh()
            }
        }
    }

    // MARK: - Helpers

    /// Conta direttamente gli item in Core Data per evitare problemi di timing dello @Published.
    private func hasPantryItems() -> Bool {
        let ctx = PersistenceController.shared.container.viewContext
        let req: NSFetchRequest<CDProduct> = CDProduct.fetchRequest()
        req.fetchLimit = 1
        let count = (try? ctx.count(for: req)) ?? 0
        return count > 0
    }
}

// MARK: - Dettaglio ricetta (incluso qui per risolvere l'errore)

struct RecipeDetailView: View {
    let recipe: Recipe

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(recipe.title)
                    .font(.title2)
                    .bold()

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
            }
            .padding()
        }
        .navigationTitle("Dettagli")
        .navigationBarTitleDisplayMode(.inline)
    }
}
