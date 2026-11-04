import Foundation

@MainActor
protocol StockRepository: AnyObject {
    var stocks: [Stock] { get }
    var stockSnapshots: AsyncStream<[Stock]> { get }
    var connectionStates: AsyncStream<WebSocketConnectionState> { get }
    func start()
    func stop()
}

struct StockPriceUpdate: Codable, Equatable, Sendable {
    let symbol: String
    let price: Double
    let change: Double
    var absoluteChange: Double = 0
}
