import CoreLocation
import XCTest
@testable import MeuLabApp

final class RadarProcessingTests: XCTestCase {
    func testFiltersMatchOriginalAcrossCombinations() throws {
        let aircraft = try [
            makeTestAircraft(id: "civil", altitude: 0),
            makeTestAircraft(id: "cruise", altitude: 35000),
            makeTestAircraft(id: "military", altitude: 10000, callsign: "FAB123", model: "F16"),
            makeTestAircraft(id: "emergency", altitude: 25000, squawk: "7700"),
            makeTestAircraft(id: "no-position", lat: nil),
        ]
        for mask in 0..<8 {
            for query in ["", "test", "FAB", "7700", "a320", "civil", "TEST-REG", "missing"] {
                for (minimum, maximum) in [(0.0, 60000.0), (10000, 35000), (35000, 10000)] {
                    let filter = RadarAircraftFilter(searchText: query, minAltitude: minimum,
                        maxAltitude: maximum, showMilitary: mask & 1 != 0,
                        showEmergency: mask & 2 != 0, showCivil: mask & 4 != 0)
                    XCTAssertEqual(filter.apply(to: aircraft), originalFilter(aircraft, filter),
                                   "mask=\(mask), query=\(query), altitude=\(minimum)...\(maximum)")
                }
            }
        }
    }

    func testSnapshotCountsAndDuplicateIDLookup() throws {
        let aircraft = try [0, 9999, 10000, 24999, 25000, 34999, 35000].enumerated().map {
            try makeTestAircraft(id: String($0.offset), altitude: $0.element)
        }
        let snapshot = RadarAircraftSnapshot(aircraft: aircraft)
        XCTAssertEqual(snapshot.aircraft, aircraft)
        XCTAssertEqual(snapshot.altitudeDistribution.ground, 1.0 / 7, accuracy: 0.00001)
        XCTAssertEqual(snapshot.altitudeDistribution.low, 1.0 / 7, accuracy: 0.00001)
        XCTAssertEqual(snapshot.altitudeDistribution.med, 2.0 / 7, accuracy: 0.00001)
        XCTAssertEqual(snapshot.altitudeDistribution.high, 2.0 / 7, accuracy: 0.00001)
        XCTAssertEqual(snapshot.altitudeDistribution.cruise, 1.0 / 7, accuracy: 0.00001)
        let duplicate = try makeTestAircraft(id: "0", altitude: 40000)
        XCTAssertEqual(RadarAircraftSnapshot(aircraft: aircraft + [duplicate]).byID["0"], aircraft[0])
        XCTAssertEqual(RadarAircraftSnapshot(aircraft: []).altitudeDistribution.ground, 0)
    }

    func testStationaryTrailsReuseGeometryAndMovedTrailsReplaceOnlyTheirGeometry() throws {
        var history = RadarTrailHistory()
        XCTAssertTrue(history.update(aircraft: [try makeTestAircraft(id: "a"), try makeTestAircraft(id: "b")]))
        XCTAssertNil(history.trails["a"]?.polyline)
        let second = try [makeTestAircraft(id: "a", lat: 11), makeTestAircraft(id: "b", lat: 11)]
        XCTAssertTrue(history.update(aircraft: second))
        let originalA = try XCTUnwrap(history.trails["a"]?.polyline)
        let originalB = try XCTUnwrap(history.trails["b"]?.polyline)
        let ids = history.orderedIDs
        XCTAssertFalse(history.update(aircraft: second))
        XCTAssertTrue(history.trails["a"]?.polyline === originalA)
        XCTAssertEqual(history.orderedIDs, ids)
        // Altitude/color can change without rebuilding geometry.
        XCTAssertFalse(history.update(aircraft: [try makeTestAircraft(id: "a", lat: 11, altitude: 40000), second[1]]))
        XCTAssertTrue(history.trails["a"]?.polyline === originalA)
        XCTAssertTrue(history.update(aircraft: [try makeTestAircraft(id: "a", lat: 12), second[1]]))
        XCTAssertFalse(history.trails["a"]?.polyline === originalA)
        XCTAssertTrue(history.trails["b"]?.polyline === originalB)
        XCTAssertEqual(history.trails["a"]?.polyline?.pointCount, 3)
    }

