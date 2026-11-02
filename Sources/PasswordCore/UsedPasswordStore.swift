import Foundation
import CryptoKit

/// Remembers passwords the user reported as used, without storing the passwords.
/// Only salted SHA-256 hashes are written to disk (file mode 0600).
public final class UsedPasswordStore {
    private struct Payload: Codable { var salt: Data; var hashes: [String] }

    private let fileURL: URL
    private var salt: Data
    private var hashes: Set<String>

    public var count: Int { hashes.count }

    public init(fileURL: URL) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL),
           let p = try? JSONDecoder().decode(Payload.self, from: data) {
            salt = p.salt; hashes = Set(p.hashes)
        } else {
            var bytes = [UInt8](repeating: 0, count: 32)
            var rng = SystemRandomNumberGenerator()
            for i in bytes.indices { bytes[i] = UInt8.random(in: 0...255, using: &rng) }
            salt = Data(bytes); hashes = []
        }
    }

    /// Default location: the app's Application Support folder (inside the sandbox container).
    public static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("PasswordGenerator/used_hashes.json")
    }

    private func hash(_ password: String) -> String {
        SHA256.hash(data: salt + Data(password.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    public func contains(_ password: String) -> Bool { hashes.contains(hash(password)) }

    public func markUsed(_ password: String) throws {
        hashes.insert(hash(password))
        try save()
    }

    public func clear() throws {
        hashes.removeAll()
        try save()
    }

    private func save() throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(Payload(salt: salt, hashes: hashes.sorted()))
        try data.write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }
}

public extension PasswordGenerator {
    /// Generates a password that is not in `store`, retrying if a previously used one comes up.
    static func generateUnused(_ options: PasswordOptions, store: UsedPasswordStore) throws -> String {
        for _ in 0..<100 {
            let p = try generate(options)
            if !store.contains(p) { return p }
        }
        throw PasswordError.exhausted
    }
}
