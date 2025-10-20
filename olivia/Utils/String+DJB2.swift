//
// String+DJB2.swift
// olivia
//
//
// This file is part of OLIVIA Communication Network
// Licensed under the MIT License - see LICENSE file for details
//
import Foundation

extension String {
    func djb2() -> UInt64 {
        var hash: UInt64 = 5381
        for b in utf8 { hash = ((hash << 5) &+ hash) &+ UInt64(b) }
        return hash
    }
}