    func testTrailHistoryMatchesOriginalAcrossUpdatesAndRemoval() throws {
        var history = RadarTrailHistory()
        var original: [String: [CLLocationCoordinate2D]] = [:]
        for tick in 0..<70 {
            var aircraft = try [makeTestAircraft(id: "moving", lat: 10 + Double(tick) / 100),
                                makeTestAircraft(id: "stationary")]
            if tick < 30 { aircraft.append(try makeTestAircraft(id: "leaves", lat: 30)) }
            if tick > 40 { aircraft.append(try makeTestAircraft(id: "arrives", lat: 40)) }
            _ = history.update(aircraft: aircraft)
            originalUpdateTrails(&original, aircraft)
            XCTAssertEqual(Set(history.trails.keys), Set(original.keys))
            for (id, coordinates) in original {
                XCTAssertEqual(history.trails[id]?.coordinates.map(\.latitude), coordinates.map(\.latitude))
                XCTAssertEqual(history.trails[id]?.coordinates.map(\.longitude), coordinates.map(\.longitude))
            }
        }
        XCTAssertEqual(history.trails["moving"]?.coordinates.count, 60)
        XCTAssertEqual(history.trails["stationary"]?.coordinates.count, 1)
        XCTAssertTrue(history.update(aircraft: []))
        XCTAssertTrue(history.trails.isEmpty)
        XCTAssertTrue(history.orderedIDs.isEmpty)
        XCTAssertFalse(history.update(aircraft: []))
    }

    func testHiddenTrailsKeepHeadingHistoryWithoutBuildingGeometry() throws {
        var history = RadarTrailHistory()
        XCTAssertTrue(history.update(aircraft: [try makeTestAircraft()], includeGeometry: false))
        XCTAssertTrue(history.update(aircraft: [try makeTestAircraft(lat: 11)], includeGeometry: false))
        XCTAssertEqual(history.trails["test-aircraft"]?.coordinates.count, 2)
        XCTAssertNil(history.trails["test-aircraft"]?.polyline)
        XCTAssertTrue(history.prepareGeometry())
        let polyline = try XCTUnwrap(history.trails["test-aircraft"]?.polyline)
        XCTAssertEqual(polyline.pointCount, 2)
        XCTAssertFalse(history.prepareGeometry())
        XCTAssertTrue(history.trails["test-aircraft"]?.polyline === polyline)
        // Movement while hidden invalidates geometry, but never loses heading points.
        XCTAssertTrue(history.update(aircraft: [try makeTestAircraft(lat: 12)], includeGeometry: false))
        XCTAssertNil(history.trails["test-aircraft"]?.polyline)
        XCTAssertEqual(history.trails["test-aircraft"]?.coordinates.count, 3)
        XCTAssertTrue(history.prepareGeometry())
        XCTAssertEqual(history.trails["test-aircraft"]?.polyline?.pointCount, 3)
    }

    func testLargeBatchReportsOneUpdateAndNoUpdateForSamePositions() throws {
        let aircraft = try (0..<500).map { try makeTestAircraft(id: String($0), lat: Double($0) / 10) }
        var history = RadarTrailHistory()
        var publications = 0
        if history.update(aircraft: aircraft) { publications += 1 }
        if history.update(aircraft: aircraft) { publications += 1 }
        XCTAssertEqual(publications, 1)
        XCTAssertEqual(history.trails.count, 500)
    }
}

// Frozen pre-refactor algorithms: equivalence oracle, independent of the new implementation.
private func originalFilter(_ aircraft: [Aircraft], _ filter: RadarAircraftFilter) -> [Aircraft] {
    var list = aircraft.filter { $0.hasPosition }
    if !filter.showMilitary { list = list.filter { !$0.isMilitary } }
    if !filter.showEmergency { list = list.filter { !$0.isEmergency } }
    if !filter.showCivil { list = list.filter { $0.isMilitary || $0.isEmergency } }
    if filter.minAltitude > 0 || filter.maxAltitude < 60_000 {
        list = list.filter { Double($0.altitudeFt) >= filter.minAltitude && Double($0.altitudeFt) <= filter.maxAltitude }
    }
    guard !filter.searchText.isEmpty else { return list }
    let query = filter.searchText.uppercased()
    return list.filter {
        $0.displayCallsign.uppercased().contains(query) || ($0.hex ?? "").uppercased().contains(query)
            || ($0.model ?? "").uppercased().contains(query)
            || ($0.registration ?? "").uppercased().contains(query)
            || ($0.squawk ?? "").contains(query)
    }
}

private func originalUpdateTrails(_ history: inout [String: [CLLocationCoordinate2D]], _ aircraft: [Aircraft]) {
    for aircraft in aircraft {
        guard let lat = aircraft.lat, let lon = aircraft.lon else { continue }
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        var points = history[aircraft.id] ?? []
        if let last = points.last, last.latitude == coordinate.latitude && last.longitude == coordinate.longitude { continue }
        points.append(coordinate)
        if points.count > 60 { points.removeFirst() }
        history[aircraft.id] = points
    }
    let ids = Set(aircraft.map(\.id))
    for key in history.keys where !ids.contains(key) { history.removeValue(forKey: key) }
}
