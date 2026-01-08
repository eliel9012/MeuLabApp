import SwiftUI
import MapKit

struct AircraftMapView: View {
    let aircraft: [Aircraft]
    let receiverLocation: CLLocationCoordinate2D

    @State private var position: MapCameraPosition
    @State private var selectedAircraft: Aircraft?

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
        Map(position: $position, selection: $selectedAircraft) {
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
                        AircraftMarker(aircraft: ac, isSelected: selectedAircraft?.id == ac.id)
                    }
                    .tag(ac)
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
            if let selected = selectedAircraft {
                AircraftInfoCard(aircraft: selected)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: selectedAircraft?.id)
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
                    .foregroundStyle(Color(aircraft.movementColor))

                Text(aircraft.displayCallsign)
                    .font(.headline)
                    .monospacedDigit()

                Spacer()

                if let airline = aircraft.airline {
                    Text(airline)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                }
            }

            Divider()

            HStack(spacing: 20) {
                InfoItem(icon: "arrow.up.and.down", label: "Alt", value: "\(aircraft.altitudeFt.formatted()) ft")
                InfoItem(icon: "gauge.with.needle", label: "Vel", value: "\(aircraft.speedKt) kt")

                if let dist = aircraft.distanceNm {
                    InfoItem(icon: "location", label: "Dist", value: String(format: "%.1f nm", dist))
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
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(radius: 10)
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
            AircraftMapView(aircraft: appState.aircraftList)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Mapa ADS-B")
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
