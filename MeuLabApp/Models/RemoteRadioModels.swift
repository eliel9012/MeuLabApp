import Foundation

// MARK: - Remote Radio Models

/// Response from POST /api/remote-radio/session
struct RemoteRadioSession: Codable {
    let ok: Bool
    let sessionId: String
    let backend: String  // "rtl" | "fake"
    let rtlSerial: String?
    let locked: Bool
    let wsUrl: String
    let iceServers: [ICEServerConfig]?

    enum CodingKeys: String, CodingKey {
        case ok
        case sessionId = "sessionId"
        case backend
        case rtlSerial = "rtlSerial"
        case locked
        case wsUrl = "wsUrl"
        case iceServers = "iceServers"
    }
}

struct ICEServerConfig: Codable {
    let urls: ICEURLs
    let username: String?
    let credential: String?

    enum ICEURLs: Codable {
        case single(String)
        case multiple([String])

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let single = try? container.decode(String.self) {
                self = .single(single)
            } else if let multiple = try? container.decode([String].self) {
                self = .multiple(multiple)
            } else {
                self = .single("stun:stun.l.google.com:19302")
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .single(let url): try container.encode(url)
            case .multiple(let urls): try container.encode(urls)
            }
        }

        var allURLs: [String] {
            switch self {
            case .single(let url): return [url]
            case .multiple(let urls): return urls
            }
        }
    }
}

/// Response from POST /api/remote-radio/session/{id}/offer
struct RemoteRadioAnswer: Codable {
    let ok: Bool
    let answer: SDPPayload
}

struct SDPPayload: Codable {
    let type: String  // "offer" or "answer"
    let sdp: String
}

/// Body for POST /api/remote-radio/session/{id}/tune
struct TuneRequest: Codable {
    let freqHz: Int
    let mode: String  // "AM", "NFM", "WFM"
    let gain: GainValue
    let squelch: Int

    enum GainValue: Codable {
        case auto
        case manual(Double)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let str = try? container.decode(String.self), str == "auto" {
                self = .auto
            } else if let val = try? container.decode(Double.self) {
                self = .manual(val)
            } else {
                self = .auto
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .auto: try container.encode("auto")
            case .manual(let val): try container.encode(val)
            }
        }
    }
}

/// Unified status — used for both service-level GET /status and session-level status in WS events.
/// The server may return `"status"` as either a plain string (WS events) or a nested
/// JSON object (GET /api/remote-radio/status when backend is openwebrx).
/// A custom decoder handles both shapes without throwing.
struct RemoteRadioStatus: Codable {
    // Service-level fields (GET /api/remote-radio/status)
    let ok: Bool?
    let enabled: Bool?
    let backend: String?
    let rtlSerial: String?
    let locked: Bool?
    let donglePresent: Bool?
    let webrtcAvailable: Bool?
    let webrtcImportError: String?
    let activeSessionId: String?

    // Session-level fields (WS state_changed events)
    let sessionId: String?
    let state: String?
    let status: String?
    let running: Bool?
    let freqHz: Int?
    let mode: String?
    let gain: AnyCodableGain?
    let squelch: Int?
    let signal: Double?
    let audioLevel: Double?
    let webrtcState: String?
    let createdAt: String?
    let startedAt: String?
    let lastTuneAt: String?

    // Nested OpenWebRX status (when backend == "openwebrx")
    let openwebrxEnabled: Bool?
    let audioWavUrl: String?
    let audioPcmWsUrl: String?

    enum CodingKeys: String, CodingKey {
        case ok, enabled, backend, rtlSerial, locked, donglePresent
        case webrtcAvailable, webrtcImportError, activeSessionId
        case sessionId, state, status, running, freqHz, mode, gain
        case squelch, signal, audioLevel, webrtcState
        case createdAt, startedAt, lastTuneAt
        case audioWavUrl, audioPcmWsUrl
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        ok = try c.decodeIfPresent(Bool.self, forKey: .ok)
        backend = try c.decodeIfPresent(String.self, forKey: .backend)
        rtlSerial = try c.decodeIfPresent(String.self, forKey: .rtlSerial)
        locked = try c.decodeIfPresent(Bool.self, forKey: .locked)
        donglePresent = try c.decodeIfPresent(Bool.self, forKey: .donglePresent)
        webrtcAvailable = try c.decodeIfPresent(Bool.self, forKey: .webrtcAvailable)
        webrtcImportError = try c.decodeIfPresent(String.self, forKey: .webrtcImportError)
        activeSessionId = try c.decodeIfPresent(String.self, forKey: .activeSessionId)
        sessionId = try c.decodeIfPresent(String.self, forKey: .sessionId)
        state = try c.decodeIfPresent(String.self, forKey: .state)
        running = try c.decodeIfPresent(Bool.self, forKey: .running)
        freqHz = try c.decodeIfPresent(Int.self, forKey: .freqHz)
        mode = try c.decodeIfPresent(String.self, forKey: .mode)
        gain = try c.decodeIfPresent(AnyCodableGain.self, forKey: .gain)
        squelch = try c.decodeIfPresent(Int.self, forKey: .squelch)
        signal = try c.decodeIfPresent(Double.self, forKey: .signal)
        audioLevel = try c.decodeIfPresent(Double.self, forKey: .audioLevel)
        webrtcState = try c.decodeIfPresent(String.self, forKey: .webrtcState)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        startedAt = try c.decodeIfPresent(String.self, forKey: .startedAt)
        lastTuneAt = try c.decodeIfPresent(String.self, forKey: .lastTuneAt)
        audioWavUrl = try c.decodeIfPresent(String.self, forKey: .audioWavUrl)
        audioPcmWsUrl = try c.decodeIfPresent(String.self, forKey: .audioPcmWsUrl)

