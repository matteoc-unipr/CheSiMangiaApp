//
//  OFFClient.swift
//  CheSiMangia
//
//  Created by Matteo Costella on 25/09/25.
//

import Foundation

enum OFFError: Error { case notFound, badResponse }

final class OFFClient {
    static let shared = OFFClient()
    private init() {}

    func fetchProduct(barcode: String) async throws -> OFFProduct.Product {
        let url = URL(string: "https://world.openfoodfacts.org/api/v0/product/\(barcode).json")!
        var req = URLRequest(url: url)
        req.setValue("CheSiMangia/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw OFFError.badResponse }
        let res = try JSONDecoder().decode(OFFProduct.self, from: data)
        guard res.status == 1, let p = res.product else { throw OFFError.notFound }
        return p
    }

    func searchProducts(query: String) async throws -> [OFFProduct.Product] {
        var comps = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl")!
        comps.queryItems = [
            .init(name: "search_terms", value: query),
            .init(name: "search_simple", value: "1"),
            .init(name: "action", value: "process"),            // 👈 necessario
            .init(name: "json", value: "1"),
            .init(name: "page_size", value: "20"),
            // Limitiamo i campi per evitare problemi di decoding
            .init(name: "fields", value: "code,product_name,brands,image_url,nutriscore_grade,nova_group,allergens")
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue("CheSiMangia/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw OFFError.badResponse }

        struct SearchResponse: Decodable { let products: [OFFProduct.Product] }
        return try JSONDecoder().decode(SearchResponse.self, from: data).products
    }
}

// MARK: - NutriScore details

struct OFFNutriScoreData: Decodable {
    let energy_points: Int?
    let sugars_points: Int?
    let sat_fat_points: Int?
    let sodium_points: Int?
    let proteins_points: Int?
    let fiber_points: Int?
    let fruits_veg_nuts_points: Int?
    let nutriscore_score: Int?
    let nutriscore_grade: String?
}

private struct OFFNutriScoreEnvelope: Decodable {
    let product: Inner
    struct Inner: Decodable {
        let nutriscore_data: OFFNutriScoreData?
        let nutriscore_score: Int?
        let nutriscore_grade: String?
    }
}

extension OFFClient {
    /// Scarica e normalizza `nutriscore_data` del prodotto
    func fetchNutriScoreDetails(barcode: String) async throws -> OFFNutriScoreData {
        // chiediamo esplicitamente solo i campi utili
        var comps = URLComponents(string: "https://world.openfoodfacts.org/api/v0/product/\(barcode).json")!
        comps.queryItems = [
            .init(name: "fields", value: "product.nutriscore_data,product.nutriscore_score,product.nutriscore_grade")
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue("CheSiMangia/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw OFFError.badResponse }

        struct Envelope: Decodable {
            let product: Product?
            struct Product: Decodable {
                let nutriscore_data: [String: JSONValue]?
                let nutriscore_score: Int?
                let nutriscore_grade: String?
            }
        }
        let env = try JSONDecoder().decode(Envelope.self, from: data)
        let d = env.product?.nutriscore_data ?? [:]

        func int(_ keys: [String]) -> Int? {
            for k in keys {
                if let v = d[k] {
                    switch v {
                    case .number(let n): return Int(n.rounded())
                    case .string(let s): if let n = Int(s) { return n }
                    default: break
                    }
                }
            }
            return nil
        }

        // alias noti delle chiavi OFF
        let energy = int(["energy_points"])
        let sugars = int(["sugars_points"])
        let satFat = int(["saturated-fat_points","saturated_fat_points","sat_fat_points"])
        let sodium = int(["sodium_points","salt_points"])   // a volte “salt_points”
        let proteins = int(["proteins_points"])
        let fiber = int(["fiber_points","fibers_points"])
        let fruits = int([
            "fruits_vegetables_nuts_colza_walnut_olive_oils_points",
            "fruits_vegetables_nuts_points",
            "fruits_veg_nuts_points"
        ])

        return OFFNutriScoreData(
            energy_points: energy,
            sugars_points: sugars,
            sat_fat_points: satFat,
            sodium_points: sodium,
            proteins_points: proteins,
            fiber_points: fiber,
            fruits_veg_nuts_points: fruits,
            nutriscore_score: env.product?.nutriscore_score,
            nutriscore_grade: env.product?.nutriscore_grade
        )
    }
}
