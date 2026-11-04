import Foundation

enum StockFeedMapper {
    static func validatedSnapshot(from payload: StockFeedDTO) throws -> [Stock] {
        guard payload.type == "snapshot",
              let stocks = payload.stocks,
              !stocks.isEmpty else {
            throw WebSocketError.invalidPayload
        }
        let allowedSymbols = Set(StockWatchlist.symbols)
        var receivedSymbols = Set<String>()
        for stock in stocks {
            guard allowedSymbols.contains(stock.symbol),
                  receivedSymbols.insert(stock.symbol).inserted,
                  stock.price.isFinite,
                  stock.price > 0,
                  stock.change.isFinite,
                  stock.absoluteChange.isFinite else {
                throw WebSocketError.invalidPayload
            }
        }
        return stocks
    }

    static func snapshotMessage(_ stocks: [Stock]) -> StockFeedDTO {
        StockFeedDTO(type: "snapshot", stocks: stocks)
    }

    static func updateMessage(_ update: StockPriceUpdate) -> StockFeedDTO {
        StockFeedDTO(
            type: "update",
            symbol: update.symbol,
            price: update.price,
            change: update.change,
            absoluteChange: update.absoluteChange
        )
    }

    static func stockUpdate(from payload: StockFeedDTO) throws -> StockPriceUpdate {
        guard payload.type == "update",
              let symbol = payload.symbol,
              let price = payload.price,
              let change = payload.change,
              let absoluteChange = payload.absoluteChange,
              StockWatchlist.symbols.contains(symbol),
              price.isFinite,
              price > 0,
              change.isFinite,
              absoluteChange.isFinite else {
            throw WebSocketError.invalidPayload
        }
        return StockPriceUpdate(
            symbol: symbol,
            price: price,
            change: change,
            absoluteChange: absoluteChange
        )
    }
}
