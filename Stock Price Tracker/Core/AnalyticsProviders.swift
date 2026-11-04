import os

struct ConsoleAnalyticsProvider: AnalyticsProvider {
    private let logger = AppLogger.logger(category: "Analytics")

    func track(event: AnalyticsEvent) {
        logger.info("Analytics event: \(event.name, privacy: .public), properties: \(String(describing: event.properties), privacy: .public)")
    }
}

#if canImport(FirebaseAnalytics)
import FirebaseAnalytics

struct FirebaseAnalyticsProvider: AnalyticsProvider {
    func track(event: AnalyticsEvent) {
        Analytics.logEvent(event.name, parameters: event.properties)
    }
}
#endif

#if canImport(Mixpanel)
import Mixpanel

struct MixpanelAnalyticsProvider: AnalyticsProvider {
    func track(event: AnalyticsEvent) {
        Mixpanel.mainInstance().track(event: event.name, properties: event.properties)
    }
}
#endif
