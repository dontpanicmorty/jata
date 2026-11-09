import Foundation

/// How hard a password from these options is to guess, measured in bits of entropy: each character
/// is drawn from the pool, so a password has about length × log2(pool size) bits. (The no-repeat
/// cycles narrow this slightly; at the lengths this app allows the difference doesn't change the rating.)
public enum Strength: Int, Comparable, CaseIterable {
    case weak, fair, strong, veryStrong

    public static func < (a: Strength, b: Strength) -> Bool { a.rawValue < b.rawValue }

    public var label: String {
        switch self {
        case .weak: return "Weak"
        case .fair: return "Fair"
        case .strong: return "Strong"
        case .veryStrong: return "Very strong"
        }
    }

    /// Under 50 bits is guessable offline; 80 is a common minimum for important accounts; 110+ is
    /// beyond any realistic attack.
    public init(bits: Double) {
        switch bits {
        case ..<50: self = .weak
        case ..<80: self = .fair
        case ..<110: self = .strong
        default: self = .veryStrong
        }
    }
}

extension PasswordOptions {
    /// Bits of entropy of a password made with these options; 0 when the pool is empty.
    public var entropyBits: Double {
        let pool = poolSize
        return pool > 1 ? Double(length) * log2(Double(pool)) : 0
    }

    public var strength: Strength { Strength(bits: entropyBits) }
}
