import Foundation

public enum CharClass: CaseIterable, Hashable {
    case lower, upper, digit, special
}

public enum PasswordError: Error, CustomStringConvertible {
    case lengthOutOfRange
    case noClassSelected
    case minimumsExceedLength
    case emptySpecialSet
    case unsatisfiable
    case exhausted

    public var description: String {
        switch self {
        case .lengthOutOfRange: return "Length must be between \(PasswordOptions.minLength) and \(PasswordOptions.maxLength)."
        case .noClassSelected: return "Select at least one character type."
        case .minimumsExceedLength: return "Minimum counts add up to more than the password length."
        case .emptySpecialSet: return "Special characters are enabled but the set is empty."
        case .unsatisfiable: return "Could not satisfy the minimum counts with these settings."
        case .exhausted: return "Could not find an unused password with these settings."
        }
    }
}

public struct PasswordOptions: Equatable {
    public static let minLength = 8
    public static let maxLength = 256
    public static let defaultLength = 32
    public static let defaultSpecial = "!@#$%^&*()-_=+[]{};:,.<>?/~"
    public static let ambiguous: Set<Character> = ["I", "l", "1", "O", "0", "|"]

    public var length = PasswordOptions.defaultLength
    public var useLower = true, useUpper = true, useDigits = true, useSpecial = true
    public var minLower = 0, minUpper = 0, minDigits = 0, minSpecial = 0
    public var specialSet = PasswordOptions.defaultSpecial
    public var excludeAmbiguous = false
    /// How many distinct characters are used before any character may repeat.
    /// nil = the entire pool (every character is used once before any repeats).
    public var cycleSize: Int? = nil

    public init() {}

    public func pool(for cls: CharClass) -> [Character] {
        let raw: [Character]
        switch cls {
        case .lower: raw = useLower ? Array("abcdefghijklmnopqrstuvwxyz") : []
        case .upper: raw = useUpper ? Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ") : []
        case .digit: raw = useDigits ? Array("0123456789") : []
        case .special:
            var seen = Set<Character>()
            raw = useSpecial ? specialSet.filter { !$0.isWhitespace && seen.insert($0).inserted } : []
        }
        return excludeAmbiguous ? raw.filter { !Self.ambiguous.contains($0) } : raw
    }

    public func minimum(for cls: CharClass) -> Int {
        switch cls {
        case .lower: return useLower ? minLower : 0
        case .upper: return useUpper ? minUpper : 0
        case .digit: return useDigits ? minDigits : 0
        case .special: return useSpecial ? minSpecial : 0
        }
    }

    public var poolSize: Int { CharClass.allCases.reduce(0) { $0 + pool(for: $1).count } }
}

public enum PasswordGenerator {
    /// Builds the password in "cycles". Each cycle is a random selection of distinct
    /// characters, so no character repeats until the cycle is used up. With the default
    /// cycle size (the whole pool), every character is used once before any is reused.
    public static func generate<G: RandomNumberGenerator>(
        _ options: PasswordOptions, using rng: inout G
    ) throws -> String {
        guard (PasswordOptions.minLength...PasswordOptions.maxLength).contains(options.length)
        else { throw PasswordError.lengthOutOfRange }
        if options.useSpecial && options.pool(for: .special).isEmpty { throw PasswordError.emptySpecialSet }
        let pools = Dictionary(uniqueKeysWithValues: CharClass.allCases.map { ($0, options.pool(for: $0)) })
        let all = pools.values.flatMap { $0 }
        guard !all.isEmpty else { throw PasswordError.noClassSelected }
        let mins = Dictionary(uniqueKeysWithValues: CharClass.allCases.map { ($0, options.minimum(for: $0)) })
        guard mins.values.reduce(0, +) <= options.length else { throw PasswordError.minimumsExceedLength }

        for _ in 0..<50 {
            let result = build(options, pools: pools, all: all, mins: mins, using: &rng)
            let ok = CharClass.allCases.allSatisfy { cls in
                result.filter { pools[cls]!.contains($0) }.count >= mins[cls]!
            }
            if ok { return String(result) }
        }
        throw PasswordError.unsatisfiable
    }

    public static func generate(_ options: PasswordOptions) throws -> String {
        var rng = SystemRandomNumberGenerator()
        return try generate(options, using: &rng)
    }

    private static func build<G: RandomNumberGenerator>(
        _ options: PasswordOptions, pools: [CharClass: [Character]], all: [Character],
        mins: [CharClass: Int], using rng: inout G
    ) -> [Character] {
        var needs = mins
        var out: [Character] = []
        let cap = min(max(options.cycleSize ?? all.count, 1), all.count)

        while out.count < options.length {
            let n = min(cap, options.length - out.count)
            var avail = pools.mapValues { $0.shuffled(using: &rng) }
            var chosen: [Character] = []

            // Forced picks to satisfy per-type minimums, round-robin so none starves.
            var progressed = true
            while chosen.count < n && progressed {
                progressed = false
                for cls in CharClass.allCases where chosen.count < n && needs[cls]! > 0 && !avail[cls]!.isEmpty {
                    chosen.append(avail[cls]!.removeLast())
                    needs[cls]! -= 1
                    progressed = true
                }
            }
            // Fill the rest uniformly from what's left in the pool.
            var rest = avail.values.flatMap { $0 }.shuffled(using: &rng)
            while chosen.count < n { chosen.append(rest.removeLast()) }

            chosen.shuffle(using: &rng)
            // Avoid the same character back-to-back across a cycle boundary.
            if let last = out.last, chosen.count > 1, chosen[0] == last {
                let j = Int.random(in: 1..<chosen.count, using: &rng)
                chosen.swapAt(0, j)
            }
            out.append(contentsOf: chosen)
        }
        return out
    }
}
