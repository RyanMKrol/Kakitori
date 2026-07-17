import Compression
import Foundation

enum ZipArchiveError: Error, Equatable {
    case notAZip
    case zip64Unsupported
    case encryptedEntryUnsupported
    case unsupportedCompressionMethod(UInt16)
    case entryNotFound(String)
    case decompressionFailed(String)
    case malformed
}

private struct EOCDData {
    let entryCount: UInt16
    let cdSize: UInt32
    let cdOffset: UInt32
}

struct ZipArchive {
    private let data: Data
    private let entries: [ZipEntry]

    var entryNames: [String] {
        entries.map(\.name)
    }

    init(url: URL) throws {
        data = try Data(contentsOf: url)

        if data.count < 22 {
            throw ZipArchiveError.notAZip
        }

        let tempArchive = ZipArchive(data: data, entries: [])
        let eocdOffset = try tempArchive.findEOCD()
        let eocdData = try tempArchive.parseEOCD(at: eocdOffset)

        if eocdData.entryCount == 0xFFFF || eocdData.cdOffset == 0xFFFF_FFFF {
            throw ZipArchiveError.zip64Unsupported
        }

        entries = try tempArchive.parseCentralDirectory(
            offset: Int(eocdData.cdOffset),
            size: Int(eocdData.cdSize),
            entryCount: Int(eocdData.entryCount)
        )
    }

    private init(data: Data, entries: [ZipEntry]) {
        self.data = data
        self.entries = entries
    }

    func extract(_ name: String, to url: URL) throws {
        guard let entry = entries.first(where: { $0.name == name }) else {
            throw ZipArchiveError.entryNotFound(name)
        }

        let extractedData = try extractEntry(entry)
        try extractedData.write(to: url, options: .atomic)
    }

    func extractAll(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for entry in entries {
            if entry.name.hasSuffix("/") {
                continue
            }

            if entry.name.contains("..") {
                continue
            }

            let extractedData = try extractEntry(entry)
            let filePath = directory.appendingPathComponent(entry.name)
            try extractedData.write(to: filePath, options: .atomic)
        }
    }

    private func findEOCD() throws -> Int {
        let searchLimit = min(data.count, 65557)
        let startOffset = max(0, data.count - searchLimit)

        let signature: UInt32 = 0x0605_4B50
        let signatureBytes = signature.littleEndianBytes

        for offset in stride(from: data.count - 22, through: startOffset, by: -1) {
            guard offset + 4 <= data.count else { continue }

            let slice = data.subdata(in: offset ..< offset + 4)
            if slice == Data(signatureBytes) {
                return offset
            }
        }

        throw ZipArchiveError.notAZip
    }

    private func parseEOCD(at offset: Int) throws -> EOCDData {
        guard offset + 22 <= data.count else {
            throw ZipArchiveError.malformed
        }

        let entryCount = try readUInt16(at: offset + 10)
        let cdSize = try readUInt32(at: offset + 12)
        let cdOffset = try readUInt32(at: offset + 16)

        return EOCDData(entryCount: entryCount, cdSize: cdSize, cdOffset: cdOffset)
    }

    private func parseCentralDirectory(offset: Int, size _: Int, entryCount: Int) throws -> [ZipEntry] {
        var entries: [ZipEntry] = []
        var currentOffset = offset

        for _ in 0 ..< entryCount {
            guard currentOffset + 4 <= data.count else {
                throw ZipArchiveError.malformed
            }

            let signature = try readUInt32(at: currentOffset)
            guard signature == 0x0201_4B50 else {
                throw ZipArchiveError.malformed
            }

            let entry = try parseEntry(at: currentOffset)
            entries.append(entry)

            let nameLen = Int(entry.nameLength)
            let extraLen = Int(entry.extraLength)
            let commentLen = Int(entry.commentLength)

            currentOffset += 46 + nameLen + extraLen + commentLen
        }

        return entries
    }

