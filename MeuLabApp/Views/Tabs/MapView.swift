import SwiftUI
import MapKit

struct MapView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var locationManager = LocationManager.shared
    @State private var position: MapCameraPosition
    @State private var selectedAircraft: Aircraft?
    @State private var mapStyle: MapStyleOption = .standard
    @State private var showRangeRings = true
    @State private var showUserRangeRings = false
    @State private var showSettings = false
    @State private var distanceMode: DistanceMode = .receiver

    let receiverLocation = CLLocationCoordinate2D(latitude: -20.512504, longitude: -47.400830)

    enum DistanceMode: String, CaseIterable {
        case receiver = "Receptor"
        case user = "Você"
    }

    init() {
        self._position = State(initialValue: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -20.512504, longitude: -47.400830),
            span: MKCoordinateSpan(latitudeDelta: 4.0, longitudeDelta: 4.0)
        )))
    }

    enum MapStyleOption: String, CaseIterable {
        case standard = "Padrão"
        case satellite = "Satélite"
        case hybrid = "Híbrido"

        var mapStyle: MapStyle {
            switch self {
            case .standard: return .standard(elevation: .realistic)
            case .satellite: return .imagery(elevation: .realistic)
            case .hybrid: return .hybrid(elevation: .realistic)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $position, selection: $selectedAircraft) {
                    // User location (shown automatically by MapUserLocationButton)
                    UserAnnotation()

                    // Receiver location
                    Annotation("Receptor", coordinate: receiverLocation) {
                        ReceiverMarker()
                    }

                    // Range rings from receiver
                    if showRangeRings {
                        ForEach([50, 100, 150, 200], id: \.self) { rangeNm in
                            MapCircle(center: receiverLocation, radius: CLLocationDistance(rangeNm) * 1852)
                                .stroke(.blue.opacity(0.3), lineWidth: 1)
                        }
                    }

                    // Range rings from user location
                    if showUserRangeRings, let userCoord = locationManager.userCoordinate {
                        ForEach([25, 50, 100], id: \.self) { rangeNm in
                            MapCircle(center: userCoord, radius: CLLocationDistance(rangeNm) * 1852)
                                .stroke(.green.opacity(0.3), lineWidth: 1)
                        }
                    }

                    // Aircraft
                    ForEach(aircraftWithPosition) { ac in
                        if let coord = ac.coordinate {
                            Annotation(ac.displayCallsign, coordinate: coord) {
                                MapAircraftMarker(
                                    aircraft: ac,
                                    isSelected: selectedAircraft?.id == ac.id
                                )
                            }
                            .tag(ac)
                        }
                    }
                }
                .mapStyle(mapStyle.mapStyle)
                .mapControls {
                    MapCompass()
                    MapScaleView()
                    MapUserLocationButton()
                }

                // Stats overlay
                VStack {
                    HStack {
                        Spacer()
                        statsOverlay
                    }
                    .padding()

                    Spacer()

                    // Selected aircraft info
                    if let selected = selectedAircraft {
                        MapAircraftInfoCard(
                            aircraft: selected,
                            locationManager: locationManager,
                            distanceMode: distanceMode
                        )
                        .padding()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .animation(.easeInOut, value: selectedAircraft?.id)
            .navigationTitle("Radar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            centerOnReceiver()
                        } label: {
                            Label("Receptor", systemImage: "antenna.radiowaves.left.and.right")
                        }

                        if locationManager.isAuthorized {
                            Button {
                                centerOnUser()
                            } label: {
                                Label("Minha Posição", systemImage: "location.fill")
                            }
                        }
                    } label: {
                        Image(systemName: "scope")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                MapSettingsSheet(
                    mapStyle: $mapStyle,
                    showRangeRings: $showRangeRings,
                    showUserRangeRings: $showUserRangeRings,
                    distanceMode: $distanceMode,
                    locationManager: locationManager
                )
                .presentationDetents([.medium, .large])
            }
            .onAppear {
                locationManager.requestPermission()
            }
        }
    }

    private var aircraftWithPosition: [Aircraft] {
        appState.aircraftList.filter { $0.hasPosition }
    }

    private var statsOverlay: some View {
        VStack(alignment: .trailing, spacing: 4) {
            // Aeronaves locais (meu radar)
            HStack(spacing: 4) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Text("\(appState.localAircraftCount)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .monospacedDigit()
            }

            // Aeronaves da rede
            if appState.showNetworkAircraft && appState.networkAircraftCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.caption)
                        .foregroundStyle(.purple)
                    Text("+\(appState.networkAircraftCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .monospacedDigit()
                        .foregroundStyle(.purple)
                }
            }

            Text("no mapa")
                .font(.caption2)
                .foregroundStyle(.secondary)

            // Show closest aircraft to user
            if locationManager.isAuthorized,
               let closest = closestAircraftToUser {
                Divider()
                    .frame(width: 60)
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text(String(format: "%.0f nm", closest.distance))
                        .font(.caption2)
                        .monospacedDigit()
                }
                Text(closest.callsign)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }

    private var closestAircraftToUser: (callsign: String, distance: Double)? {
        guard locationManager.isAuthorized else { return nil }

        var closest: (String, Double)? = nil

        for ac in aircraftWithPosition {
            if let lat = ac.latitude, let lon = ac.longitude,
               let dist = locationManager.distanceToUser(latitude: lat, longitude: lon) {
                if closest == nil || dist < closest!.1 {
                    closest = (ac.displayCallsign, dist)
                }
            }
        }

        return closest
    }

    private func centerOnReceiver() {
        withAnimation {
            position = .region(MKCoordinateRegion(
                center: receiverLocation,
                span: MKCoordinateSpan(latitudeDelta: 4.0, longitudeDelta: 4.0)
            ))
        }
    }

    private func centerOnUser() {
        guard let userCoord = locationManager.userCoordinate else { return }
        withAnimation {
            position = .region(MKCoordinateRegion(
                center: userCoord,
                span: MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)
            ))
        }
    }
}

