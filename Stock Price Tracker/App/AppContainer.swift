import Combine
import Foundation

@MainActor
final class AppContainer: ObservableObject {
    let repository: StockRepository
    let analytics: AnalyticsOrchestrator
    let stockListViewModel: StockListViewModel
    let coordinator: AppCoordinator

    init(repository: StockRepository? = nil, analyticsProviders: [AnalyticsProvider]? = nil) {
        let isUITesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        let repository = repository ?? (isUITesting
            ? UITestStockRepository()
            : WebSocketStockRepository(endpoint: AppConfiguration.stockFeedEndpoint))
        self.repository = repository
        let providers = analyticsProviders ?? Self.defaultAnalyticsProviders()
        analytics = AnalyticsOrchestrator(providers: providers)
        let coordinator = AppCoordinator(repository: repository, analytics: analytics)
        self.coordinator = coordinator
        stockListViewModel = StockListViewModel(repository: repository, coordinator: coordinator)
    }

    private static func defaultAnalyticsProviders() -> [AnalyticsProvider] {
        var providers: [AnalyticsProvider] = [ConsoleAnalyticsProvider()]
        #if canImport(FirebaseAnalytics)
        providers.append(FirebaseAnalyticsProvider())
        #endif
        #if canImport(Mixpanel)
        providers.append(MixpanelAnalyticsProvider())
        #endif
        return providers
    }
}

@MainActor
private final class UITestStockRepository: StockRepository {
    private let snapshotContinuation: AsyncStream<[Stock]>.Continuation
    private let stateContinuation: AsyncStream<WebSocketConnectionState>.Continuation

    let stocks = [
        Stock(
            symbol: "AAPL",
            name: "Apple Inc.",
            description: "Consumer technology company.",
            price: 189.25,
            change: 1.5,
            absoluteChange: 2.8
        ),
        Stock(
            symbol: "MSFT",
            name: "Microsoft Corporation",
            description: "Software and cloud services company.",
            price: 420.5,
            change: -0.75,
            absoluteChange: -3.15
        )
    ]
    let stockSnapshots: AsyncStream<[Stock]>
    let connectionStates: AsyncStream<WebSocketConnectionState>

    init() {
        let snapshots = AsyncStream<[Stock]>.makeStream(bufferingPolicy: .bufferingNewest(1))
        stockSnapshots = snapshots.stream
        snapshotContinuation = snapshots.continuation
        let states = AsyncStream<WebSocketConnectionState>.makeStream(bufferingPolicy: .bufferingNewest(1))
        connectionStates = states.stream
        stateContinuation = states.continuation
        snapshotContinuation.yield(stocks)
        stateContinuation.yield(.disconnected)
    }

    func start() {
        stateContinuation.yield(.connecting)
        stateContinuation.yield(.connected)
    }

    func stop() {
        stateContinuation.yield(.disconnected)
    }
}
