import Combine
import Foundation

@MainActor
final class AppContainer: ObservableObject {
    let repository: StockRepository
    let analytics: AnalyticsOrchestrator
    let stockListViewModel: StockListViewModel
    let coordinator: AppCoordinator

    init(repository: StockRepository? = nil, analyticsProviders: [AnalyticsProvider]? = nil) {
        let repository = repository ?? WebSocketStockRepository(endpoint: AppConfiguration.stockFeedEndpoint)
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
