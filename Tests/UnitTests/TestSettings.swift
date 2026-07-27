import Foundation
@testable import Kakitori

/// `AppSettings` backed by a throwaway `UserDefaults` suite instead of `.standard`.
///
/// Tests that read the daily limits must NOT read the app's real settings: a test asserting "10
/// introduced hits the cap" silently depends on the cap still being 10, so someone changing New
/// cards per day on the simulator — which is a normal thing to do while checking a feature — turns
/// the suite red for reasons that have nothing to do with the code.
enum TestSettings {
    /// - Parameters:
    ///   - newCardsPerDay: defaults to the app's own default, so callers that don't care read the
    ///     same numbers the app ships with rather than whatever the device was last set to.
    static func make(
        newCardsPerDay: Int = SRSConstants.defaultNewPerDay,
        maxReviewsPerDay: Int = SRSConstants.defaultMaxReviewsPerDay
    ) -> AppSettings {
        // A suite name unique per call keeps tests from leaking into each other, and nothing is
        // ever written to the standard domain.
        let suiteName = "kakitori.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return AppSettings()
        }
        defaults.removePersistentDomain(forName: suiteName)

        var settings = AppSettings(defaults: defaults)
        settings.newCardsPerDay = newCardsPerDay
        settings.maxReviewsPerDay = maxReviewsPerDay
        return settings
    }
}
