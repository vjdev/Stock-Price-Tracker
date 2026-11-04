import Foundation

struct StockFeedDTO: Codable, Equatable {
    var type: String
    var symbols: [String]? = nil
    var stocks: [Stock]? = nil
    var symbol: String? = nil
    var price: Double? = nil
    var change: Double? = nil
    var absoluteChange: Double? = nil
}
