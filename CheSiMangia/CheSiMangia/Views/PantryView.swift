//
//  PantryView.swift
//  CheSiMangia
//
//  Created by Matteo Costella on 25/09/25.
//

import SwiftUI
import VisionKit
import CoreData

struct PantryView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.managedObjectContext) private var ctx

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDProduct.createdAt, ascending: false)],
        animation: .default
    )
    private var products: FetchedResults<CDProduct>

    @State private var showScanner = false
    @State private var manual = ""
    @State private var scannerUnavailable = false
    @State private var showError = false

    // Ricerca OFF
    @State private var results: [OFFProduct.Product] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var manualFocused: Bool
    
    var body: some View {
        NavigationStack {
            List {
                inputSection
                resultsSection          // risultati ricerca OFF
                Section("Prodotti") {
                    ForEach(products) { p in
                        NavigationLink {
                            ProductDetailView(product: p)
                        } label: {
                            ProductRow(product: p)
                        }.id(p.objectID)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                ctx.delete(p); try? ctx.save()
                            } label: {
                                Label("Elimina", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                vm.pantry.incrementQuantity(for: p)
                            } label: {
                                QuantityBubble(product: p)
                            }
                            .tint(.blue)
                        }

                    }
                    .onDelete { idx in
                        idx.map { products[$0] }.forEach(ctx.delete)
                        try? ctx.save()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                            showScanner = true
                        } else {
                            scannerUnavailable = true
                        }
                    } label: {
                        Image(systemName: "barcode.viewfinder")
                    }
                }
            }
            .alert("Scanner non disponibile", isPresented: $scannerUnavailable) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Il tuo dispositivo non supporta DataScanner o la fotocamera non è disponibile. Usa l’inserimento manuale.")
            }
            .navigationTitle("Dispensa")
            .onChange(of: vm.lastScanError) { _, new in
                showError = (new != nil)
            }
            .alert("Errore", isPresented: $showError) {
                Button("OK", role: .cancel) { vm.lastScanError = nil }
            } message: {
                Text(vm.lastScanError ?? "")
            }
        }
        .sheet(isPresented: $showScanner) {
            ScannerView { code in
                showScanner = false
                // tieni solo le cifre (alcuni symbology possono includere spazi o char strani)
                let clean = code.replacingOccurrences(of: #"[^0-9]"#, with: "", options: .regularExpression)
                vm.handleScanned(barcode: clean)
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Sezioni

    private var inputSection: some View {
        Section {
            HStack {
                TextField("Inserisci barcode o nome", text: $manual)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .keyboardType(.asciiCapable)
                    .focused($manualFocused)
                    .onChange(of: manual) { _, newValue in
                        handleSearchChange(newValue)
                    }
                    .onSubmit { Task { await addManual() } }

                Button("Aggiungi") {
                    Task { await addManual() }
                }
                .buttonStyle(.borderedProminent)
            }
            if isSearching {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Cerco su OpenFoodFacts…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var resultsSection: some View {
        Group {
            if !results.isEmpty {
                Section("Risultati OFF") {
                    ForEach(results.prefix(10), id: \.code) { p in
                        HStack {
                            let url = URL(string: p.image_url ?? "")
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty: Color.gray.opacity(0.2)
                                case .success(let image): image.resizable().scaledToFill()
                                case .failure: Color.gray.opacity(0.2)
                                @unknown default: Color.gray.opacity(0.2)
                                }
                            }
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.product_name ?? "Senza nome")
                                    .font(.headline)
                                    .lineLimit(1)
                                Text(p.brands ?? "")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Button {
                                Task {
                                    do {
                                        try vm.pantry.addOFFProduct(p)
                                        searchTask?.cancel()
                                        withAnimation {
                                            results.removeAll()   // chiude la sezione "Risultati OFF"
                                            isSearching = false
                                            searchTask?.cancel()
                                        }
                                        manual = ""               // svuota il campo di ricerca
                                        manualFocused = false     // chiude la tastiera
                                    } catch {
                                        vm.lastScanError = "Impossibile aggiungere il prodotto."
                                    }
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill").imageScale(.large)
                            }
                            .buttonStyle(.plain)

                        }
                    }
                }
            }
        }
    }

    // MARK: - Azioni

    private func addManual() async {
        let t = manual.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        manualFocused = false                        
        defer { manual = "" }

        if isBarcode(t) {
            vm.handleScanned(barcode: t) // barcode numerico → OFF
            return
        }

        // se ho già risultati, prendo il primo; altrimenti cerco ora
        if let first = results.first {
            do { try vm.pantry.addOFFProduct(first) }
            catch { vm.lastScanError = "Errore nel salvataggio del prodotto" }
            results.removeAll()
        } else {
            do {
                let found = try await OFFClient.shared.searchProducts(query: t)
                if let first = found.first {
                    try vm.pantry.addOFFProduct(first)
                } else {
                    // fallback: crea un prodotto manuale col nome
                    try vm.pantry.addManualProduct(name: t, brand: nil)
                }
            } catch {
                vm.lastScanError = "Errore nella ricerca su OFF."
            }
        }
    }

    // MARK: - Ricerca helper

    /// Vero se il testo è un barcode (solo cifre 8–14)
    private func isBarcode(_ s: String) -> Bool {
        s.range(of: #"^\d{8,14}$"#, options: .regularExpression) != nil
    }

    private func handleSearchChange(_ text: String) {
        // cancella eventuale task precedente (debounce)
        searchTask?.cancel()
        results.removeAll()

        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { isSearching = false; return }

        // se sembra barcode, non cercare per nome
        guard !isBarcode(q) else { isSearching = false; return }

        // evita traffico eccessivo: cerca solo con ≥ 2 caratteri (puoi mettere 3)
        guard q.count >= 2 else { isSearching = false; return }

        isSearching = true
        searchTask = Task { @MainActor in
            // debounce 400 ms
            try? await Task.sleep(nanoseconds: 400_000_000)
            do {
                let found = try await OFFClient.shared.searchProducts(query: q)
                // tieni solo quelli con nome/brand
                self.results = found.filter { ($0.product_name?.isEmpty == false) || ($0.brands?.isEmpty == false) }
                self.isSearching = false
            } catch {
                // niente alert su typing: semplicemente azzera risultati
                self.results = []
                self.isSearching = false
                // (facoltativo) print per debug:
                print("[OFF][SEARCH][ERR] \(error)")
            }
        }
    }
}

// MARK: - UI Support

private struct ProductRow: View {
    let product: CDProduct
    var body: some View {
        HStack {
            let url = URL(string: product.imageURL ?? "")
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty: Color.gray.opacity(0.2)
                case .success(let image): image.resizable().scaledToFill()
                case .failure: Color.gray.opacity(0.2)
                @unknown default: Color.gray.opacity(0.2)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(product.name ?? "Senza nome")
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(product.brand ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if product.isManual {
                        Text("• manuale")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            if let ns = product.nutriscore?.uppercased() {
                NutriScoreDot(grade: ns)
            }
        }
    }
}

struct Badge: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())
    }
}

private struct QuantityBubble: View {
    @ObservedObject var product: CDProduct

    var body: some View {
        ZStack {
            Color.clear.overlay(
                Text("\(product.quantity)")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.blue)
                    .monospacedDigit()
            )
        }
        .frame(width: 32, height: 32)
        .accessibilityLabel("Quantità \(product.quantity)")
    }
}

