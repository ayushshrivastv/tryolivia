//
// String+Nickname.swift
// olivia
//
//
// Olivia is a Decentralised Permissionless Communication Network.
// Licensed under the MIT License - see LICENSE file for details
//
import Foundation

extension String {
    /// Split a nickname into base and a '#abcd' suffix if present
    func splitSuffix() -> (String, String) {
        let name = self.replacingOccurrences(of: "@", with: "")
        guard name.count >= 5 else { return (name, "") }
        let suffix = String(name.suffix(5))
        if suffix.first == "#", suffix.dropFirst().allSatisfy({ c in
            ("0"..."9").contains(String(c)) || ("a"..."f").contains(String(c)) || ("A"..."F").contains(String(c))
        }) {
            let base = String(name.dropLast(5))
            return (base, suffix)
        }
        return (name, "")
    }
}
