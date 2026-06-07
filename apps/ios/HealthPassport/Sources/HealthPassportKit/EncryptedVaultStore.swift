import CryptoKit
import Foundation

public enum VaultError: Error, Equatable {
    case invalidKeySize
    case unreadableArchive
}

public protocol VaultKeyProviding: Sendable {
    func vaultKeyData() throws -> Data
}

public struct StaticVaultKeyProvider: VaultKeyProviding {
    private let keyData: Data

    public init(keyData: Data) {
        self.keyData = keyData
    }

    public func vaultKeyData() throws -> Data {
        keyData
    }
}

public final class EncryptedVaultStore: @unchecked Sendable {
    private let fileURL: URL
    private let keyProvider: VaultKeyProviding
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL, keyProvider: VaultKeyProviding) {
        self.fileURL = fileURL
        self.keyProvider = keyProvider

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func load() throws -> VaultSnapshot {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .empty
        }

        let encrypted = try Data(contentsOf: fileURL)
        let decrypted = try decrypt(encrypted)

        do {
            return try decoder.decode(VaultSnapshot.self, from: decrypted)
        } catch {
            throw VaultError.unreadableArchive
        }
    }

    public func save(_ snapshot: VaultSnapshot) throws {
        var next = snapshot
        next.updatedAt = Date()

        let plaintext = try encoder.encode(next)
        let encrypted = try encrypt(plaintext)

        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try encrypted.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    public func exportUserArchive() throws -> Data {
        let snapshot = try load()
        return try encoder.encode(snapshot)
    }

    public func deleteLocalData() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }
        try FileManager.default.removeItem(at: fileURL)
    }

    public var exists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    private func encrypt(_ plaintext: Data) throws -> Data {
        let sealedBox = try AES.GCM.seal(plaintext, using: symmetricKey())
        guard let combined = sealedBox.combined else {
            throw VaultError.unreadableArchive
        }
        return combined
    }

    private func decrypt(_ encrypted: Data) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: encrypted)
        return try AES.GCM.open(sealedBox, using: symmetricKey())
    }

    private func symmetricKey() throws -> SymmetricKey {
        let keyData = try keyProvider.vaultKeyData()
        guard keyData.count == 32 else {
            throw VaultError.invalidKeySize
        }
        return SymmetricKey(data: keyData)
    }
}
