import MapKit
import SwiftUI

// MARK: - Native Radar Map View

struct NativeRadarMapView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var favoritesManager = FavoritesManager.shared
    @State private var position: MapCameraPosition
    @State private var selectedAircraftID: Aircraft.ID?
    @State private var selectedAircraft: Aircraft?
    @State private var dismissedAircraftID: Aircraft.ID?
    @State private var mapStyle: RadarMapStyle = .standard
    @State private var showLabels = true
    @State private var showRangeRings = true
    @State private var showAirports = true
    @State private var showTrails = false
    @State private var isFollowing = false
    @State private var showSettings = false
    @State private var searchText = ""
    @State private var trailHistory: [String: [CLLocationCoordinate2D]] = [:]
    @State private var filterMinAlt: Double = 0
    @State private var filterMaxAlt: Double = 60_000
    @State private var filterShowMilitary = true
    @State private var filterShowEmergency = true
    @State private var filterShowCivil = true

    let receiverLocation = CLLocationCoordinate2D(latitude: -20.512504, longitude: -47.400830)

    private static let airports: [(icao: String, name: String, coord: CLLocationCoordinate2D)] = [
        ("SIMK", "Franca", CLLocationCoordinate2D(latitude: -20.5922, longitude: -47.3829)),
        (
            "SBSR", "São José Rio Preto",
            CLLocationCoordinate2D(latitude: -20.8166, longitude: -49.4065)
        ),
        ("SBBH", "Pampulha", CLLocationCoordinate2D(latitude: -19.8516, longitude: -43.9509)),
        ("SBSP", "Congonhas", CLLocationCoordinate2D(latitude: -23.6261, longitude: -46.6564)),
        ("SBGR", "Guarulhos", CLLocationCoordinate2D(latitude: -23.4356, longitude: -46.4731)),
        ("SBKP", "Viracopos", CLLocationCoordinate2D(latitude: -23.0074, longitude: -47.1345)),
        ("SBRP", "Ribeirão Preto", CLLocationCoordinate2D(latitude: -21.1364, longitude: -47.7767)),
        ("SBUL", "Uberlândia", CLLocationCoordinate2D(latitude: -18.8836, longitude: -48.2253)),
        ("SBCF", "Confins", CLLocationCoordinate2D(latitude: -19.6244, longitude: -43.9719)),
        ("SBBR", "Brasília", CLLocationCoordinate2D(latitude: -15.8711, longitude: -47.9186)),
        ("SBGL", "Galeão", CLLocationCoordinate2D(latitude: -22.8090, longitude: -43.2506)),
        ("SBCT", "Curitiba", CLLocationCoordinate2D(latitude: -25.5285, longitude: -49.1758)),
        ("SBFL", "Florianópolis", CLLocationCoordinate2D(latitude: -27.6703, longitude: -48.5525)),
        ("SBPA", "Porto Alegre", CLLocationCoordinate2D(latitude: -29.9944, longitude: -51.1714)),
    ]

    enum RadarMapStyle: String, CaseIterable {
        case standard = "Mapa"
        case satellite = "Sat"
        case hybrid = "Híb"

        var mapStyle: MapStyle {
            switch self {
            case .standard: return .standard(elevation: .realistic, emphasis: .muted)
            case .satellite: return .imagery(elevation: .realistic)
            case .hybrid: return .hybrid(elevation: .realistic)
            }
        }
    }

    init() {
        self._position = State(
            initialValue: .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: -20.512504, longitude: -47.400830),
                    span: MKCoordinateSpan(latitudeDelta: 4.0, longitudeDelta: 4.0)
                )))
    }

    // MARK: - Computed Properties

    private var aircraftWithPosition: [Aircraft] {
        var list = appState.aircraftList.filter { $0.hasPosition }

        // Category filters
        if !filterShowMilitary { list = list.filter { !$0.isMilitary } }
        if !filterShowEmergency { list = list.filter { !$0.isEmergency } }
        if !filterShowCivil { list = list.filter { $0.isMilitary || $0.isEmergency } }

        // Altitude filter
        if filterMinAlt > 0 || filterMaxAlt < 60_000 {
            list = list.filter {
                Double($0.altitudeFt) >= filterMinAlt && Double($0.altitudeFt) <= filterMaxAlt
            }
        }

        // Text search
        guard !searchText.isEmpty else { return list }
        let query = searchText.uppercased()
        return list.filter {
            $0.displayCallsign.uppercased().contains(query)
                || ($0.hex ?? "").uppercased().contains(query)
                || ($0.model ?? "").uppercased().contains(query)
                || ($0.registration ?? "").uppercased().contains(query)
                || ($0.squawk ?? "").contains(query)
        }
    }

    private var altitudeDistribution:
        (ground: CGFloat, low: CGFloat, med: CGFloat, high: CGFloat, cruise: CGFloat)
    {
        let list = aircraftWithPosition
        guard !list.isEmpty else { return (0, 0, 0, 0, 0) }
        var g = 0
        var l = 0
        var m = 0
        var h = 0
        var c = 0
        for ac in list {
            let alt = ac.altitudeFt
            if alt <= 0 {
                g += 1
            } else if alt < 10_000 {
                l += 1
            } else if alt < 25_000 {
                m += 1
            } else if alt < 35_000 {
                h += 1
            } else {
                c += 1
            }
        }
        let t = CGFloat(list.count)
        return (CGFloat(g) / t, CGFloat(l) / t, CGFloat(m) / t, CGFloat(h) / t, CGFloat(c) / t)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            mapContent
                .ignoresSafeArea(edges: .bottom)

            // Overlays
            VStack(spacing: 0) {
                headerBar
                Spacer()
                if let ac = selectedAircraft {
                    detailCard(for: ac)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                altitudeBar
            }
            .animation(.easeInOut(duration: 0.25), value: selectedAircraft?.id)
        }
        .onChange(of: selectedAircraftID) { _, newID in
            // If the user just dismissed this aircraft, reject Map re-selection
            if let newID, newID == dismissedAircraftID {
                selectedAircraft = nil
                isFollowing = false
                selectedAircraftID = nil
                return
            }
            withAnimation(.easeInOut(duration: 0.2)) {
                if let id = newID {
                    dismissedAircraftID = nil
                    selectedAircraft = aircraftWithPosition.first { $0.id == id }
                } else {
                    selectedAircraft = nil
                    isFollowing = false
                }
            }
        }
        .onChange(of: appState.aircraftList) { _, _ in
            updateTrails()
            if isFollowing, let ac = selectedAircraft,
                let updated = aircraftWithPosition.first(where: { $0.id == ac.id }),
                let lat = updated.lat, let lon = updated.lon
            {
                selectedAircraft = updated
                withAnimation(.easeInOut(duration: 0.3)) {
                    position = .region(
                        MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
                        ))
                }
            }
        }
        .onChange(of: appState.mapFocusAircraft) { _, aircraft in
            if let ac = aircraft, let lat = ac.lat, let lon = ac.lon {
                withAnimation {
                    position = .region(
                        MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
                        ))
                    selectedAircraftID = ac.id
                }
                appState.mapFocusAircraft = nil
            }
        }
        .sheet(isPresented: $showSettings) {
            radarSettingsSheet
        }
    }

    // MARK: - Map Content

    private var mapContent: some View {
        Map(position: $position, selection: $selectedAircraftID) {
            // Receiver
            Annotation("", coordinate: receiverLocation, anchor: .center) {
                ReceiverPulse()
            }

            // Range Rings
            if showRangeRings {
                ForEach([50, 100, 150, 200], id: \.self) { nm in
                    MapCircle(center: receiverLocation, radius: CLLocationDistance(nm) * 1852)
                        .foregroundStyle(.clear)
                        .stroke(.blue.opacity(0.25), lineWidth: 1)
                }
            }

            // Airports
            if showAirports {
                ForEach(Self.airports, id: \.icao) { apt in
                    Annotation("", coordinate: apt.coord, anchor: .center) {
                        AirportPin(icao: apt.icao)
                    }
                }
            }

            // Trails
            if showTrails {
                ForEach(Array(trailHistory.keys), id: \.self) { key in
                    if let coords = trailHistory[key], coords.count >= 2 {
                        MapPolyline(coordinates: coords)
                            .stroke(trailColor(for: key), lineWidth: 2)
                    }
                }
            }

            // Aircraft annotations
            ForEach(aircraftWithPosition) { ac in
                if let coord = ac.coordinate {
                    Annotation(
                        showLabels ? ac.displayCallsign : "", coordinate: coord, anchor: .center
                    ) {
                        RadarAircraftPin(
                            aircraft: ac,
                            rotationDegrees: aircraftRotationDegrees(for: ac),
                            isSelected: selectedAircraftID == ac.id,
                            isFavorite: favoritesManager.isFavorite(aircraft: ac)
                        )
                    }
                    .tag(ac.id)
                    .annotationTitles(showLabels ? .automatic : .hidden)
                }
            }
        }
        .mapStyle(mapStyle.mapStyle)
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            let region = context.region
            let c = region.center
            let s = region.span
            let bounds = [
                c.latitude - s.latitudeDelta / 2,
                c.latitude + s.latitudeDelta / 2,
                c.longitude - s.longitudeDelta / 2,
                c.longitude + s.longitudeDelta / 2,
            ]
            appState.updateRadarBounds(bounds)
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                // Title
                Button {
                    withAnimation {
                        position = .region(
                            MKCoordinateRegion(
                                center: receiverLocation,
                                span: MKCoordinateSpan(latitudeDelta: 4.0, longitudeDelta: 4.0)
                            ))
                    }
                } label: {
                    Text("Radar ADS-B")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }

                // Map Style Picker
                Picker("", selection: $mapStyle) {
                    ForEach(RadarMapStyle.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)

                Spacer()

                // Controls
                HStack(spacing: 4) {
                    headerButton(icon: "line.3.horizontal", isActive: false) {
                        showSettings.toggle()
                    }
                    headerButton(icon: "globe", isActive: appState.isOpenSkyEnabled) {
                        appState.isOpenSkyEnabled.toggle()
                    }
                    headerButton(icon: "location.fill", isActive: false) {
                        if let userCoord = locationManager.userCoordinate {
                            withAnimation {
                                position = .region(
                                    MKCoordinateRegion(
                                        center: userCoord,
                                        span: MKCoordinateSpan(
                                            latitudeDelta: 2.0, longitudeDelta: 2.0)
                                    ))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Status bar
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                    Text("Ao vivo")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Label("\(aircraftWithPosition.count)", systemImage: "airplane")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                if appState.isOpenSkyEnabled {
                    HStack(spacing: 2) {
                        Image(systemName: "globe")
                            .font(.system(size: 8))
                            .foregroundStyle(.orange)
                        Text("\(appState.openskyAircraftCount)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.orange)
                            .monospacedDigit()
                    }
                }

                Label(
                    "\(appState.localAircraftCount)",
                    systemImage: "antenna.radiowaves.left.and.right"
                )
                .font(.system(size: 10))
                .foregroundStyle(.blue)
                .monospacedDigit()

                // Military count
                let milCount = aircraftWithPosition.filter(\.isMilitary).count
                if milCount > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.indigo)
                        Text("\(milCount)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.indigo)
                            .monospacedDigit()
                    }
                }

                // Emergency count
                let emgCount = aircraftWithPosition.filter(\.isEmergency).count
                if emgCount > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.red)
                        Text("\(emgCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.red)
                            .monospacedDigit()
                    }
                }

                Spacer()

                Text(timeString)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
        .modifier(FloatingBarGlass())
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: Date())
    }

    private func headerButton(icon: String, isActive: Bool, action: @escaping () -> Void)
        -> some View
    {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 32, height: 32)
                .background(isActive ? Color.accentColor : Color(.systemGray5).opacity(0.5))
                .foregroundStyle(isActive ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Detail Card

    private func detailCard(for aircraft: Aircraft) -> some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(.systemGray3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 6)

            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(aircraft.displayCallsign)
                                .font(.system(size: 20, weight: .bold, design: .monospaced))

                            // Source badge
                            Text(
                                aircraft.source == .opensky
                                    ? "OpenSky" : (aircraft.source == .network ? "Rede" : "Local")
                            )
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                aircraft.source == .local
                                    ? Color.blue.opacity(0.3) : Color.orange.opacity(0.3)
                            )
                            .foregroundStyle(aircraft.source == .local ? .blue : .orange)
                            .clipShape(Capsule())

                            // Military badge
                            if aircraft.isMilitary {
                                Text("MILITAR")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.indigo.opacity(0.3))
                                    .foregroundStyle(.indigo)
                                    .clipShape(Capsule())
                            }

                            // Emergency badge
                            if let emg = aircraft.emergencyLabel {
                                Text(emg)
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red.opacity(0.3))
                                    .foregroundStyle(.red)
                                    .clipShape(Capsule())
                            }
                        }

                        HStack(spacing: 8) {
                            if let hex = aircraft.hex {
                                Text(hex.uppercased())
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            if let model = aircraft.model, !model.isEmpty {
                                Text(model)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            if let reg = aircraft.registration, !reg.isEmpty {
                                Text(reg)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.blue)
                            }
                            if let sq = aircraft.squawk, !sq.isEmpty {
                                Text("SQ \(sq)")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(aircraft.isEmergency ? .red : .secondary)
                            }
                        }
                    }

                    Spacer()

                    // Action buttons
                    HStack(spacing: 8) {
                        // Favorite
                        Button {
                            if let hex = aircraft.hex {
                                favoritesManager.toggle(hex)
                            } else {
                                favoritesManager.toggle(aircraft.callsign)
                            }
                        } label: {
                            Image(
                                systemName: favoritesManager.isFavorite(aircraft: aircraft)
                                    ? "star.fill" : "star"
                            )
                            .font(.system(size: 14))
                            .foregroundStyle(
                                favoritesManager.isFavorite(aircraft: aircraft)
                                    ? .yellow : .secondary)
                        }

                        Button {
                            isFollowing.toggle()
                        } label: {
                            Image(systemName: isFollowing ? "location.fill" : "location")
                                .font(.system(size: 14))
                                .foregroundStyle(isFollowing ? .blue : .secondary)
                        }

                        Button {
                            dismissSelectedAircraft()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.secondary)
                                .frame(width: 34, height: 34)
                                .background(Color(.systemGray5).opacity(0.85))
                                .clipShape(Circle())
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Aircraft Photo
                AircraftPhotoView(aircraft: aircraft)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                // Stats Grid
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                    spacing: 8
                ) {
                    RadarStatCell(
                        icon: "arrow.up.and.down",
                        value: "\(aircraft.altitudeFt.formatted())",
                        unit: "ft",
                        color: altitudeColor(aircraft.altitudeFt)
                    )
                    RadarStatCell(
                        icon: "gauge.with.needle",
                        value: "\(aircraft.speedKt)",
                        unit: "kt",
                        color: .blue
                    )
                    RadarStatCell(
                        icon: aircraft.verticalRateFpm > 0
                            ? "arrow.up.right"
                            : (aircraft.verticalRateFpm < 0 ? "arrow.down.right" : "arrow.right"),
                        value:
                            "\(aircraft.verticalRateFpm > 0 ? "+" : "")\(aircraft.verticalRateFpm)",
                        unit: "fpm",
                        color: aircraft.verticalRateFpm > 256
                            ? .green : (aircraft.verticalRateFpm < -256 ? .orange : .secondary)
                    )

                    if let dist = aircraft.distanceNm ?? computedDistanceNm(for: aircraft) {
                        RadarStatCell(
                            icon: "location",
                            value: String(format: "%.1f", dist),
                            unit: "nm",
                            color: .cyan
                        )
                    } else if let track = aircraft.track {
                        RadarStatCell(
                            icon: "safari",
                            value: "\(Int(track))°",
                            unit: "hdg",
                            color: .secondary
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .glassCard(cornerRadius: 20)
        .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: -4)
        .padding(.horizontal, 8)
        .padding(.bottom, 44)  // space for altitude bar
    }

    private func computedDistanceNm(for aircraft: Aircraft) -> Double? {
        guard let lat = aircraft.lat, let lon = aircraft.lon else { return nil }
        let acLoc = CLLocation(latitude: lat, longitude: lon)
        let rxLoc = CLLocation(
            latitude: receiverLocation.latitude, longitude: receiverLocation.longitude)
        let distMeters = acLoc.distance(from: rxLoc)
        return distMeters / 1852.0
    }

    // MARK: - Altitude Bar

    private var altitudeBar: some View {
        let dist = altitudeDistribution
        return HStack(spacing: 6) {
            Text("ALT")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                HStack(spacing: 0) {
                    Rectangle().fill(Color(.systemGray)).frame(width: geo.size.width * dist.ground)
                    Rectangle().fill(Color.green).frame(width: geo.size.width * dist.low)
                    Rectangle().fill(Color.blue).frame(width: geo.size.width * dist.med)
                    Rectangle().fill(Color.orange).frame(width: geo.size.width * dist.high)
                    Rectangle().fill(Color.red).frame(width: geo.size.width * dist.cruise)
                }
                .frame(height: 5)
                .clipShape(Capsule())
            }
            .frame(height: 5)

            Text("MSG: \(Text("\(aircraftWithPosition.count)").font(.system(size: 9, weight: .bold)).foregroundStyle(.green))/s")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .modifier(FloatingBarGlass())
    }

    // MARK: - Settings Sheet

    private var radarSettingsSheet: some View {
        NavigationStack {
            Form {
                Section("Estilo do Mapa") {
                    Picker("Tipo", selection: $mapStyle) {
                        ForEach(RadarMapStyle.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Exibição") {
                    Toggle("Labels das Aeronaves", isOn: $showLabels)
                    Toggle("Anéis de Alcance", isOn: $showRangeRings)
                    Toggle("Aeroportos", isOn: $showAirports)
                    Toggle("Trilhas", isOn: $showTrails)
                }

                Section("Fontes de Dados") {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundStyle(.blue)
                        Text("Meu Radar (Local)")
                        Spacer()
                        Text("\(appState.localAircraftCount)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }

                    Toggle(isOn: $appState.isOpenSkyEnabled) {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundStyle(.orange)
                            Text("OpenSky (Global)")
                        }
                    }

                    if appState.isOpenSkyEnabled {
                        HStack {
                            Text("OpenSky")
                            Spacer()
                            Text("\(appState.openskyAircraftCount)")
                                .monospacedDigit()
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Section("Buscar") {
                    TextField("Callsign, Hex, Tipo, Squawk...", text: $searchText)
                        .textInputAutocapitalization(.characters)
                }

                Section("Filtros") {
                    Toggle("Civil", isOn: $filterShowCivil)
                    Toggle("Militar", isOn: $filterShowMilitary)
                    Toggle("Emergência", isOn: $filterShowEmergency)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(
                            "Altitude: \(Int(filterMinAlt).formatted()) – \(Int(filterMaxAlt).formatted()) ft"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            Text("Min")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Slider(value: $filterMinAlt, in: 0...60_000, step: 1000)
                        }
                        HStack(spacing: 12) {
                            Text("Max")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Slider(value: $filterMaxAlt, in: 0...60_000, step: 1000)
                        }
                    }

                    if filterMinAlt > 0 || filterMaxAlt < 60_000 || !filterShowCivil
                        || !filterShowMilitary || !filterShowEmergency
                    {
                        Button("Limpar Filtros") {
                            filterMinAlt = 0
                            filterMaxAlt = 60_000
                            filterShowCivil = true
                            filterShowMilitary = true
                            filterShowEmergency = true
                        }
                        .foregroundStyle(.red)
                    }
                }

                Section("Localização do Receptor") {
                    HStack {
                        Text("Franca, SP")
                        Spacer()
                        Text(
                            "\(receiverLocation.latitude, specifier: "%.4f"), \(receiverLocation.longitude, specifier: "%.4f")"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                if !favoritesManager.favorites.isEmpty {
                    Section("Favoritos (\(favoritesManager.favorites.count))") {
                        ForEach(Array(favoritesManager.favorites).sorted(), id: \.self) { fav in
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.system(size: 12))
                                Text(fav)
                                    .font(.system(size: 13, design: .monospaced))
                                Spacer()
                                Button {
                                    favoritesManager.toggle(fav)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Legenda de Cores")
                            .font(.headline)
                        legendRow(color: .green, text: "< 10.000 ft (baixa)")
                        legendRow(color: .orange, text: "10.000 - 25.000 ft (média)")
                        legendRow(color: .red, text: "25.000 - 35.000 ft (alta)")
                        legendRow(color: .purple, text: "> 35.000 ft (cruzeiro)")
                        Divider()
                        legendRow(color: .indigo, text: "Militar")
                        legendRow(color: .red, text: "Emergência (SQ 7500/7600/7700)")
                        Divider()
                        legendRow(color: .blue, text: "Fonte: Meu Radar (Local)")
                        legendRow(color: .orange, text: "Fonte: OpenSky (Global)")
                    }
                    .font(.caption)
                }
            }
            .navigationTitle("Configurações do Radar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("OK") { showSettings = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func legendRow(color: Color, text: String) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(text)
        }
    }

    // MARK: - Helpers

    private func altitudeColor(_ alt: Int) -> Color {
        if alt <= 0 { return .gray }
        if alt < 10_000 { return .green }
        if alt < 25_000 { return .orange }
        if alt < 35_000 { return .red }
        return .purple
    }

    private func trailColor(for key: String) -> Color {
        guard let ac = aircraftWithPosition.first(where: { $0.id == key }) else { return .blue }
        return altitudeColor(ac.altitudeFt).opacity(0.6)
    }

    private func aircraftRotationDegrees(for aircraft: Aircraft) -> Double {
        // SF Symbol "airplane" is drawn with the nose already tilted ~45 degrees.
        let symbolBaseCourse = 45.0
        let course = recentCourse(for: aircraft) ?? aircraft.track ?? 0
        return normalizedDegrees(course - symbolBaseCourse)
    }

    private func recentCourse(for aircraft: Aircraft) -> Double? {
        guard let history = trailHistory[aircraft.id], history.count >= 2 else { return nil }
        return bearing(from: history[history.count - 2], to: history[history.count - 1])
    }

    private func bearing(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        let startLat = start.latitude * .pi / 180
        let endLat = end.latitude * .pi / 180
        let deltaLon = (end.longitude - start.longitude) * .pi / 180

        let y = sin(deltaLon) * cos(endLat)
        let x =
            cos(startLat) * sin(endLat)
            - sin(startLat) * cos(endLat) * cos(deltaLon)

        return normalizedDegrees(atan2(y, x) * 180 / .pi)
    }

    private func normalizedDegrees(_ value: Double) -> Double {
        let normalized = value.truncatingRemainder(dividingBy: 360)
        return normalized >= 0 ? normalized : normalized + 360
    }

    private func dismissSelectedAircraft() {
        let dismissed = selectedAircraftID ?? selectedAircraft?.id
        withAnimation(.easeInOut(duration: 0.2)) {
            dismissedAircraftID = dismissed
            selectedAircraftID = nil
            selectedAircraft = nil
            isFollowing = false
        }

        // Keep the dismissed id briefly so MapKit cannot immediately restore the selection.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if selectedAircraftID == nil {
                dismissedAircraftID = nil
            }
        }
    }

    private func updateTrails() {
        for ac in aircraftWithPosition {
            guard let lat = ac.lat, let lon = ac.lon else { continue }
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            var history = trailHistory[ac.id] ?? []
            if let last = history.last,
                last.latitude == coord.latitude && last.longitude == coord.longitude
            {
                continue
            }
            history.append(coord)
            if history.count > 60 { history.removeFirst() }
            trailHistory[ac.id] = history
        }
        // Clean up stale trails
        let activeIDs = Set(aircraftWithPosition.map { $0.id })
        for key in trailHistory.keys where !activeIDs.contains(key) {
            trailHistory.removeValue(forKey: key)
        }
    }
}

// MARK: - Receiver Pulse

private struct ReceiverPulse: View {
    @State private var pulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(.blue.opacity(0.15))
                .frame(width: 44, height: 44)
                .scaleEffect(pulsing ? 1.3 : 1.0)
                .opacity(pulsing ? 0 : 0.5)

            Circle()
                .fill(.blue)
                .frame(width: 12, height: 12)
            Circle()
                .stroke(.white, lineWidth: 2)
                .frame(width: 12, height: 12)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: false)) {
                pulsing = true
            }
        }
    }
}

// MARK: - Airport Pin

private struct AirportPin: View {
    let icao: String

    var body: some View {
        VStack(spacing: 1) {
            Text("🛫")
                .font(.system(size: 14))
            Text(icao)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 2))
        }
    }
}

// MARK: - Aircraft Pin

struct RadarAircraftPin: View {
    let aircraft: Aircraft
    let rotationDegrees: Double
    let isSelected: Bool
    var isFavorite: Bool = false
    @State private var emergencyPulse = false

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                // Emergency pulse
                if aircraft.isEmergency {
                    Circle()
                        .fill(Color.red.opacity(emergencyPulse ? 0.5 : 0.15))
                        .frame(width: 48, height: 48)
                        .animation(
                            .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                            value: emergencyPulse)
                }

                // Selection glow
                if isSelected {
                    Circle()
                        .fill(markerColor.opacity(0.3))
                        .frame(width: 44, height: 44)

                    Circle()
                        .stroke(markerColor, lineWidth: 2)
                        .frame(width: 44, height: 44)
                }

                // Military badge
                if aircraft.isMilitary && !isSelected {
                    Circle()
                        .stroke(Color.indigo, lineWidth: 1.5)
                        .frame(width: 36, height: 36)
                }

                // Aircraft icon
                Image(systemName: aircraft.isMilitary ? "shield.fill" : "airplane")
                    .font(.system(size: isSelected ? 24 : 18, weight: .semibold))
                    .foregroundStyle(markerColor)
                    .rotationEffect(.degrees(aircraft.isMilitary ? 0 : rotationDegrees))
                    .shadow(color: markerColor.opacity(0.5), radius: isSelected ? 6 : 3)

                // Favorite star
                if isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.yellow)
                        .offset(x: 12, y: -12)
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .onAppear {
            if aircraft.isEmergency { emergencyPulse = true }
        }
    }

    private var markerColor: Color {
        // Emergency: red
        if aircraft.isEmergency { return .red }
        // Military: indigo
        if aircraft.isMilitary { return .indigo }
        // OpenSky: orange
        if aircraft.source == .opensky { return .orange }
        // Altitude-based
        let alt = aircraft.altitudeFt
        if alt <= 0 { return .gray }
        if alt < 10_000 { return .green }
        if alt < 25_000 { return .orange }
        if alt < 35_000 { return .red }
        return .purple
    }
}

// MARK: - Stat Cell

private struct RadarStatCell: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color.opacity(0.7))

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(unit)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
