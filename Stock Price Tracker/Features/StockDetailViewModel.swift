import Combine
import Foundation

@MainActor
final class StockDetailViewModel: ObservableObject {
    @Published private(set) var stock: Stock?

    private let symbol: String
    private var stockUpdates: AnyCancellable?

    init(symbol: String, stockListViewModel: StockListViewModel) {
        self.symbol = symbol
        stock = stockListViewModel.stock(for: symbol)
        stockUpdates = stockListViewModel.$stocks.sink { [weak self] stocks in
            guard let self else { return }
            stock = stocks.first { $0.symbol == symbol }
        }
    }
}
