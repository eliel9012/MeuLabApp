import Observation
import SwiftUI
import XCTest
@testable import MeuLabApp

private final class ChangeCounter: @unchecked Sendable {
    var value = 0
}

final class AppStateObservationTests: XCTestCase {
    @MainActor
    func testRadioMutationDoesNotInvalidateAircraftObserver() throws {
        let state = AppState()
        let aircraftChanges = ChangeCounter()
        let radioChanges = ChangeCounter()
        withObservationTracking { _ = state.aircraftList } onChange: {
            aircraftChanges.value += 1
        }
        withObservationTracking { _ = state.nowPlaying } onChange: {
            radioChanges.value += 1
        }
        state.nowPlaying = try JSONDecoder().decode(NowPlaying.self, from: Data(#"{"title":"Fixture","artist":"Test","timestamp":"fixture","stream_url":"https://example.invalid","radio_name":"Test","has_itunes":false}"#.utf8))
        XCTAssertEqual(aircraftChanges.value, 0)
        XCTAssertEqual(radioChanges.value, 1)
    }

    @MainActor
    func testOperationalStateDoesNotRegisterObservation() {
        let state = AppState()
        let changes = ChangeCounter()
        withObservationTracking {
            _ = state.activeTabRawValue
            _ = state.radarBoundingBox
            _ = state.adsbLoading
            _ = state.radioLoading
            _ = state.tuyaSensorLoading
        } onChange: { changes.value += 1 }
        state.setActiveTab("radio")
        state.updateRadarBounds([2, 1, 4, 3])
        state.adsbLoading = true
        state.radioLoading = true
        state.tuyaSensorLoading = true
        XCTAssertEqual(changes.value, 0)
        XCTAssertEqual(state.activeTabRawValue, "radio")
        XCTAssertEqual(state.radarBoundingBox, [1, 2, 3, 4])
    }

    @MainActor
    func testAircraftMutationUpdatesObservedDerivedCaches() throws {
        let state = AppState()
        let changes = ChangeCounter()
        withObservationTracking { _ = state.adsbAirlines } onChange: {
            changes.value += 1
        }
        let aircraft = try makeTestAircraft()
        state.aircraftList = [aircraft]
        XCTAssertEqual(changes.value, 1)
        XCTAssertEqual(state.adsbAirlines.map(\.name), ["Test Airline"])
        XCTAssertEqual(state.adsbNearbyAircraftPreview.map(\.id), [aircraft.id])
        state.aircraftList = []
        XCTAssertTrue(state.adsbAirlines.isEmpty)
        XCTAssertTrue(state.adsbNearbyAircraftPreview.isEmpty)
    }

    @MainActor
    func testBindableSharesOpenSkyStateInBothDirections() {
        let state = AppState()
        @Bindable var first = state
        @Bindable var second = state
        let changes = ChangeCounter()
        withObservationTracking { _ = state.isOpenSkyEnabled } onChange: {
            changes.value += 1
        }
        $first.isOpenSkyEnabled.wrappedValue = true
        XCTAssertTrue(state.isOpenSkyEnabled)
        XCTAssertTrue($second.isOpenSkyEnabled.wrappedValue)
        XCTAssertEqual(changes.value, 1)
        $second.isOpenSkyEnabled.wrappedValue = false
        XCTAssertFalse($first.isOpenSkyEnabled.wrappedValue)
    }
}

func makeTestAircraft(id: String = "test-aircraft", lat: Double? = 10, lon: Double? = 20,
                      altitude: Int = 12000, squawk: String? = nil,
                      callsign: String = "TEST123", model: String = "A320") throws -> Aircraft {
    var json: [String: Any] = [
        "id": id, "hex": id, "callsign": callsign, "model": model,
        "airline": "Test Airline", "registration": "TEST-REG", "altitude_ft": altitude,
        "speed_kt": 200, "speed_kmh": 370, "distance_nm": 10, "vertical_rate_fpm": 0,
    ]
    if let lat { json["lat"] = lat }
    if let lon { json["lon"] = lon }
    if let squawk { json["squawk"] = squawk }
    return try JSONDecoder().decode(Aircraft.self, from: JSONSerialization.data(withJSONObject: json))
}
