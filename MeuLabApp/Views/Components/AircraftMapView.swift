import SwiftUI
import MapKit

struct AircraftMapView: View {
    let aircraft: [Aircraft]
    let receiverLocation: CLLocationCoordinate2D

    @State private var position: MapCameraPosition
    @State private var selectedAircraftID: Aircraft.ID?

    init(aircraft: [Aircraft], receiverLat: Double = -20.512504, receiverLon: Double = -47.400830) {
        self.aircraft = aircraft
        self.receiverLocation = CLLocationCoordinate2D(latitude: receiverLat, longitude: receiverLon)
        // Center on receiver with 200nm radius view
        self._position = State(initialValue: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: receiverLat, longitude: receiverLon),
            span: MKCoordinateSpan(latitudeDelta: 4.0, longitudeDelta: 4.0)
        )))
    }

    var body: some View {
        Map(position: $position, selection: $selectedAircraftID) {
            // Receiver location (your station)
            Annotation("Receptor", coordinate: receiverLocation) {
                ZStack {
                    Circle()
                        .fill(.blue.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Circle()
                        .fill(.blue)
                        .frame(width: 12, height: 12)
                    Circle()
                        .stroke(.white, lineWidth: 2)
                        .frame(width: 12, height: 12)
                }
            }

            // Range rings (50nm, 100nm, 150nm, 200nm)
            ForEach([50, 100, 150, 200], id: \.self) { rangeNm in
                MapCircle(center: receiverLocation, radius: CLLocationDistance(rangeNm) * 1852)
                    .stroke(.blue.opacity(0.3), lineWidth: 1)
            }

            // Aircraft markers
            ForEach(aircraftWithPosition) { ac in
                if let coord = ac.coordinate {
                    Annotation(ac.displayCallsign, coordinate: coord) {
                        AircraftMarker(aircraft: ac, isSelected: selectedAircraftID == ac.id)
                    }
                    .tag(ac.id)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapCompass()
            MapScaleView()
            MapUserLocationButton()
        }
        .overlay(alignment: .bottom) {
            if let selectedID = selectedAircraftID, let selected = aircraftWithPosition.first(where: { $0.id == selectedID }) {
                AircraftInfoCard(aircraft: selected)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: selectedAircraftID)
    }

    private var aircraftWithPosition: [Aircraft] {
        aircraft.filter { $0.hasPosition }
    }
}

// MARK: - Aircraft Coordinate Extension

extension Aircraft {
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = lat, let lon = lon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    // Aliases para compatibilidade
    var latitude: Double? { lat }
    var longitude: Double? { lon }
}

// MARK: - Aircraft Marker

struct AircraftMarker: View {
    let aircraft: Aircraft
    let isSelected: Bool

    var body: some View {
        ZStack {
            // Shadow/glow for selected
            if isSelected {
                Image(systemName: "airplane")
                    .font(.system(size: 24))
                    .foregroundStyle(.blue)
                    .blur(radius: 4)
            }

            // Aircraft icon
            Image(systemName: "airplane")
                .font(.system(size: isSelected ? 22 : 18))
                .foregroundStyle(markerColor)
                .rotationEffect(.degrees(aircraft.track ?? 0))
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    private var markerColor: Color {
        // Color based on altitude
        let alt = aircraft.altitudeFt
        if alt < 10000 {
            return .green
        } else if alt < 25000 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Aircraft Info Card

struct AircraftInfoCard: View {
    let aircraft: Aircraft

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: aircraft.movementIcon)
                    .foregroundStyle(Color.fromName(aircraft.movementColor))

                HStack(spacing: 6) {
                    if let logoURL = aircraft.airlineLogoURL {
                        AsyncImage(url: logoURL) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 18)
                            default:
                                if let airline = aircraft.airline {
                                    Text(airline)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else if let airline = aircraft.airline {
                        Text(airline)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(aircraft.displayCallsign)
                        .font(.headline)
                        .monospacedDigit()
                }
            }

            Divider()

            HStack(spacing: 20) {
                let alt = Formatters.altitudeDual(aircraft.altitudeFt)
                InfoItem(icon: "arrow.up.and.down", label: alt.metric, value: alt.aviation)
                
                let speed = Formatters.speedDual(aircraft.speedKt)
                InfoItem(icon: "gauge.with.needle", label: speed.metric, value: speed.aviation)

                if let dist = aircraft.distanceNm {
                    let d = Formatters.distanceDual(dist)
                    InfoItem(icon: "location", label: d.metric, value: d.aviation)
                }

                if aircraft.verticalRateFpm != 0 {
                    InfoItem(
                        icon: aircraft.verticalRateFpm > 0 ? "arrow.up" : "arrow.down",
                        label: "V/S",
                        value: "\(abs(aircraft.verticalRateFpm)) fpm"
                    )
                }
            }

            if let model = aircraft.model, !model.isEmpty {
                HStack {
                    Image(systemName: "airplane.circle")
                        .foregroundStyle(.secondary)
                    Text(model)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .glassCard(cornerRadius: 16)
    }
}

struct InfoItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .monospacedDigit()

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Fullscreen Map View

struct FullscreenMapView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            NativeRadarMapView()
                .environmentObject(appState)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Radar ADS-B")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Fechar") {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        HStack {
                            Image(systemName: "airplane")
                            Text("\(appState.aircraftList.filter { $0.hasPosition }.count)")
                                .monospacedDigit()
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
        }
    }
}

#Preview {
    AircraftMapView(aircraft: [])
}
