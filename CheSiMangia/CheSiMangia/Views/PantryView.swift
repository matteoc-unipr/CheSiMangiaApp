//
//  PantryView.swift
//  CheSiMangia
//
//  Created by Matteo Costella on 25/09/25.
//

import SwiftUI
import VisionKit

struct PantryView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var showScanner = false
    @State private var manual = ""
    @State private var scannerUnavailable = false

    var body: some View {
        NavigationStack {
            List {
                inputSection
                productsSection
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
        }
        .sheet(isPresented: $showScanner) {
            ScannerView { code in
                showScanner = false
                vm.handleScanned(barcode: code)
            }
            .ignoresSafeArea()
        }
    }

    private var inputSection: some View {
        Section {
            HStack {
                TextField("Inserisci barcode o nome", text: $manual)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .keyboardType(.asciiCapable)
                    .onSubmit { Task { await addManual() } }
                Button("Aggiungi") {
                    Task { await addManual() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var productsSection: some View {
        Section("Prodotti") {
            ForEach(vm.pantry.products, id: \.objectID) { p in
                NavigationLink {
                    ProductDetailView(product: p)
                } label: {
                    ProductRow(product: p)
                }
            }
            .onDelete { idx in
                let items = idx.map { vm.pantry.products[$0] }
                items.forEach(vm.pantry.delete)
            }
        }
    }

    func addManual() async {
        let t = manual.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        if t.range(of: #"^\d{8,14}$"#, options: .regularExpression) != nil {
            vm.handleScanned(barcode: t) // barcode numerico → OFF
        } else {
            do {
                try vm.pantry.addManualProduct(name: t, brand: nil)
            } catch {
                vm.lastScanError = "Errore nel salvataggio del prodotto manuale"
            }
        }
        manual = ""
    }
}

private struct ProductRow: View {
    let product: CDProduct

    var body: some View {
        HStack {
            productImage
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
                Badge(text: "Nutri-Score \(ns)")
            }
        }
    }

    private var productImage: some View {
        let url = URL(string: product.imageURL ?? "")
        return AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                Color.gray.opacity(0.2)
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure:
                Color.gray.opacity(0.2)
            @unknown default:
                Color.gray.opacity(0.2)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
