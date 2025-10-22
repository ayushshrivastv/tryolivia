import Foundation

// MARK: - DAO Vote Type

struct DAOVote: Codable {
    let id: String
    let proposalId: UInt64
    let voter: String
    let vote: VoteChoice
    let votingPower: Int
    let timestamp: Date
    let signature: String?
    
    enum VoteChoice: String, Codable {
        case yes = "yes"
        case no = "no"
        case abstain = "abstain"
    }
    
    func encode() -> Data? {
        return try? JSONEncoder().encode(self)
    }
    
    static func decode(_ data: Data) -> DAOVote? {
        return try? JSONDecoder().decode(DAOVote.self, from: data)
    }
}

// MARK: - Extensions for existing DAO types

extension DAOProposal {
    func encode() -> Data? {
        // Manual encoding since DAOProposal may not be Codable
        let dict: [String: Any] = [
            "id": id,
            "title": title,
            "description": description,
            "proposer": proposer,
            "type": type.rawValue,
            "votesFor": votesFor,
            "votesAgainst": votesAgainst,
            "createdAt": createdAt.timeIntervalSince1970,
            "votingEndsAt": votingEndsAt.timeIntervalSince1970,
            "executed": executed,
            "cancelled": cancelled
        ]
        return try? JSONSerialization.data(withJSONObject: dict)
    }
    
    static func decode(_ data: Data) -> DAOProposal? {
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = dict["id"] as? UInt64,
              let title = dict["title"] as? String,
              let description = dict["description"] as? String,
              let proposer = dict["proposer"] as? String,
              let typeRaw = dict["type"] as? UInt8,
              let type = ProposalType(rawValue: typeRaw),
              let votesFor = dict["votesFor"] as? UInt64,
              let votesAgainst = dict["votesAgainst"] as? UInt64,
              let createdAtInterval = dict["createdAt"] as? TimeInterval,
              let votingEndsAtInterval = dict["votingEndsAt"] as? TimeInterval,
              let executed = dict["executed"] as? Bool,
              let cancelled = dict["cancelled"] as? Bool else {
            return nil
        }
        
        return DAOProposal(
            id: id,
            title: title,
            description: description,
            proposer: proposer,
            type: type,
            votesFor: votesFor,
            votesAgainst: votesAgainst,
            createdAt: Date(timeIntervalSince1970: createdAtInterval),
            votingEndsAt: Date(timeIntervalSince1970: votingEndsAtInterval),
            executed: executed,
            cancelled: cancelled
        )
    }
}
