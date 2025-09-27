//
//  NovaInfoSheet.swift
//  CheSiMangia
//
//  Created by Matteo Costella on 27/09/25.
//


import SwiftUI

struct NovaInfoSheet: View {
    let barcode: String
    let level: Int?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack(spacing: 12) {
                        if let lv = level, (1...4).contains(lv) { NovaDot(level: lv) }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cos’è il NOVA").font(.title).bold()
                            if let lv = level, (1...4).contains(lv) {
                                Text("Livello del prodotto: \(lv)")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }

                    // Livelli 1–4
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Livelli NOVA").font(.headline)
                            NovaRow(level: 1, title: "Alimenti non trasformati o minimamente trasformati",
                                    examples: "frutta, verdura, riso, carne fresca, latte, yogurt bianco")
                            NovaRow(level: 2, title: "Ingredienti culinari trasformati",
                                    examples: "olio, burro, sale, zucchero")
                            NovaRow(level: 3, title: "Alimenti trasformati",
                                    examples: "pane, formaggi, conserve, prosciutto")
                            NovaRow(level: 4, title: "Alimenti ultra-processati",
                                    examples: "bibite zuccherate, snack, cereali zuccherati, piatti pronti")
                        }
                    }
                    
                    // Che cos'è NOVA
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("**NOVA** è una classificazione che raggruppa gli alimenti in base al **grado di trasformazione** industriale, **non** alla qualità nutrizionale.")
                            Text("È complementare al Nutri-Score: NOVA indica *quanto è processato* un alimento.").foregroundStyle(.secondary)
                        }.textSelection(.enabled)
                    }

                    // Come viene assegnato
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Come viene assegnato").font(.headline)
                            Text("La categoria NOVA deriva dalla **lista ingredienti** e dai **processi** impiegati (additivi, estrusi, aromi, ingredienti ricomposti, ecc.). Più un prodotto contiene ingredienti/tecniche tipiche dell’ultra-processamento, più tende verso **NOVA 4**.")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !barcode.isEmpty {
                        Link(destination: URL(string: "https://world.openfoodfacts.org/product/\(barcode)")!) {
                            Label("Apri la pagina del prodotto su OpenFoodFacts", systemImage: "link")
                        }
                        .padding(.top, 4)
                    }
                }
                .padding()
            }
            .navigationTitle("NOVA")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct NovaRow: View {
    let level: Int
    let title: String
    let examples: String

    var color: Color {
        switch level {
        case 1: return Color(red: 0.0, green: 1.0, blue: 0.0)   // verde fluo
        case 2: return Color(red: 0.09, green: 0.53, blue: 0.25)
        case 3: return Color(red: 0.98, green: 0.85, blue: 0.25)
        case 4: return Color(red: 0.86, green: 0.23, blue: 0.19) // rosso
        default: return .gray
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(level)").font(.caption).bold()
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(color, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).bold()
                Text("Esempi: \(examples)")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("NOVA \(level): \(title)")
    }
}
