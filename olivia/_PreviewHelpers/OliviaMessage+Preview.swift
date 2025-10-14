//
// OliviaMessage+Preview.swift
// olivia
//
//
// This file is part of OLIVIA Emergency Communication Network
// Licensed under the MIT License - see LICENSE file for details
//
import Foundation

extension OliviaMessage {
    static var preview: OliviaMessage {
        OliviaMessage(
            id: UUID().uuidString,
            sender: "John Doe",
            content: "Hello",
            timestamp: Date(),
            isRelay: false,
            originalSender: nil,
            isPrivate: false,
            recipientNickname: "Jane Doe",
            senderPeerID: nil,
            mentions: nil,
            deliveryStatus: .sent
        )
    }
}
