final class AnalyticsOrchestrator {
    private let providers: [AnalyticsProvider]

    init(providers: [AnalyticsProvider]) {
        self.providers = providers
    }

    func track(_ event: AnalyticsEvent) {
        providers.forEach { $0.track(event: event) }
    }
}
