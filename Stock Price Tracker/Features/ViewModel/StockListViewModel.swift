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
        case .priceAscending: return sort(visibleStocks, by: \.price, ascending: true)
        case .priceDescending: return sort(visibleStocks, by: \.price, ascending: false)
        case .changeAscending: return sort(visibleStocks, by: \.change, ascending: true)
        case .changeDescending: return sort(visibleStocks, by: \.change, ascending: false)
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

    private func sort(
        _ stocks: [Stock],
        by keyPath: KeyPath<Stock, Double>,
        ascending: Bool
    ) -> [Stock] {
        stocks.sorted { lhs, rhs in
            let leftValue = lhs[keyPath: keyPath]
            let rightValue = rhs[keyPath: keyPath]
            guard leftValue == rightValue else {
                return ascending ? leftValue < rightValue : leftValue > rightValue
            }
            return lhs.symbol < rhs.symbol
        }
    }
}
