//
// TestConstants.swift
// oliviaTests
//
//
// Olivia is a Decentralised Permissionless Communication Network.
// Licensed under the MIT License - see LICENSE file for details
//
import Foundation
@testable import olivia

struct TestConstants {
    static let defaultTimeout: TimeInterval = 5.0
    static let shortTimeout: TimeInterval = 1.0
    static let longTimeout: TimeInterval = 10.0
    
    static let testPeerID1: PeerID = "PEER1234"
    static let testPeerID2: PeerID = "PEER5678"
    static let testPeerID3: PeerID = "PEER9012"
    static let testPeerID4: PeerID = "PEER3456"
    
    static let testNickname1 = "Alice"
    static let testNickname2 = "Bob"
    static let testNickname3 = "Charlie"
    static let testNickname4 = "David"
    
    static let testMessage1 = "Hello, World!"
    static let testMessage2 = "How are you?"
    static let testMessage3 = "This is a test message"
    static let testLongMessage = String(repeating: "This is a long message. ", count: 100)
    
    static let testSignature = Data(repeating: 0xAB, count: 64)
}
