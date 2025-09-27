//
//  NutriScoreInfoSheet.swift
//  CheSiMangia
//
//  Created by Matteo Costella on 27/09/25.
//


import SwiftUI

struct NutriScoreInfoSheet: View {
    let barcode: String
    let grade: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack(spacing: 12) {
                        if let g = grade { NutriScoreDot(grade: g) }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cos’è il Nutri-Score")
                                .font(.title).bold()
                            if let g = grade {
                                Text("Valutazione del prodotto: \(g)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    
                    // Mappa lettera → significato & colori
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Significato delle lettere").font(.headline)
                            NutriRow(letter: "A", text: "Qualità nutrizionale molto buona", color: Color(red: 0.0, green: 1.0, blue: 0.0))
                            NutriRow(letter: "B", text: "Buona qualità nutrizionale", color: Color(red: 0.09, green: 0.53, blue: 0.25))
                            NutriRow(letter: "C", text: "Qualità nutrizionale media", color: Color(red: 0.98, green: 0.85, blue: 0.25))
                            NutriRow(letter: "D", text: "Qualità nutrizionale bassa", color: Color(red: 0.99, green: 0.61, blue: 0.20))
                            NutriRow(letter: "E", text: "Qualità nutrizionale molto bassa", color: Color(red: 0.86, green: 0.23, blue: 0.19))
                            Text("La lettera **non** tiene conto di porzioni, ingredienti ultra-processati, allergeni o impatto ambientale.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }

                    // Che cos'è
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Il **Nutri-Score** è un sistema di etichettatura nutrizionale che riassume la qualità nutrizionale complessiva di un alimento con una lettera **A–E** e un colore associato.")
                            Text("Non sostituisce la lettura dell’etichetta completa, ma aiuta a **confrontare rapidamente** prodotti della **stessa categoria**.")
                                .foregroundStyle(.secondary)
                        }
                        .textSelection(.enabled)
                    }
                    
                    // Come si calcola
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Come viene calcolato").font(.headline)
                            Text("Si parte da un punteggio che combina:")
                            VStack(alignment: .leading, spacing: 6) {
                                Label("**Punti negativi** (0–55): energia (kJ), zuccheri, grassi saturi, sodio", systemImage: "minus.circle")
                                Label("**Punti positivi** (0–17): proteine, fibre, quota di frutta/verdura/legumi/olio di colza-noci-oliva", systemImage: "plus.circle")
                            }
                            Text("Il **punteggio finale** è dato dai punti negativi **meno** i punti positivi; dalla somma si ricava la **lettera** A–E.")
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Link a OFF
                    if !barcode.isEmpty {
                        Link(destination: URL(string: "https://world.openfoodfacts.org/product/\(barcode)")!) {
                            Label("Apri la pagina del prodotto su OpenFoodFacts", systemImage: "link")
                        }
                        .padding(.top, 4)
                    }
                }
                .padding()
            }
            .navigationTitle("Nutri-Score")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct NutriRow: View {
    let letter: String
    let text: String
    let color: Color
    var body: some View {
        HStack(spacing: 10) {
            Text(letter).font(.caption).bold()
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(color, in: Circle())
            Text(text)
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Nutri-Score \(letter): \(text)")
    }
}