// MARK: - Receiver Marker

struct ReceiverMarker: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.blue.opacity(0.2))
                .frame(width: 44, height: 44)
            Circle()
                .fill(.blue)
                .frame(width: 14, height: 14)
            Circle()
                .stroke(.white, lineWidth: 2)
                .frame(width: 14, height: 14)
        }
    }
}

// MARK: - Aircraft Marker for Map

struct MapAircraftMarker: View {
    let aircraft: Aircraft
    let isSelected: Bool

    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(aircraft.isLocal ? .blue.opacity(0.3) : .purple.opacity(0.3))
                    .frame(width: 40, height: 40)
            }

            // Anel indicador de fonte (rede = círculo tracejado)
            if !aircraft.isLocal {
                Circle()
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [4, 2]))
                    .foregroundStyle(.purple.opacity(0.6))
                    .frame(width: 28, height: 28)
            }

            Image(systemName: "airplane")
                .font(.system(size: isSelected ? 24 : 20))
                .foregroundStyle(markerColor)
                .rotationEffect(.degrees(aircraft.track ?? 0))
                .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    private var markerColor: Color {
        // Aeronaves da rede têm cor mais transparente
        let opacity: Double = aircraft.isLocal ? 1.0 : 0.7

        let alt = aircraft.altitudeFt
        if alt < 10000 {
            return .green.opacity(opacity)
        } else if alt < 25000 {
            return .orange.opacity(opacity)
        } else {
            return .red.opacity(opacity)
        }
    }
}

// MARK: - Aircraft Info Card

struct MapAircraftInfoCard: View {
    let aircraft: Aircraft
    let locationManager: LocationManager
    let distanceMode: MapView.DistanceMode

    private var displayDistance: Double? {
        guard let lat = aircraft.latitude, let lon = aircraft.longitude else {
            return aircraft.distanceNm
        }

        switch distanceMode {
        case .receiver:
            return locationManager.distanceToReceiver(latitude: lat, longitude: lon)
        case .user:
            return locationManager.distanceToUser(latitude: lat, longitude: lon)
        }
    }

