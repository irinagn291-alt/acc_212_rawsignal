import Foundation

protocol SignalVaultPersisting: AnyObject {
    func loadEnvelope() -> SignalVaultEnvelope
    func persistEnvelope(_ envelope: SignalVaultEnvelope)
}

enum SignalArchiveBinaryCodec {
    static let magicHeader = Data([0x52, 0x53, 0x47, 0x31])
    static let formatVersion: UInt16 = 1

    static func encodeEnvelope(_ envelope: SignalVaultEnvelope) throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let payload = try encoder.encode(envelope)
        var archive = Data()
        archive.append(magicHeader)
        archive.append(contentsOf: Self.bigEndianBytes(formatVersion))
        archive.append(contentsOf: Self.bigEndianBytes(UInt32(payload.count)))
        archive.append(payload)
        archive.append(contentsOf: Self.bigEndianBytes(crc32(payload)))
        return archive
    }

    static func decodeEnvelope(from archive: Data) throws -> SignalVaultEnvelope {
        let headerCount = 4 + 2 + 4
        guard archive.count >= headerCount + 4 else {
            throw SignalArchiveFailure.truncated
        }
        guard archive.prefix(4) == magicHeader else {
            throw SignalArchiveFailure.badMagic
        }
        let version = readUInt16(archive, at: 4)
        guard version == formatVersion else {
            throw SignalArchiveFailure.unsupportedVersion
        }
        let payloadLength = Int(readUInt32(archive, at: 6))
        let payloadEnd = 10 + payloadLength
        guard archive.count >= payloadEnd + 4 else {
            throw SignalArchiveFailure.truncated
        }
        let payload = archive.subdata(in: 10..<payloadEnd)
        let storedChecksum = readUInt32(archive, at: payloadEnd)
        guard storedChecksum == crc32(payload) else {
            throw SignalArchiveFailure.checksumMismatch
        }
        return try PropertyListDecoder().decode(SignalVaultEnvelope.self, from: payload)
    }

    private static func bigEndianBytes(_ value: UInt16) -> [UInt8] {
        [UInt8(value >> 8), UInt8(value & 0xFF)]
    }

    private static func bigEndianBytes(_ value: UInt32) -> [UInt8] {
        [
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        ]
    }

    private static func readUInt16(_ data: Data, at offset: Int) -> UInt16 {
        (UInt16(data[offset]) << 8) | UInt16(data[offset + 1])
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        (UInt32(data[offset]) << 24)
            | (UInt32(data[offset + 1]) << 16)
            | (UInt32(data[offset + 2]) << 8)
            | UInt32(data[offset + 3])
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                let mask = (crc & 1).twosComplementMask
                crc = (crc >> 1) ^ (0xEDB8_8320 & mask)
            }
        }
        return crc ^ 0xFFFF_FFFF
    }
}

private extension UInt32 {
    var twosComplementMask: UInt32 { self == 0 ? 0 : 0xFFFF_FFFF }
}

enum SignalArchiveFailure: Error {
    case truncated
    case badMagic
    case unsupportedVersion
    case checksumMismatch
}

final class SignalArchiveBinaryStore: SignalVaultPersisting, @unchecked Sendable {
    private let fileURL: URL
    private let lock = NSLock()
    private var memoryCache: SignalVaultEnvelope?

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func loadEnvelope() -> SignalVaultEnvelope {
        lock.lock()
        defer { lock.unlock() }
        if let memoryCache {
            return memoryCache
        }
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? SignalArchiveBinaryCodec.decodeEnvelope(from: data) else {
            let empty = SignalVaultEnvelope.emptyFactory()
            memoryCache = empty
            return empty
        }
        memoryCache = decoded
        return decoded
    }

    func persistEnvelope(_ envelope: SignalVaultEnvelope) {
        lock.lock()
        defer { lock.unlock() }
        memoryCache = envelope
        guard let data = try? SignalArchiveBinaryCodec.encodeEnvelope(envelope) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }
}

final class InMemorySignalVault: SignalVaultPersisting {
    var envelope: SignalVaultEnvelope

    init(envelope: SignalVaultEnvelope = .emptyFactory()) {
        self.envelope = envelope
    }

    func loadEnvelope() -> SignalVaultEnvelope { envelope }

    func persistEnvelope(_ envelope: SignalVaultEnvelope) {
        self.envelope = envelope
    }
}
