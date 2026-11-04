import Foundation

struct StockFeedDTO: Codable, Equatable {
    var type: String
    var symbols: [String]?
    var stocks: [Stock]?
    var symbol: String?
    var price: Double?
    var change: Double?
}
