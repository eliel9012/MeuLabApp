import Foundation
import AVFoundation

// MARK: - Abstract types for cross-compilation

/// Lightweight ICE candidate info that works with or without WebRTC framework
struct ICECandidateInfo {
    let sdp: String
    let sdpMid: String
    let sdpMLineIndex: Int
}

// MARK: - WebRTC Client

#if canImport(WebRTC)
import WebRTC

final class RemoteRadioWebRTCClient: NSObject {

    // MARK: - Callbacks (abstract types – no RTC specifics leak out)

    var onICECandidate: ((ICECandidateInfo) -> Void)?
    var onConnectionStateChanged: ((String) -> Void)?
    var onAudioTrackReceived: (() -> Void)?

    // MARK: - Private

    private var peerConnectionFactory: RTCPeerConnectionFactory?
    private var peerConnection: RTCPeerConnection?

    // MARK: - Setup

    func setup(iceServers: [ICEServerConfig]) {
        RTCInitializeSSL()

        let decoderFactory = RTCDefaultVideoDecoderFactory()
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        let factory = RTCPeerConnectionFactory(
            encoderFactory: encoderFactory,
            decoderFactory: decoderFactory
        )
        peerConnectionFactory = factory

        let rtcIceServers = iceServers.map { config -> RTCIceServer in
            RTCIceServer(urlStrings: config.urls.allURLs)
        }

        let rtcConfig = RTCConfiguration()
        rtcConfig.iceServers = rtcIceServers
        rtcConfig.sdpSemantics = .unifiedPlan
        rtcConfig.continualGatheringPolicy = .gatherContinually

        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: nil
        )

        peerConnection = factory.peerConnection(
            with: rtcConfig,
            constraints: constraints,
            delegate: self
        )

        // Add audio-only recvonly transceiver
        let audioTransceiverInit = RTCRtpTransceiverInit()
        audioTransceiverInit.direction = .recvOnly
        peerConnection?.addTransceiver(of: .audio, init: audioTransceiverInit)
    }

    // MARK: - SDP Exchange

    func createOffer() async throws -> String {
        guard let pc = peerConnection else {
            throw RemoteRadioError.webrtcFailed("Peer connection not initialized")
        }

        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "true",
                "OfferToReceiveVideo": "false"
            ],
            optionalConstraints: nil
        )

        return try await withCheckedThrowingContinuation { continuation in
            pc.offer(for: constraints) { sdp, error in
                if let error {
                    continuation.resume(throwing: RemoteRadioError.webrtcFailed(error.localizedDescription))
                    return
                }
                guard let sdp else {
                    continuation.resume(throwing: RemoteRadioError.webrtcFailed("No SDP in offer"))
                    return
                }
                pc.setLocalDescription(sdp) { error in
                    if let error {
                        continuation.resume(throwing: RemoteRadioError.webrtcFailed(error.localizedDescription))
                    } else {
                        continuation.resume(returning: sdp.sdp)
                    }
                }
            }
        }
    }

    func setRemoteAnswer(sdp: String) async throws {
        guard let pc = peerConnection else {
            throw RemoteRadioError.webrtcFailed("Peer connection not initialized")
        }

        let remoteSDP = RTCSessionDescription(type: .answer, sdp: sdp)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            pc.setRemoteDescription(remoteSDP) { error in
                if let error {
                    continuation.resume(throwing: RemoteRadioError.webrtcFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func addRemoteICECandidate(sdp: String, sdpMid: String, sdpMLineIndex: Int) async throws {
        guard let pc = peerConnection else {
            throw RemoteRadioError.webrtcFailed("Peer connection not initialized")
        }

        let candidate = RTCIceCandidate(sdp: sdp, sdpMLineIndex: Int32(sdpMLineIndex), sdpMid: sdpMid)
        pc.add(candidate)
    }

    // MARK: - Audio

    func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playback, mode: .default, options: [])
        try? audioSession.setActive(true)
    }

    // MARK: - Teardown

    func disconnect() {
        peerConnection?.close()
        peerConnection = nil
        peerConnectionFactory = nil
        onICECandidate = nil
        onConnectionStateChanged = nil
        onAudioTrackReceived = nil
    }
}

// MARK: - RTCPeerConnectionDelegate

extension RemoteRadioWebRTCClient: RTCPeerConnectionDelegate {

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        if !stream.audioTracks.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.onAudioTrackReceived?()
            }
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}

    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        let stateString: String
        switch newState {
        case .new:        stateString = "new"
        case .checking:   stateString = "checking"
        case .connected:  stateString = "connected"
        case .completed:  stateString = "completed"
        case .failed:     stateString = "failed"
        case .disconnected: stateString = "disconnected"
        case .closed:     stateString = "closed"
        case .count:      stateString = "unknown"
        @unknown default: stateString = "unknown"
        }
        DispatchQueue.main.async { [weak self] in
            self?.onConnectionStateChanged?(stateString)
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        let info = ICECandidateInfo(
            sdp: candidate.sdp,
            sdpMid: candidate.sdpMid ?? "0",
            sdpMLineIndex: Int(candidate.sdpMLineIndex)
        )
        DispatchQueue.main.async { [weak self] in
            self?.onICECandidate?(info)
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}

#else

// MARK: - Stub (no WebRTC framework)

final class RemoteRadioWebRTCClient {

    var onICECandidate: ((ICECandidateInfo) -> Void)?
    var onConnectionStateChanged: ((String) -> Void)?
    var onAudioTrackReceived: (() -> Void)?

    func setup(iceServers: [ICEServerConfig]) {
        // No-op without WebRTC
    }

    func createOffer() async throws -> String {
        throw RemoteRadioError.webrtcFailed(
            "WebRTC framework not available. Add the WebRTC SPM package to enable audio streaming."
        )
    }

    func setRemoteAnswer(sdp: String) async throws {
        throw RemoteRadioError.webrtcFailed(
            "WebRTC framework not available."
        )
    }

    func addRemoteICECandidate(sdp: String, sdpMid: String, sdpMLineIndex: Int) async throws {
        throw RemoteRadioError.webrtcFailed(
            "WebRTC framework not available."
        )
    }

    func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playback, mode: .default, options: [])
        try? audioSession.setActive(true)
    }

    func disconnect() {
        onICECandidate = nil
        onConnectionStateChanged = nil
        onAudioTrackReceived = nil
    }
}

#endif
