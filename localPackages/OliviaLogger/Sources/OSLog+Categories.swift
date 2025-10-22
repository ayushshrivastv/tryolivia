//
// OSLog+Categories.swift
// OliviaLogger
//
//
// Olivia is a Decentralised Permissionless Communication Network.
// Licensed under the MIT License - see LICENSE file for details
//
import os.log

public extension OSLog {
    private static let subsystem = "chat.olivia"
    
    static let noise        = OSLog(subsystem: subsystem, category: "noise")
    static let encryption   = OSLog(subsystem: subsystem, category: "encryption")
    static let keychain     = OSLog(subsystem: subsystem, category: "keychain")
    static let session      = OSLog(subsystem: subsystem, category: "session")
    static let security     = OSLog(subsystem: subsystem, category: "security")
    static let handshake    = OSLog(subsystem: subsystem, category: "handshake")
}
