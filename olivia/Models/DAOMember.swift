import Foundation
import SolanaSwift

// MARK: - DAO Member Model

struct DAOMember: Codable, Identifiable, Equatable {
    let id = UUID()
    let walletAddress: String
    let nickname: String
    let noisePublicKey: Data
    let reputation: UInt64
    let joinedAt: Int64
    let isActive: Bool
    
    init(walletAddress: String, nickname: String, noisePublicKey: Data, reputation: UInt64, joinedAt: Int64 = Int64(Date().timeIntervalSince1970), isActive: Bool = true) {
        self.walletAddress = walletAddress
        self.nickname = nickname
        self.noisePublicKey = noisePublicKey
        self.reputation = reputation
        self.joinedAt = joinedAt
        self.isActive = isActive
    }
    
    // For compatibility with existing code
    init(walletAddress: String, nickname: String, noisePublicKey: Data, reputation: UInt64) {
        self.init(walletAddress: walletAddress, nickname: nickname, noisePublicKey: noisePublicKey, reputation: reputation, joinedAt: Int64(Date().timeIntervalSince1970), isActive: true)
    }
    
    static let accountSize: UInt64 = 8 + 32 + 32 + 32 + 8 + 8 + 1 // Discriminator + wallet + nickname + noise_key + reputation + joined_at + is_active
    
    /// Deserialize DAOMember from Solana+Nostr+Noise account data
    static func deserialize(data: Data) throws -> DAOMember {
        guard data.count >= accountSize else {
            throw DeserializationError.insufficientData
        }
        
        var offset = 8 // Skip discriminator
        
        // Read wallet address (32 bytes)
        let walletData = data.subdata(in: offset..<offset+32)
        let walletAddress = try PublicKey(data: walletData).base58EncodedString
        offset += 32
        
        // Read nickname (32 bytes, null-terminated)
        let nicknameData = data.subdata(in: offset..<offset+32)
        let nickname = String(data: nicknameData.prefix(while: { $0 != 0 }), encoding: .utf8) ?? ""
        offset += 32
        
        // Read noise public key (32 bytes)
        let noisePublicKey = data.subdata(in: offset..<offset+32)
        offset += 32
        
        // Read reputation (8 bytes)
        let reputation = data.subdata(in: offset..<offset+8).withUnsafeBytes { $0.load(as: UInt64.self) }
        offset += 8
        
        // Read joined_at (8 bytes)
        let joinedAt = data.subdata(in: offset..<offset+8).withUnsafeBytes { $0.load(as: Int64.self) }
        offset += 8
        
        // Read is_active (1 byte)
        let isActive = data[offset] != 0
        
        return DAOMember(
            walletAddress: walletAddress,
            nickname: nickname,
            noisePublicKey: noisePublicKey,
            reputation: reputation,
            joinedAt: joinedAt,
            isActive: isActive
        )
    }
    
    enum DeserializationError: Error {
        case insufficientData
        case invalidData
    }
}

// MARK: - Extensions for Data Encoding

extension UInt32 {
    var littleEndianData: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<UInt32>.size)
    }
}

extension UInt64 {
    var littleEndianData: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<UInt64>.size)
    }
}

extension Int64 {
    var littleEndianData: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<Int64>.size)
    }
}
