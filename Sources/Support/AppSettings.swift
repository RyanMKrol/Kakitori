import Foundation

struct AppSettings {
    var defaults: UserDefaults = .standard

    var newCardsPerDay: Int {
        get {
            defaults.object(forKey: "newCardsPerDay") as? Int ?? 10
        }
        set {
            defaults.set(newValue, forKey: "newCardsPerDay")
        }
    }

    var maxReviewsPerDay: Int {
        get {
            defaults.object(forKey: "maxReviewsPerDay") as? Int ?? 100
        }
        set {
            defaults.set(newValue, forKey: "maxReviewsPerDay")
        }
    }

    var audioAutoplay: Bool {
        get {
            defaults.object(forKey: "audioAutoplay") as? Bool ?? true
        }
        set {
            defaults.set(newValue, forKey: "audioAutoplay")
        }
    }

    var showRomaji: Bool {
        get {
            defaults.object(forKey: "showRomaji") as? Bool ?? true
        }
        set {
            defaults.set(newValue, forKey: "showRomaji")
        }
    }
}
