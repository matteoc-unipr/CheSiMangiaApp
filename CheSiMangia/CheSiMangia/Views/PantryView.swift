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
            ZStack {
                // ====== LIST PRINCIPALE ======
                List {
                    inputSection
                    resultsSection
                    Section("Prodotti") {
                        ForEach(products) { p in
                            NavigationLink {
                                ProductDetailView(product: p)
                            } label: { ProductRow(product: p) }
                                .id(p.objectID)
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        ctx.delete(p); try? ctx.save()
                                    } label: { Label("Elimina", systemImage: "trash") }
                                }
                                .tint(.red)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button { vm.pantry.incrementQuantity(for: p) } label: {
                                        QuantityBubble(product: p)
                                    }
                                    .tint(.green)
                                }
                        }
                        .onDelete { idx in
                            idx.map { products[$0] }.forEach(ctx.delete)
                            try? ctx.save()
                        }
                    }
                }
                // ====== FAB SCAN IN BASSO ======
                .overlay(alignment: .bottom) {
                    FloatingScanButton {
                        if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                            showScanner = true
                        } else {
                            scannerUnavailable = true
                        }
                    }
                    .padding(.bottom, 28)   // sopra la TabBar
                }
            }
            .alert("Scanner non disponibile", isPresented: $scannerUnavailable) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Il tuo dispositivo non supporta DataScanner o la fotocamera non è disponibile. Usa l’inserimento manuale.")
            }
            .navigationTitle("Dispensa")
            .onChange(of: vm.lastScanError) { _, new in showError = (new != nil) }
            .alert("Errore", isPresented: $showError) {
                Button("OK", role: .cancel) { vm.lastScanError = nil }
            } message: { Text(vm.lastScanError ?? "") }
        }
        .sheet(isPresented: $showScanner) {
            ScannerView { code in
                showScanner = false
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
                        debouncedSearch(text: newValue)
                    }
                    // Invio/Cerca: SOLO ricerca (se è nome). Se è barcode, aggiunge da OFF.
                    .onSubmit { Task { await submitSearch() } }

                Button("Aggiungi") {
                    Task { await addManualProduct() }   // sempre manuale
                }
                .buttonStyle(.borderedProminent)
            }
            if isSearching {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Cerco su OpenFoodFacts…")
                        .font(.footnote).foregroundStyle(.secondary)
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
                                    .font(.headline).lineLimit(1)
                                Text(p.brands ?? "")
                                    .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Button {
                                Task {
                                    do {
                                        try vm.pantry.addOFFProduct(p)
                                        clearResultsUI()
                                    } catch {
                                        vm.lastScanError = "Impossibile aggiungere il prodotto."
                                    }
                                }
                            } label: { Image(systemName: "plus.circle.fill").imageScale(.large) }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Ricerca

    private func submitSearch() async {
        let q = manual.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { clearResultsUI(); return }

        if isBarcode(q) {
            // Per i barcode è comodo aggiungere subito
            vm.handleScanned(barcode: q)
            manual = ""
            clearResultsUI()
        } else {
            await searchOFF(query: q)
        }
    }

    private func debouncedSearch(text: String) {
        searchTask?.cancel()
        results.removeAll()

        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { isSearching = false; return }
        guard !isBarcode(q) else { isSearching = false; return }
        guard q.count >= 2 else { isSearching = false; return }

        isSearching = true
        searchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000) // 400 ms
            await searchOFF(query: q)
        }
    }

    @MainActor
    private func searchOFF(query: String) async {
        isSearching = true
        do {
            let found = try await OFFClient.shared.searchProducts(query: query)
            results = found.filter { ($0.product_name?.isEmpty == false) || ($0.brands?.isEmpty == false) }
        } catch {
            results = []
        }
        isSearching = false
    }

    private func clearResultsUI() {
        withAnimation {
            results.removeAll()
            isSearching = false
            manualFocused = false
        }
    }

    // MARK: - Azioni

    private func addManualProduct() async {
        let t = manual.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        do {
            try vm.pantry.addManualProduct(name: t, brand: nil)
            manual = ""
            clearResultsUI()
        } catch {
            vm.lastScanError = "Errore nel salvataggio del prodotto manuale."
        }
    }

    // MARK: - Helper

    private func isBarcode(_ s: String) -> Bool {
        s.range(of: #"^\d{8,14}$"#, options: .regularExpression) != nil
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
                    .font(.headline).lineLimit(1)
                HStack(spacing: 6) {
                    Text(product.brand ?? "")
                        .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    if product.isManual {
                        Text("• manuale").font(.caption).foregroundStyle(.secondary)
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
            Circle().fill(Color.white)
            Text("\(product.quantity)")
                .font(.headline).bold()
                .foregroundStyle(.blue)
        }
        .frame(width: 32, height: 32)
        .accessibilityLabel("Quantità \(product.quantity)")
    }
}

// MARK: - Floating Scan Button

private struct FloatingScanButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .padding(22)
                .background(Circle().fill(Color.orange))
                .shadow(radius: 8, y: 4)
        }
        .accessibilityLabel("Scansiona nuovo prodotto")
    }
}
