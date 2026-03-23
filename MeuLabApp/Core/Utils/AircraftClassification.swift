import Foundation

// MARK: - Military & Emergency Detection

enum AircraftClassification {
    /// Military callsign prefixes (Brazilian + NATO)
    private static let militaryPrefixes: Set<String> = [
        // Força Aérea Brasileira
        "FAB", "BRS", "FFAB", "PAT", "CBJ", "PBM", "CPB",
        // Marinha do Brasil
        "NAE", "NAV", "MAR",
        // US Military
        "RCH", "EVAC", "REACH", "CNV", "DUKE", "KING", "JAKE",
        "TOPCAT", "MMF", "USAF", "USN", "USMC",
        // NATO / Others
        "BAF", "GAF", "RRR",
    ]

    /// Emergency squawk codes
    private static let emergencySquawks: Set<String> = [
        "7500",  // Hijacking
        "7600",  // Radio failure
        "7700",  // General emergency
    ]

    /// Check if callsign matches a military prefix
    static func isMilitary(callsign: String?) -> Bool {
        guard let cs = callsign?.trimmingCharacters(in: .whitespaces).uppercased(),
            !cs.isEmpty
        else { return false }

        let maxPrefixLen = min(4, cs.count)
        guard maxPrefixLen >= 2 else { return false }

        for len in 2...maxPrefixLen {
            let prefix = String(cs.prefix(len))
            if militaryPrefixes.contains(prefix) { return true }
        }
        return false
    }

    /// Check if hex ICAO address falls in known military ranges
    static func isMilitaryHex(_ hex: String?) -> Bool {
        // Currently no hex ranges defined (MIL_HEX was empty in original JS).
        // If ranges are needed in the future, add them here.
        return false
    }

    /// True if the squawk indicates an emergency
    static func isEmergency(squawk: String?) -> Bool {
        guard let sq = squawk else { return false }
        return emergencySquawks.contains(sq)
    }

    /// Human-readable emergency description
    static func emergencyDescription(squawk: String?) -> String? {
        switch squawk {
        case "7500": return "HIJACK"
        case "7600": return "NORDO"
        case "7700": return "EMERGÊNCIA"
        default: return nil
        }
    }
}

// MARK: - Aircraft convenience

extension Aircraft {
    var isMilitary: Bool {
        AircraftClassification.isMilitary(callsign: callsign)
            || AircraftClassification.isMilitaryHex(hex)
    }

    var isEmergency: Bool {
        AircraftClassification.isEmergency(squawk: squawk)
    }

    var emergencyLabel: String? {
        AircraftClassification.emergencyDescription(squawk: squawk)
    }
}
