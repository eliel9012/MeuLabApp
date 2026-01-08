import Foundation

// MARK: - ACARS Summary

struct ACARSSummary: Codable, Equatable {
    let timestamp: String
    let today: ACARSDayStats
    let last24h: ACARSPeriodStats
    let lastHour: Int
    let topAircraft: [ACARSTopAircraft]
    let topLabels: [ACARSTopLabel]

    enum CodingKeys: String, CodingKey {
        case timestamp
        case today
        case last24h = "last_24h"
        case lastHour = "last_hour"
        case topAircraft = "top_aircraft"
        case topLabels = "top_labels"
    }
}

struct ACARSDayStats: Codable, Equatable {
    let messages: Int
    let flights: Int
    let aircraft: Int
    let peakHour: String?
    let peakCount: Int

    enum CodingKeys: String, CodingKey {
        case messages, flights, aircraft
        case peakHour = "peak_hour"
        case peakCount = "peak_count"
    }
}

struct ACARSPeriodStats: Codable, Equatable {
    let messages: Int
    let flights: Int
    let aircraft: Int
}

struct ACARSTopAircraft: Codable, Equatable, Identifiable {
    let tail: String
    let flight: String
    let count: Int

    var id: String { tail }
}

struct ACARSTopLabel: Codable, Equatable, Identifiable {
    let label: String
    let description: String
    let count: Int

    var id: String { label }
}

// MARK: - ACARS Messages

struct ACARSMessageList: Codable {
    let timestamp: String
    let count: Int
    let messages: [ACARSMessage]
}

struct ACARSMessage: Codable, Identifiable, Equatable {
    let id: Int
    let flight: String?
    let tail: String?
    let label: String?
    let labelDesc: String?
    let departure: String?
    let destination: String?
    let text: String?
    let time: String
    let timestamp: Int

    enum CodingKeys: String, CodingKey {
        case id, flight, tail, label
        case labelDesc = "label_desc"
        case departure, destination, text, time, timestamp
    }

    var displayFlight: String {
        flight ?? tail ?? "???"
    }

    var displayRoute: String? {
        guard departure != nil || destination != nil else { return nil }
        let dep = departure ?? "???"
        let dst = destination ?? "???"
        return "\(dep) → \(dst)"
    }

    var labelIcon: String {
        switch label {
        case "H1": return "location.fill"
        case "SA": return "building.2"
        case "B9", "5U": return "cloud.sun"
        case "80": return "antenna.radiowaves.left.and.right"
        case "BA": return "clock"
        case "QQ", "Q0", "Q1", "Q2", "Q3": return "door.left.hand.open"
        case "44": return "mappin.and.ellipse"
        case "15": return "scalemass"
        case "49": return "fuelpump"
        default: return "doc.text"
        }
    }

    var labelColor: String {
        switch label {
        case "QQ", "Q0", "Q1", "Q2", "Q3": return "green"
        case "80": return "purple"
        case "BA": return "orange"
        case "H1", "44": return "blue"
        default: return "gray"
        }
    }
}

// MARK: - ACARS Hourly Stats

struct ACARSHourlyStats: Codable {
    let timestamp: String
    let hours: [ACARSHourStat]
}

struct ACARSHourStat: Codable, Identifiable, Equatable {
    let hour: String
    let messages: Int
    let flights: Int

    var id: String { hour }
}

// MARK: - ACARS Search

struct ACARSSearchResult: Codable {
    let timestamp: String
    let query: String
    let count: Int
    let messages: [ACARSMessage]
}
