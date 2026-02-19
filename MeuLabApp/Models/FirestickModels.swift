import Foundation

// MARK: - Fire Stick

struct FirestickDevicesResponse: Codable, Equatable {
    let ok: Bool
    let devices: [FirestickDevice]
    let defaultId: String?

    enum CodingKeys: String, CodingKey {
        case ok, devices
        case defaultId = "default_id"
    }
}

struct FirestickDevice: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let ip: String
    let port: Int
    let serial: String?
}

struct FirestickStatusResponse: Codable, Equatable {
    let ok: Bool
    let timestamp: String
    let firestick: FirestickStatusPayload
}

struct FirestickStatusPayload: Codable, Equatable {
    let name: String
    let ip: String
    let port: Int
    let serial: String
    let tvOn: Bool?
    let tvShowingFirestick: Bool?
    let adb: FirestickAdb
    let foregroundApp: FirestickForegroundApp?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case name, ip, port, serial, adb, error
        case tvOn = "tv_on"
        case tvShowingFirestick = "tv_showing_firestick"
        case foregroundApp = "foreground_app"
    }
}

struct FirestickAdb: Codable, Equatable {
    let installed: Bool
    let deviceState: String?

    enum CodingKeys: String, CodingKey {
        case installed
        case deviceState = "device_state"
    }
}

struct FirestickForegroundApp: Codable, Equatable {
    let component: String?
    let package: String?
    let activity: String?
}

struct FirestickScreenshotKeyResponse: Codable, Equatable {
    let ok: Bool
    let id: String
    let name: String
    let serial: String
    let ttlSeconds: Int
    let url: String
    let publicUrl: String?

    enum CodingKeys: String, CodingKey {
        case ok, id, name, serial, url
        case ttlSeconds = "ttl_seconds"
        case publicUrl = "public_url"
    }
}

struct FirestickDeviceStatus: Identifiable, Equatable {
    let device: FirestickDevice
    let status: FirestickStatusResponse

    var id: String { device.id }
}

