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
            .init(name: "json", value: "1")
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue("CheSiMangia/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw OFFError.badResponse }
        struct S: Decodable { let products: [OFFProduct.Product] }
        return try JSONDecoder().decode(S.self, from: data).products
    }
}
