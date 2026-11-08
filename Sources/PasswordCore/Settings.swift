import Foundation

/// Everything chosen in the window: the password options plus the repeat control. Saved whenever it
/// changes and loaded when the app opens, so the character types and their minimum counts don't have
/// to be set again each time. Kept in the app's own (sandboxed) user defaults; nothing leaves the Mac.
public struct Settings: Equatable, Codable {
    public var options = PasswordOptions()
    /// Use every character once before any repeats (the whole pool as one cycle).
    public var fullCycle = true
    /// Distinct characters before a repeat, when fullCycle is off.
    public var cycle = 16

    public static let key = "settings"

    public init() {}

    /// The saved settings, or the defaults when none are saved or they can't be read.
    public static func load(from defaults: UserDefaults = .standard) -> Settings {
        guard let data = defaults.data(forKey: key),
              let saved = try? JSONDecoder().decode(Settings.self, from: data) else { return Settings() }
        return saved
    }

    public func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.key) }
    }

    // Each value is read on its own, so settings saved by an older version (missing a newer value)
    // still load, with that one value at its default.
    private enum CodingKeys: String, CodingKey { case options, fullCycle, cycle }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        options = (try? c.decodeIfPresent(PasswordOptions.self, forKey: .options)) ?? PasswordOptions()
        fullCycle = (try? c.decodeIfPresent(Bool.self, forKey: .fullCycle)) ?? true
        cycle = (try? c.decodeIfPresent(Int.self, forKey: .cycle)) ?? 16
    }
}

extension PasswordOptions: Codable {
    private enum CodingKeys: String, CodingKey {
        case length, useLower, useUpper, useDigits, useSpecial
        case minLower, minUpper, minDigits, minSpecial, specialSet, excludeAmbiguous, cycleSize
    }

    public init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func read<T: Decodable>(_ key: CodingKeys, _ value: inout T) {
            if let v = try? c.decodeIfPresent(T.self, forKey: key) { value = v }
        }
        read(.length, &length)
        read(.useLower, &useLower); read(.useUpper, &useUpper)
        read(.useDigits, &useDigits); read(.useSpecial, &useSpecial)
        read(.minLower, &minLower); read(.minUpper, &minUpper)
        read(.minDigits, &minDigits); read(.minSpecial, &minSpecial)
        read(.specialSet, &specialSet); read(.excludeAmbiguous, &excludeAmbiguous)
        cycleSize = try? c.decodeIfPresent(Int.self, forKey: .cycleSize)
        length = Swift.min(Swift.max(length, Self.minLength), Self.maxLength)  // a saved value out of range is pulled in
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(length, forKey: .length)
        try c.encode(useLower, forKey: .useLower); try c.encode(useUpper, forKey: .useUpper)
        try c.encode(useDigits, forKey: .useDigits); try c.encode(useSpecial, forKey: .useSpecial)
        try c.encode(minLower, forKey: .minLower); try c.encode(minUpper, forKey: .minUpper)
        try c.encode(minDigits, forKey: .minDigits); try c.encode(minSpecial, forKey: .minSpecial)
        try c.encode(specialSet, forKey: .specialSet); try c.encode(excludeAmbiguous, forKey: .excludeAmbiguous)
        try c.encodeIfPresent(cycleSize, forKey: .cycleSize)
    }
}
