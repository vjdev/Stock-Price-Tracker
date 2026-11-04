import Foundation

// MARK: - Stock Model -

struct Stock: Codable, Identifiable, Equatable, Sendable {
    let symbol: String
    let name: String
    let description: String
    var price: Double
    var change: Double
    var absoluteChange: Double = 0
    var lastUpdated: Date = .now

    var id: String { symbol }
    var isPositive: Bool { change >= 0 }
}

enum StockSortOption: String, CaseIterable, Identifiable {
    case priceAscending
    case priceDescending
    case changeAscending
    case changeDescending

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .priceAscending: String(localized: "sort.priceAscending")
        case .priceDescending: String(localized: "sort.priceDescending")
        case .changeAscending: String(localized: "sort.changeAscending")
        case .changeDescending: String(localized: "sort.changeDescending")
        }
    }
}

// MARK: - Stock Watchlist -

enum StockWatchlist {
    static let companies = [
        StockMetadata(symbol: "AAPL", name: "Apple Inc.", description: "Designs consumer electronics, software, and digital services."),
        StockMetadata(symbol: "GOOG", name: "Alphabet Inc.", description: "A technology company known for Google Search, YouTube, and cloud services."),
        StockMetadata(symbol: "TSLA", name: "Tesla, Inc.", description: "Develops electric vehicles, battery storage, and clean energy products."),
        StockMetadata(symbol: "AMZN", name: "Amazon.com, Inc.", description: "Operates e-commerce, cloud computing, streaming, and logistics businesses."),
        StockMetadata(symbol: "MSFT", name: "Microsoft Corporation", description: "Builds software, cloud services, devices, and productivity tools."),
        StockMetadata(symbol: "NVDA", name: "NVIDIA Corporation", description: "Creates accelerated computing and graphics platforms used in AI and gaming."),
        StockMetadata(symbol: "META", name: "Meta Platforms, Inc.", description: "Builds social platforms and technologies that connect people and communities."),
        StockMetadata(symbol: "NFLX", name: "Netflix, Inc.", description: "Provides subscription entertainment including films, series, and games."),
        StockMetadata(symbol: "AMD", name: "Advanced Micro Devices", description: "Designs processors and graphics products for computing markets."),
        StockMetadata(symbol: "INTC", name: "Intel Corporation", description: "Designs and manufactures semiconductor products for computing."),
        StockMetadata(symbol: "ORCL", name: "Oracle Corporation", description: "Provides database technology, cloud infrastructure, and business software."),
        StockMetadata(symbol: "CRM", name: "Salesforce, Inc.", description: "Provides customer relationship management and cloud-based business software."),
        StockMetadata(symbol: "ADBE", name: "Adobe Inc.", description: "Develops creative, document, and digital experience software."),
        StockMetadata(symbol: "COST", name: "Costco Wholesale", description: "Operates membership warehouses offering a wide range of merchandise."),
        StockMetadata(symbol: "WMT", name: "Walmart Inc.", description: "Operates retail stores and e-commerce marketplaces around the world."),
        StockMetadata(symbol: "JPM", name: "JPMorgan Chase & Co.", description: "A global financial services firm serving consumers and institutions."),
        StockMetadata(symbol: "V", name: "Visa Inc.", description: "Operates a global digital payments network."),
        StockMetadata(symbol: "MA", name: "Mastercard Incorporated", description: "Operates a global payments technology network."),
        StockMetadata(symbol: "KO", name: "The Coca-Cola Company", description: "Produces and distributes a portfolio of beverages worldwide."),
        StockMetadata(symbol: "PEP", name: "PepsiCo, Inc.", description: "Produces beverages and convenient foods for global markets."),
        StockMetadata(symbol: "DIS", name: "The Walt Disney Company", description: "Operates entertainment, media, parks, and consumer products businesses."),
        StockMetadata(symbol: "UBER", name: "Uber Technologies, Inc.", description: "Connects consumers with mobility, delivery, and freight services."),
        StockMetadata(symbol: "SHOP", name: "Shopify Inc.", description: "Provides commerce tools that help businesses manage online stores."),
        StockMetadata(symbol: "SPOT", name: "Spotify Technology", description: "Provides audio streaming for music, podcasts, and other audio content."),
        StockMetadata(symbol: "PFE", name: "Pfizer Inc.", description: "Discovers, develops, and manufactures medicines and vaccines.")
    ]

    static let symbols = companies.map(\.symbol)
}

struct StockMetadata: Sendable {
    let symbol: String
    let name: String
    let description: String
}
