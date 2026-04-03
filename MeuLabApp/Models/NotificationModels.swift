import Foundation

struct NotificationFeedResponse: Codable, Equatable {
    let timestamp: String
    let latestId: Int
    let events: [NotificationEvent]

    enum CodingKeys: String, CodingKey {
        case timestamp
        case latestId = "latest_id"
        case events
    }
}

struct NotificationRegisterResponse: Codable, Equatable {
    let status: String
    let tokenPrefix: String?

    enum CodingKeys: String, CodingKey {
        case status
        case tokenPrefix = "token_prefix"
    }
}

struct NotificationUnregisterResponse: Codable, Equatable {
    let status: String
}

struct NotificationListResponse: Codable, Equatable {
    let timestamp: String
    let pushStats: [String: AnyCodable]?
    let notifications: [AnyCodable]

    enum CodingKeys: String, CodingKey {
        case timestamp
        case pushStats = "push_stats"
        case notifications
    }
}

struct NotificationAckResponse: Codable, Equatable {
    let timestamp: String
    let updated: Int
}

struct NotificationEvent: Codable, Equatable, Identifiable {
    let id: Int
    let category: String
    let title: String
    let body: String
    let data: [String: AnyCodable]?
    let createdAt: String
    let deliveredAt: String?

    enum CodingKeys: String, CodingKey {
        case id, category, title, body, data
        case createdAt = "created_at"
        case deliveredAt = "delivered_at"
    }
}

// MARK: - AnyCodable (minimal)

struct AnyCodable: Codable, Equatable, @unchecked Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue
        } else {
            value = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let arrayValue as [AnyCodable]:
            try container.encode(arrayValue)
        case let dictValue as [String: AnyCodable]:
            try container.encode(dictValue)
        default:
            try container.encodeNil()
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case let (l as Int, r as Int):
            return l == r
        case let (l as Double, r as Double):
            return l == r
        case let (l as Bool, r as Bool):
            return l == r
        case let (l as String, r as String):
            return l == r
        case (is NSNull, is NSNull):
            return true
        case let (l as [AnyCodable], r as [AnyCodable]):
            return l == r
        case let (l as [String: AnyCodable], r as [String: AnyCodable]):
            return l == r
        case let (l as Float, r as Float):
            return l == r
        case let (l as Int8, r as Int8):
            return l == r
        case let (l as Int16, r as Int16):
            return l == r
        case let (l as Int32, r as Int32):
            return l == r
        case let (l as Int64, r as Int64):
            return l == r
        case let (l as UInt, r as UInt):
            return l == r
        case let (l as UInt8, r as UInt8):
            return l == r
        case let (l as UInt16, r as UInt16):
            return l == r
        case let (l as UInt32, r as UInt32):
            return l == r
        case let (l as UInt64, r as UInt64):
            return l == r
        default:
            return false
        }
    }
}
