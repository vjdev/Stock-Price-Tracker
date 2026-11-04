import Foundation

@MainActor
final class AppCoordinator {
    private let repository: StockRepository
    private let analytics: AnalyticsOrchestrator
    private var feedRequested = false
    private var wasConnected = false

    init(repository: StockRepository, analytics: AnalyticsOrchestrator) {
        self.repository = repository
        self.analytics = analytics
    }

    func startFeed() {
        guard !feedRequested else { return }
        feedRequested = true
        analytics.track(.feedStarted)
        repository.start()
    }

    func stopFeed() {
        guard feedRequested else { return }
        feedRequested = false
        analytics.track(.feedStopped)
        repository.stop()
    }

    func sceneDidChange(isActive: Bool) {
        if isActive, feedRequested {
            repository.start()
        } else if !isActive, feedRequested {
            repository.stop()
        }
    }

    func connectionDidChange(_ state: WebSocketConnectionState) {
        switch state {
        case .connected where !wasConnected:
            analytics.track(.connectionEstablished)
            wasConnected = true
        case .disconnected, .reconnecting, .failed:
            if wasConnected { analytics.track(.connectionLost) }
            wasConnected = false
            if case .failed = state { feedRequested = false }
        default:
            break
        }
    }

    func selectStock(symbol: String) {
        analytics.track(.stockSelected(symbol: symbol))
    }

    func changeSort(to type: String) {
        analytics.track(.sortChanged(type: type))
    }
}
