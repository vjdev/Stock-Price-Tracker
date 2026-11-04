import Foundation

@MainActor
protocol StockPriceGenerating: AnyObject {
    func makeSnapshot() -> [Stock]
    func makeUpdate() throws -> StockPriceUpdate
}

@MainActor
final class StockPriceGenerator: StockPriceGenerating {
    private var prices: [String: Double] = [:]
    private var random: AnyRandomNumberGenerator

    // MARK: - Initialization -

    init<R: RandomNumberGenerator>(random: R = SystemRandomNumberGenerator()) {
        self.random = AnyRandomNumberGenerator(random)
    }

    // MARK: - Snapshot Generation -

    func makeSnapshot() -> [Stock] {
        StockWatchlist.companies.map { company in
            let price = Double.random(in: 25...950, using: &random)
            prices[company.symbol] = price
            return Stock(
                symbol: company.symbol,
                name: company.name,
                description: company.description,
                price: price,
                change: 0,
                absoluteChange: 0
            )
        }
    }

    // MARK: - Random Number Generation -

    private struct AnyRandomNumberGenerator: RandomNumberGenerator {
        private var nextValue: () -> UInt64

        init<Generator: RandomNumberGenerator>(_ generator: Generator) {
            var generator = generator
            nextValue = { generator.next() }
        }

        mutating func next() -> UInt64 {
            nextValue()
        }
    }

    // MARK: - Price Updates -

    func makeUpdate() throws -> StockPriceUpdate {
        guard let symbol = StockWatchlist.symbols.randomElement(using: &random),
              let current = prices[symbol] else {
            throw WebSocketError.invalidPayload
        }
        let movementPercentage = Double.random(in: -1.2...1.2, using: &random)
        let price = max(0.01, current * (1 + movementPercentage / 100))
        let absoluteChange = price - current
        let change = absoluteChange / current * 100
        prices[symbol] = price
        return StockPriceUpdate(
            symbol: symbol,
            price: price,
            change: change,
            absoluteChange: absoluteChange
        )
    }
}
