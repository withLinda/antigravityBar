import Foundation

struct AccountDisclosureStore {
    private let defaults: UserDefaults
    private let keyPrefix = "accountDisclosure."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func isExpanded(email: String) -> Bool {
        let key = keyPrefix + email
        guard defaults.object(forKey: key) != nil else {
            return true
        }
        return defaults.bool(forKey: key)
    }

    func setExpanded(_ isExpanded: Bool, for email: String) {
        defaults.set(isExpanded, forKey: keyPrefix + email)
    }
}