        // "status" can be a String (WS events) or a nested Object (openwebrx status).
        // Try String first; if that fails, try decoding as the nested object to extract "enabled".
        if let str = try? c.decodeIfPresent(String.self, forKey: .status) {
            status = str
            // Top-level enabled takes priority; if absent, fallback will be set below
            enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled)
            openwebrxEnabled = nil
        } else if let nested = try? c.decodeIfPresent(NestedOpenWebRXStatus.self, forKey: .status) {
            status = nil
            enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? nested.enabled
            openwebrxEnabled = nested.enabled
        } else {
            status = nil
            enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled)
            openwebrxEnabled = nil
        }
    }

    /// Internal type for parsing the nested `"status": { "enabled": true, ... }` object
    private struct NestedOpenWebRXStatus: Codable {
        let ok: Bool?
        let enabled: Bool?
        let connected: Bool?
    }
}

/// Flexible gain decoding — server sends either "auto" (String) or a Double
enum AnyCodableGain: Codable {
    case auto
    case manual(Double)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if (try? container.decode(String.self)) != nil {
            self = .auto
        } else if let val = try? container.decode(Double.self) {
            self = .manual(val)
        } else {
            self = .auto
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .auto: try container.encode("auto")
        case .manual(let val): try container.encode(val)
        }
    }

    var displayString: String {
        switch self {
        case .auto: return "Auto"
        case .manual(let val): return String(format: "%.1f dB", val)
        }
    }
}

/// Generic OK response
struct RemoteRadioOKResponse: Codable {
    let ok: Bool
    let message: String?
    let error: String?
    let code: String?
}

/// OpenWebRX status response
struct OpenWebRXStatusResponse: Codable {
    let ok: Bool?
    let connected: Bool?
    let sdrProfile: String?
    let frequency: Int?
    let modulation: String?

    enum CodingKeys: String, CodingKey {
        case ok, connected, frequency, modulation
        case sdrProfile = "sdr_profile"
    }
}

/// WebSocket message from server
struct WSMessage: Codable {
    let type: String  // "pong", "event", "error"
    let event: String?  // "state_changed", "webrtc_state"
    let value: String?
    let status: RemoteRadioStatus?
    let code: String?
    let message: String?
}

// MARK: - Radio Mode

enum RadioMode: String, CaseIterable, Identifiable {
    case am = "AM"
    case nfm = "NFM"
    case wfm = "WFM"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .am: return "AM"
        case .nfm: return "NFM"
        case .wfm: return "WFM"
        }
    }
}

// MARK: - Radio Preset

struct RadioPreset: Identifiable {
    let id = UUID()
    let name: String
    let freqHz: Int
    let mode: RadioMode
    let icon: String

    var freqMHz: Double {
        Double(freqHz) / 1_000_000.0
    }
}

extension RadioPreset {
    static let presets: [RadioPreset] = [
        RadioPreset(name: "Aviação", freqHz: 118_300_000, mode: .am, icon: "airplane"),
        RadioPreset(name: "NOAA WX", freqHz: 162_550_000, mode: .nfm, icon: "cloud.sun"),
        RadioPreset(name: "FM 99.5", freqHz: 99_500_000, mode: .wfm, icon: "radio"),
        RadioPreset(
            name: "Torre TWR", freqHz: 121_500_000, mode: .am,
            icon: "antenna.radiowaves.left.and.right"),
        RadioPreset(name: "Bombeiros", freqHz: 154_000_000, mode: .nfm, icon: "flame"),
        RadioPreset(name: "FM 93.3", freqHz: 93_300_000, mode: .wfm, icon: "music.note"),
    ]
}

// MARK: - Connection State

enum RemoteRadioConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case running
    case error(String)

    var displayText: String {
        switch self {
        case .disconnected: return "Desconectado"
        case .connecting: return "Conectando…"
        case .connected: return "Conectado"
        case .running: return "No Ar"
        case .error(let msg): return "Erro: \(msg)"
        }
    }

    var color: String {
        switch self {
        case .disconnected: return "gray"
        case .connecting: return "orange"
        case .connected: return "green"
        case .running: return "red"
        case .error: return "red"
        }
    }

    var isConnected: Bool {
        switch self {
        case .connected, .running: return true
        default: return false
        }
    }
}
