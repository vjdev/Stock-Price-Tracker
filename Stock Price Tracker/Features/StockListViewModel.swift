import Combine
import Foundation

@MainActor
final class StockListViewModel: ObservableObject {
    @Published private(set) var stocks: [Stock] = []
    @Published private(set) var connectionState: WebSocketConnectionState = .disconnected
    @Published var searchQuery = ""
    @Published var sortOption: StockSortOption = .priceDescending {
        didSet {
            guard oldValue != sortOption else { return }
            coordinator.changeSort(to: sortOption.rawValue)
        }
    }

    private let repository: StockRepository
    private let coordinator: AppCoordinator
    private var snapshotTask: Task<Void, Never>?
    private var connectionTask: Task<Void, Never>?

    init(repository: StockRepository, coordinator: AppCoordinator) {
        self.repository = repository
        self.coordinator = coordinator
        stocks = repository.stocks
        observeFeed()
    }

    deinit {
        snapshotTask?.cancel()
        connectionTask?.cancel()
    }

    var sortedStocks: [Stock] {
        let visibleStocks = stocks.filter {
            searchQuery.isEmpty ||
                $0.symbol.localizedCaseInsensitiveContains(searchQuery) ||
                $0.name.localizedCaseInsensitiveContains(searchQuery)
        }
        switch sortOption {
        case .priceAscending:
            return visibleStocks.sorted { $0.price == $1.price ? $0.symbol < $1.symbol : $0.price < $1.price }
        case .priceDescending:
            return visibleStocks.sorted { $0.price == $1.price ? $0.symbol < $1.symbol : $0.price > $1.price }
        case .changeAscending:
            return visibleStocks.sorted { $0.change == $1.change ? $0.symbol < $1.symbol : $0.change < $1.change }
        case .changeDescending:
            return visibleStocks.sorted { $0.change == $1.change ? $0.symbol < $1.symbol : $0.change > $1.change }
        }
    }

    func stock(for symbol: String) -> Stock? {
        stocks.first(where: { $0.symbol == symbol })
    }

    func startFeed() {
        coordinator.startFeed()
    }

    func stopFeed() {
        coordinator.stopFeed()
    }

    func selectStock(symbol: String) {
        coordinator.selectStock(symbol: symbol)
    }

    private func observeFeed() {
        snapshotTask = Task { [weak self, repository] in
            for await snapshot in repository.stockSnapshots {
                self?.replaceStocks(with: snapshot)
            }
        }

        connectionTask = Task { [weak self, repository] in
            for await state in repository.connectionStates {
                guard let self else { continue }
                connectionState = state
                coordinator.connectionDidChange(state)
            }
        }
    }

    private func replaceStocks(with snapshot: [Stock]) {
        stocks = snapshot
    }
}
