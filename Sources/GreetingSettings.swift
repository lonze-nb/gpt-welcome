import Foundation

struct GreetingSettings {
    private static let preferenceKey = "greetingSettings"
    static let defaultGreeting = "welcome"

    let profileURL: URL
    var defaults: UserDefaults = .standard

    static func normalized(_ value: String) -> String? {
        let greeting = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !greeting.isEmpty, greeting.utf8.count <= 512,
              greeting.unicodeScalars.allSatisfy({ $0.value >= 32 && !(127...159).contains($0.value) })
        else { return nil }
        return greeting
    }

    private var adjacentGreeting: String? {
        guard let file = try? FileHandle(forReadingFrom: profileURL) else { return nil }
        defer { try? file.close() }
        guard let data = try? file.read(upToCount: 4097), data.count <= 4096,
              let profile = try? JSONDecoder().decode([String: String].self, from: data),
              let greeting = profile["greeting"] else { return nil }
        return Self.normalized(greeting)
    }

    private var saved: [String: String] {
        defaults.dictionary(forKey: Self.preferenceKey) as? [String: String] ?? [:]
    }

    func currentGreeting() -> String {
        let preferences = saved
        if let adjacentGreeting, adjacentGreeting != preferences["imported"] {
            defaults.set(["greeting": adjacentGreeting, "imported": adjacentGreeting], forKey: Self.preferenceKey)
            return adjacentGreeting
        }
        return preferences["greeting"] ?? Self.defaultGreeting
    }

    @discardableResult
    func setGreeting(_ value: String) -> Bool {
        guard let greeting = Self.normalized(value) else { return false }
        var preferences = saved
        preferences["greeting"] = greeting
        if let adjacentGreeting { preferences["imported"] = adjacentGreeting }
        defaults.set(preferences, forKey: Self.preferenceKey)
        return true
    }
}
