import Foundation

protocol CatalogMerchandiseFetching: Sendable {
    func searchMerchandise(matching query: String) async throws -> [CatalogMerchandiseRecord]
    func fetchMerchandise(europeanArticleNumber: String) async throws -> CatalogMerchandiseRecord
}

enum CatalogGatewayFailure: Error, Equatable {
    case emptyQuery
    case transport
    case missingProduct
    case undecodable
}

struct OpenFoodFactsCatalogGateway: CatalogMerchandiseFetching {
    private let session: URLSession
    private let userAgent = "RawSignal/1.0 (iOS; com.rawsignal.grid; grid calorie pulse)"

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchMerchandise(matching query: String) async throws -> [CatalogMerchandiseRecord] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CatalogGatewayFailure.emptyQuery }
        var components = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl")
        components?.queryItems = [
            URLQueryItem(name: "search_terms", value: trimmed),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "24")
        ]
        guard let url = components?.url else { throw CatalogGatewayFailure.transport }
        let root = try await decodeRoot(from: url)
        return (root.products ?? []).compactMap { $0.asMerchandiseRecord() }
    }

    func fetchMerchandise(europeanArticleNumber: String) async throws -> CatalogMerchandiseRecord {
        guard let encoded = europeanArticleNumber.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(encoded).json") else {
            throw CatalogGatewayFailure.transport
        }
        let root = try await decodeRoot(from: url)
        if let product = root.product?.asMerchandiseRecord() {
            return product
        }
        if let first = root.products?.compactMap({ $0.asMerchandiseRecord() }).first {
            return first
        }
        throw CatalogGatewayFailure.missingProduct
    }

    private func decodeRoot(from url: URL) async throws -> OpenFoodFactsRootNode {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, _) = try await session.data(for: request)
            return try JSONDecoder().decode(OpenFoodFactsRootNode.self, from: data)
        } catch is DecodingError {
            throw CatalogGatewayFailure.undecodable
        } catch {
            throw CatalogGatewayFailure.transport
        }
    }
}

private struct OpenFoodFactsRootNode: Decodable {
    var products: [OpenFoodFactsProductNode]?
    var product: OpenFoodFactsProductNode?
}

private struct OpenFoodFactsProductNode: Decodable {
    var code: String?
    var productName: String?
    var productNameEn: String?
    var brands: String?
    var nutriments: OpenFoodFactsNutrimentNode?
    var servingSize: String?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case productNameEn = "product_name_en"
        case brands
        case nutriments
        case servingSize = "serving_size"
    }

    func asMerchandiseRecord() -> CatalogMerchandiseRecord? {
        let title = (productName?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? (productNameEn?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
        guard let title else { return nil }
        let nutriments = self.nutriments ?? OpenFoodFactsNutrimentNode()
        let energy = nutriments.resolvedKilocaloriesPerHundred()
        let sku = (code?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? title
        return CatalogMerchandiseRecord(
            identifier: UUID().uuidString,
            stockKeepingUnit: sku,
            displayTitle: title,
            brandLine: brands?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            energyPerHundredGrams: energy,
            proteinPerHundredGrams: nutriments.proteins100g ?? 0,
            carbohydratePerHundredGrams: nutriments.carbohydrates100g ?? 0,
            lipidPerHundredGrams: nutriments.fat100g ?? 0,
            defaultServingGrams: OpenFoodFactsProductNode.parseServingGrams(servingSize) ?? 100,
            artworkAssetName: nil
        )
    }

    private static func parseServingGrams(_ raw: String?) -> Double? {
        guard let raw else { return nil }
        let digits = raw.split { !$0.isNumber && $0 != "." && $0 != "," }.first.map { $0.replacingOccurrences(of: ",", with: ".") }
        guard let digits, let value = Double(digits), value > 0 else { return nil }
        return value
    }
}

private struct OpenFoodFactsNutrimentNode: Decodable {
    var energyKcal100g: Double?
    var energyKcal: Double?
    var energy100g: Double?
    var proteins100g: Double?
    var carbohydrates100g: Double?
    var fat100g: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case energyKcal = "energy-kcal"
        case energy100g = "energy_100g"
        case proteins100g = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g = "fat_100g"
    }

    func resolvedKilocaloriesPerHundred() -> Double {
        if let energyKcal100g { return energyKcal100g }
        if let energyKcal { return energyKcal }
        if let energy100g { return NutrientPortionCalculator.kilocaloriesConvertedFromKilojoules(energy100g) }
        return 0
    }
}