    private var displayBearing: Double? {
        guard distanceMode == .user,
              let lat = aircraft.latitude,
              let lon = aircraft.longitude else {
            return nil
        }
        return locationManager.bearingToUser(latitude: lat, longitude: lon)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Image(systemName: aircraft.movementIcon)
                    .foregroundStyle(Color(aircraft.movementColor))
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(aircraft.displayCallsign)
                        .font(.headline)
                        .monospacedDigit()

                    if let airline = aircraft.airline {
                        Text(airline)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Badge de origem
                HStack(spacing: 4) {
                    Image(systemName: aircraft.source.iconName)
                        .font(.caption2)
                    Text(aircraft.isLocal ? "Local" : "Rede")
                        .font(.caption2)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(aircraft.isLocal ? Color.blue.opacity(0.2) : Color.purple.opacity(0.2))
                .foregroundStyle(aircraft.isLocal ? .blue : .purple)
                .cornerRadius(4)

                if let model = aircraft.model, !model.isEmpty {
                    Text(model)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(6)
                }
            }

            Divider()

            // Stats
            HStack(spacing: 12) {
                MapStatItem(
                    icon: "arrow.up.and.down",
                    value: "\(aircraft.altitudeFt.formatted()) ft",
                    label: "Altitude"
                )

                MapStatItem(
                    icon: "gauge.with.needle",
                    value: "\(aircraft.speedKt) kt",
                    label: "Velocidade"
                )

                if let dist = displayDistance {
                    MapStatItem(
                        icon: distanceMode == .user ? "person.fill" : "antenna.radiowaves.left.and.right",
                        value: String(format: "%.1f nm", dist),
                        label: distanceMode == .user ? "De você" : "Receptor"
                    )
                }

                if let bearing = displayBearing {
                    MapStatItem(
                        icon: "safari",
                        value: "\(Int(bearing))° \(LocationManager.compassDirection(from: bearing))",
                        label: "Direção"
                    )
                }

                if aircraft.verticalRateFpm != 0 {
                    MapStatItem(
                        icon: aircraft.verticalRateFpm > 0 ? "arrow.up" : "arrow.down",
                        value: "\(abs(aircraft.verticalRateFpm)) fpm",
                        label: "V/S"
                    )
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(radius: 10)
    }
}

struct MapStatItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .monospacedDigit()

            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Settings Sheet

struct MapSettingsSheet: View {
    @Binding var mapStyle: MapView.MapStyleOption
    @Binding var showRangeRings: Bool
    @Binding var showUserRangeRings: Bool
    @Binding var distanceMode: MapView.DistanceMode
    @ObservedObject var locationManager: LocationManager
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Estilo do Mapa") {
                    Picker("Estilo", selection: $mapStyle) {
                        ForEach(MapView.MapStyleOption.allCases, id: \.self) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Fontes de Dados") {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundStyle(.blue)
                        Text("Meu Radar")
                        Spacer()
                        Text("\(appState.localAircraftCount)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Toggle(isOn: $appState.showNetworkAircraft) {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundStyle(.purple)
                            Text("Rede ADSB.lol")
                        }
                    }

                    if appState.showNetworkAircraft {
                        HStack {
                            Text("Aeronaves extras")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("+\(appState.networkAircraftCount)")
                                .font(.caption)
                                .foregroundStyle(.purple)
                                .monospacedDigit()
                        }
                    }
                }

                Section("Anéis de Alcance") {
                    Toggle("Do Receptor (50-200 nm)", isOn: $showRangeRings)

                    if locationManager.isAuthorized {
                        Toggle("Da Sua Posição (25-100 nm)", isOn: $showUserRangeRings)
                    }
                }

                Section("Cálculo de Distância") {
                    Picker("Distância relativa a", selection: $distanceMode) {
                        ForEach(MapView.DistanceMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if distanceMode == .user && !locationManager.isAuthorized {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Permita localização para usar")
                                .font(.caption)
                        }
                    }
                }

                // Location status
                Section("Localização") {
                    HStack {
                        Image(systemName: locationManager.isAuthorized ? "location.fill" : "location.slash")
                            .foregroundStyle(locationManager.isAuthorized ? .green : .red)
                        Text(locationManager.isAuthorized ? "Ativa" : "Desativada")

                        Spacer()

                        if !locationManager.isAuthorized {
                            Button("Permitir") {
                                locationManager.requestPermission()
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    if let userLoc = locationManager.userLocation {
                        HStack {
                            Text("Lat: \(String(format: "%.4f", userLoc.coordinate.latitude))")
                            Spacer()
                            Text("Lon: \(String(format: "%.4f", userLoc.coordinate.longitude))")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    if let distToReceiver = locationManager.distanceToReceiver {
                        HStack {
                            Text("Distância ao receptor:")
                            Spacer()
                            Text(String(format: "%.1f km", distToReceiver))
                                .fontWeight(.medium)
                        }
                        .font(.caption)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Legenda de Cores")
                            .font(.headline)

                        HStack {
                            Circle().fill(.green).frame(width: 12, height: 12)
                            Text("< 10.000 ft")
                            Spacer()
                        }

                        HStack {
                            Circle().fill(.orange).frame(width: 12, height: 12)
                            Text("10.000 - 25.000 ft")
                            Spacer()
                        }

                        HStack {
                            Circle().fill(.red).frame(width: 12, height: 12)
                            Text("> 25.000 ft")
                            Spacer()
                        }

                        Divider()
                            .padding(.vertical, 4)

                        Text("Origem dos Dados")
                            .font(.headline)

                        HStack {
                            Image(systemName: "airplane")
                                .foregroundStyle(.blue)
                            Text("Meu Radar (cor sólida)")
                            Spacer()
                        }

                        HStack {
                            ZStack {
                                Circle()
                                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                                    .foregroundStyle(.purple)
                                    .frame(width: 16, height: 16)
                                Image(systemName: "airplane")
                                    .font(.caption2)
                                    .foregroundStyle(.purple.opacity(0.7))
                            }
                            Text("Rede ADSB.lol (tracejado)")
                            Spacer()
                        }
                    }
                    .font(.caption)
                }
            }
            .navigationTitle("Configurações")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("OK") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    MapView()
        .environmentObject(AppState())
}
