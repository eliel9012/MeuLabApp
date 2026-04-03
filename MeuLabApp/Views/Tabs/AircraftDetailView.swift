import CoreLocation
import SwiftUI

struct AircraftDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    let ac: Aircraft

    @State private var faFlight: FlightAwareFlight?
    @State private var faLoading = false
    @State private var faError: String?

    @State private var registration: String?
    @State private var isLookingUp = false
    @State private var classifiedAirlineName: String?
    @State private var showClassificationSheet = false
    @State private var classificationMessage: String?
    @State private var isLoadingClassification = false
    @State private var nearbyCity: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Premium Header with Airline Logo and Main Info
                HStack(spacing: 20) {
                    if let logoURL = ac.airlineLogoURL {
                        AsyncImage(url: logoURL) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().aspectRatio(contentMode: .fit)
                            case .failure, .empty:
                                Image(systemName: "airplane.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.blue.opacity(0.3))
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(width: 70, height: 70)
                        .padding(8)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.1), radius: 4)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(ac.displayCallsign)
                            .font(.system(size: 34, weight: .black, design: .monospaced))
                            .tracking(1)
                        if let airline = classifiedAirlineName ?? ac.airline {
                            Text(airline)
                                .font(.headline)
                                .foregroundStyle(.blue)
                        }
                    }
                    Spacer()
                }
                .padding()
                .glassCard(cornerRadius: 24)

                // Route Visualizer (FlightAware)
                if let faFlight {
                    AircraftRouteView(flight: faFlight)
                        .padding()
                        .glassCard(cornerRadius: 20)
                }

                // Aircraft Photo (PlaneSpotters with OpenSky Fallback)
                AircraftPhotoView(aircraft: ac)
                    .frame(height: 250)
                    .glassCard(cornerRadius: 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )

                // Flight Data Grid
                VStack(spacing: 16) {
                    // Classification Section
                    Button {
                        showClassificationSheet = true
                    } label: {
                        HStack {
                            Label(
                                "Classificar empresa aérea", systemImage: "building.2.crop.circle"
                            )
                            .font(.subheadline.weight(.semibold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)

                    if isLoadingClassification {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.85)
                            Text("Carregando classificação...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }

                    if let message = classificationMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Divider()

                    DetailRow(icon: "airplane", title: "Modelo", value: ac.model ?? "N/A")
                    DetailRow(
                        icon: "number", title: "Matrícula",
                        value: registration ?? ac.registration ?? "N/A")
                    DetailRow(
                        icon: "arrow.up.forward", title: "Altitude", value: "\(ac.altitudeFt) ft")
                    DetailRow(
                        icon: "speedometer", title: "Velocidade",
                        value: "\(ac.speedKt) kt (\(ac.speedKmh) km/h)")
                    DetailRow(
                        icon: "arrow.up.and.down", title: "Razão Vertical",
                        value: "\(ac.verticalRateFpm) fpm")
                    if let track = ac.track {
                        DetailRow(
                            icon: "compass.drawing", title: "Proa",
                            value: String(format: "%.0f°", track))
                    }
                    if let lat = ac.lat, let lon = ac.lon {
                        let coordinates = String(format: "%.4f, %.4f", lat, lon)
                        let locationValue =
                            nearbyCity.map { "\(coordinates) • próximo a \($0)" } ?? coordinates
                        DetailRow(icon: "location.fill", title: "Coordenadas", value: locationValue)
                    }
                    if let dist = ac.distanceNm {
                        DetailRow(
                            icon: "location.fill", title: "Distância",
                            value: String(format: "%.1f nm", dist))
                    }

                    // Open in Map Button
                    Button {
                        appState.mapFocusAircraft = ac
                        NotificationCenter.default.post(
                            name: Notification.Name("meulab.navigateToTab"),
                            object: nil,
                            userInfo: ["tab": "map"]
                        )
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "map.fill")
                            Text("Ver no Mapa")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.top, 8)
                }
                .padding()
                .glassCard(cornerRadius: 24)

                // FlightAware block (gate/terminal/schedule)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("FlightAware", systemImage: "clock.badge.checkmark")
                            .font(.headline)
                        Spacer()
                        if faLoading {
                            ProgressView().scaleEffect(0.9)
                        }
                    }

                    if let faFlight {
                        let orig = faFlight.origin?.bestCode ?? "-"
                        let dest = faFlight.destination?.bestCode ?? "-"

                        HStack(spacing: 10) {
                            Text(orig)
                                .font(.title3.bold())
                                .monospaced()
                            Image(systemName: "arrow.right")
                                .foregroundStyle(.secondary)
                            Text(dest)
                                .font(.title3.bold())
                                .monospaced()
                            Spacer()
                            Text(faFlight.bestIdent)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .monospaced()
                        }

                        Divider()

                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Saída")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(
                                    FlightAwareTime.short(faFlight.actualOut)
                                        ?? FlightAwareTime.short(faFlight.estimatedOut)
                                        ?? FlightAwareTime.short(faFlight.scheduledOut)
                                        ?? "-"
                                )
                                .font(.headline.monospacedDigit())
                                Text(
                                    "T\(faFlight.terminalOrigin ?? "-") • G\(faFlight.gateOrigin ?? "-")"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Chegada")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(
                                    FlightAwareTime.short(faFlight.actualIn)
                                        ?? FlightAwareTime.short(faFlight.estimatedIn)
                                        ?? FlightAwareTime.short(faFlight.scheduledIn)
                                        ?? "-"
                                )
                                .font(.headline.monospacedDigit())
                                Text(
                                    "T\(faFlight.terminalDestination ?? "-") • G\(faFlight.gateDestination ?? "-")"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    } else if let faError {
                        Text(faError)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Sem dados de horário/gate para este ident agora.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .glassCard(cornerRadius: 16)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Detalhes do Voo")
        .sheet(isPresented: $showClassificationSheet) {
            AirlineClassificationSheet(
                aircraft: ac,
                currentAirline: classifiedAirlineName ?? ac.airline,
                suggestions: classificationSuggestions
            ) { selectedName in
                Task {
                    await saveClassification(airlineName: selectedName)
                }
            }
        }
        .task {
            if let reg = ac.registration {
                registration = reg
            }
            await loadNearbyCity()
            await loadFlightAware()
            await loadExistingClassification()
        }
    }

    @MainActor
    private func loadNearbyCity() async {
        guard let lat = ac.lat, let lon = ac.lon else {
            nearbyCity = nil
            return
        }
        nearbyCity = await NearbyCityResolver.shared.lookup(lat: lat, lon: lon)
    }

    @MainActor
    private func loadFlightAware() async {
        let ident = ac.callsign.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ident.isEmpty, ident != "???" else { return }
        if faLoading { return }

        faLoading = true
        faError = nil
        defer { faLoading = false }

        do {
            let resp = try await APIService.shared.fetchFlightAwareFlight(ident: ident, maxPages: 1)
            faFlight = resp.data.flights?.first
        } catch {
            faError = error.localizedDescription
        }
    }

    private var classificationSuggestions: [String] {
        let fromSummary = appState.adsbSummary?.airlines.map(\.name) ?? []
        let merged = Set(fromSummary + AirlineLogo.mapping.keys)
        return merged.sorted()
    }

    private func loadExistingClassification() async {
        isLoadingClassification = true
        defer { isLoadingClassification = false }

        do {
            let result = try await APIService.shared.fetchAirlineClassification(
                hex: ac.hex,
                registration: registration ?? ac.registration,
                callsign: ac.callsign,
                model: ac.model
            )
            if let classified = result.classification?.airlineName, !classified.isEmpty {
                await MainActor.run {
                    classifiedAirlineName = classified
                    appState.saveManualAirlineOverride(classified, for: ac)
                    classificationMessage = "Classificação manual encontrada na API."
                }
            }
        } catch {
            await MainActor.run {
                classificationMessage = "Classificação manual ainda não disponível no servidor."
            }
        }
    }

    private func saveClassification(airlineName: String) async {
        isLoadingClassification = true
        defer { isLoadingClassification = false }

        let payload = AirlineClassificationUpsertRequest(
            hex: ac.hex,
            registration: registration ?? ac.registration,
            callsign: ac.callsign,
            model: ac.model,
            airlineName: airlineName,
            airlineIcao: nil,
            airlineIata: nil,
            source: "manual",
            confidence: 1.0
        )

        do {
            let response = try await APIService.shared.saveAirlineClassification(payload)
            await MainActor.run {
                if let name = response.classification?.airlineName ?? response.message,
                    !name.isEmpty
                {
                    classifiedAirlineName = response.classification?.airlineName ?? airlineName
                } else {
                    classifiedAirlineName = airlineName
                }
                appState.saveManualAirlineOverride(classifiedAirlineName ?? airlineName, for: ac)
                classificationMessage = "Empresa aérea salva com sucesso."
            }
        } catch {
            await MainActor.run {
                classificationMessage =
                    "Não foi possível salvar. Verifique se o backend já tem os endpoints."
            }
        }
    }
}

// MARK: - AirlineClassificationSheet

private struct AirlineClassificationSheet: View {
    let aircraft: Aircraft
    let currentAirline: String?
    let suggestions: [String]
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search: String = ""
    @State private var selected: String? = nil

    private var filtered: [String] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if q.isEmpty { return suggestions }
        return suggestions.filter { $0.uppercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Info Header
                VStack(spacing: 6) {
                    HStack(spacing: 12) {
                        if let logoURL = aircraft.airlineLogoURL {
                            AsyncImage(url: logoURL) { phase in
                                if case .success(let img) = phase {
                                    img.resizable().aspectRatio(contentMode: .fit)
                                } else {
                                    Image(systemName: "airplane.circle.fill")
                                        .foregroundStyle(.blue.opacity(0.4))
                                }
                            }
                            .frame(width: 30, height: 30)
                        }
                        Text(aircraft.displayCallsign)
                            .font(.headline)
                        Spacer()
                    }
                }
                .padding()
                .background(.ultraThinMaterial)

                // Search
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Buscar companhia", text: $search)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled(true)
                }
                .padding(10)
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(10)
                .padding()

                List {
                    ForEach(filtered, id: \.self) { name in
                        Button {
                            selected = name
                        } label: {
                            HStack {
                                Text(name)
                                Spacer()
                                if selected == name {
                                    Image(systemName: "checkmark").foregroundStyle(.blue)
                                }
                            }
                        }
                        .foregroundStyle(selected == name ? .blue : .primary)
                    }
                }

                Button {
                    if let selected {
                        onSave(selected)
                        dismiss()
                    }
                } label: {
                    Text("Salvar")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selected != nil ? Color.blue : Color.gray.opacity(0.3))
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                .disabled(selected == nil)
                .padding()
            }
            .navigationTitle("Classificar Empresa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Route View Component

struct AircraftRouteView: View {
    let flight: FlightAwareFlight

    var body: some View {
        HStack {
            AirportBlock(
                code: flight.origin?.bestCode ?? "???",
                city: flight.origin?.city ?? "Origem",
                alignment: .leading
            )

            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "airplane")
                    .font(.title3)
                    .foregroundStyle(.blue)

                HStack(spacing: 4) {
                    ForEach(0..<8) { _ in
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 4, height: 4)
                    }
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            AirportBlock(
                code: flight.destination?.bestCode ?? "???",
                city: flight.destination?.city ?? "Destino",
                alignment: .trailing
            )
        }
    }
}

struct AirportBlock: View {
    let code: String
    let city: String
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(code)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
            Text(city)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(alignment == .leading ? .left : .right)
        }
        .frame(minWidth: 80)
    }
}

// MARK: - DetailRow
struct DetailRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.blue)
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .bold()
        }
    }
}

// PlaneSpottersView is now in Components/PlaneSpottersView.swift
