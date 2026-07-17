import CryptoKit
import Foundation

enum NoteIdentity {
    static func uuid(forAnkiGUID guid: String) -> UUID {
        let digest = SHA256.hash(data: Data(guid.utf8))
        let bytes = Array(digest.prefix(16))

        let uuidTuple: uuid_t = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )

        return UUID(uuid: uuidTuple)
    }
}