    private func parseEntry(at offset: Int) throws -> ZipEntry {
        guard offset + 46 <= data.count else {
            throw ZipArchiveError.malformed
        }

        let flags = try readUInt16(at: offset + 8)
        let isEncrypted = (flags & 1) != 0
        if isEncrypted {
            throw ZipArchiveError.encryptedEntryUnsupported
        }

        let compressionMethod = try readUInt16(at: offset + 10)
        let compressedSize = try readUInt32(at: offset + 20)
        let uncompressedSize = try readUInt32(at: offset + 24)
        let nameLength = try readUInt16(at: offset + 28)
        let extraLength = try readUInt16(at: offset + 30)
        let commentLength = try readUInt16(at: offset + 32)
        let localHeaderOffset = try readUInt32(at: offset + 42)

        guard offset + 46 + Int(nameLength) <= data.count else {
            throw ZipArchiveError.malformed
        }

        let nameData = data.subdata(in: offset + 46 ..< offset + 46 + Int(nameLength))
        guard let name = String(data: nameData, encoding: .utf8) else {
            throw ZipArchiveError.malformed
        }

        if compressedSize == 0xFFFF_FFFF || uncompressedSize == 0xFFFF_FFFF || localHeaderOffset == 0xFFFF_FFFF {
            throw ZipArchiveError.zip64Unsupported
        }

        return ZipEntry(
            name: name,
            compressionMethod: compressionMethod,
            compressedSize: compressedSize,
            uncompressedSize: uncompressedSize,
            nameLength: nameLength,
            extraLength: extraLength,
            commentLength: commentLength,
            localHeaderOffset: localHeaderOffset
        )
    }

    private func extractEntry(_ entry: ZipEntry) throws -> Data {
        let localHeaderOffset = Int(entry.localHeaderOffset)
        guard localHeaderOffset + 30 <= data.count else {
            throw ZipArchiveError.malformed
        }

        let localSignature = try readUInt32(at: localHeaderOffset)
        guard localSignature == 0x0403_4B50 else {
            throw ZipArchiveError.malformed
        }

        let localNameLength = try readUInt16(at: localHeaderOffset + 26)
        let localExtraLength = try readUInt16(at: localHeaderOffset + 28)

        let dataOffset = localHeaderOffset + 30 + Int(localNameLength) + Int(localExtraLength)
        let compressedSize = Int(entry.compressedSize)
        let uncompressedSize = Int(entry.uncompressedSize)

        guard dataOffset + compressedSize <= data.count else {
            throw ZipArchiveError.malformed
        }

        let compressedData = data.subdata(in: dataOffset ..< dataOffset + compressedSize)

        switch entry.compressionMethod {
        case 0:
            return compressedData

        case 8:
            return try decompressDeflate(compressedData, uncompressedSize: uncompressedSize, entryName: entry.name)

        default:
            throw ZipArchiveError.unsupportedCompressionMethod(entry.compressionMethod)
        }
    }

    private func decompressDeflate(_ data: Data, uncompressedSize: Int, entryName: String) throws -> Data {
        var decompressed = Data(count: uncompressedSize)

        let result = decompressed.withUnsafeMutableBytes { dstBuffer in
            data.withUnsafeBytes { srcBuffer in
                guard let dstPtr = dstBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self),
                      let srcPtr = srcBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return 0
                }

                return compression_decode_buffer(
                    dstPtr,
                    uncompressedSize,
                    srcPtr,
                    data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        guard result == uncompressedSize else {
            throw ZipArchiveError.decompressionFailed(entryName)
        }

        return decompressed
    }

    private func readUInt16(at offset: Int) throws -> UInt16 {
        guard offset + 2 <= data.count else {
            throw ZipArchiveError.malformed
        }

        let bytes = data.subdata(in: offset ..< offset + 2)
        return UInt16(bytes[0]) | (UInt16(bytes[1]) << 8)
    }

    private func readUInt32(at offset: Int) throws -> UInt32 {
        guard offset + 4 <= data.count else {
            throw ZipArchiveError.malformed
        }

        let bytes = data.subdata(in: offset ..< offset + 4)
        return UInt32(bytes[0]) | (UInt32(bytes[1]) << 8) | (UInt32(bytes[2]) << 16) | (UInt32(bytes[3]) << 24)
    }
}

private struct ZipEntry {
    let name: String
    let compressionMethod: UInt16
    let compressedSize: UInt32
    let uncompressedSize: UInt32
    let nameLength: UInt16
    let extraLength: UInt16
    let commentLength: UInt16
    let localHeaderOffset: UInt32
}

private extension UInt32 {
    var littleEndianBytes: [UInt8] {
        [
            UInt8(self & 0xFF),
            UInt8((self >> 8) & 0xFF),
            UInt8((self >> 16) & 0xFF),
            UInt8((self >> 24) & 0xFF),
        ]
    }
}
