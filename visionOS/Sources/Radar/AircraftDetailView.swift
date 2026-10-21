import SwiftUI

struct AircraftDetailView: View {
    @Environment(FlightStore.self) private var store

    var body: some View {
        if let aircraft = store.selectedAircraft {
            HStack(alignment: .top, spacing: 16) {
                VisionAircraftPhotoView(aircraft: aircraft)
                    .frame(width: 178, height: 146)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(aircraft.callsign).font(.title3.bold())
                            Text([aircraft.aircraftType, aircraft.description, aircraft.registration]
                                .compactMap { $0 }.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button("Fechar", systemImage: "xmark") { store.selectedHex = nil }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.plain)
                    }

                    HStack(spacing: 18) {
                        metric("Altitude", aircraft.altitudeFeet.map { "\(Int($0).formatted()) ft" } ?? "—", "mountain.2")
                        metric("Velocidade", aircraft.speedKilometersPerHour.map { "\(Int($0).formatted()) km/h" } ?? "—", "speedometer")
                        metric("Rumo", aircraft.trackDegrees.map { "\(Int($0))°" } ?? "—", "location.north")
                    }
                    VisionFlightAwareView(aircraft: aircraft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.15)))
        }
    }

    private func metric(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: symbol)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value).font(.subheadline.bold()).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct VisionAircraftPhotoView: View {
    let aircraft: Aircraft
    @State private var photo: VisionAircraftPhoto?
    @State private var loading = true

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let photo {
                AsyncImage(url: photo.url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    case .failure: placeholder("Erro na foto")
                    default: ProgressView()
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(photo.source).bold()
                    if let photographer = photo.photographer { Text("© \(photographer)") }
                }
                .font(.system(size: 10))
                .padding(6)
                .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 7))
                .padding(7)
            } else if loading {
                ProgressView()
            } else {
                placeholder("Sem foto")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task(id: aircraft.hex) {
            photo = nil
            loading = true
            let result = await VisionFlightEnrichmentService.shared.photo(for: aircraft)
            guard !Task.isCancelled else { return }
            photo = result
            loading = false
        }
    }

    private func placeholder(_ title: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: "photo").font(.title2)
            Text(title).font(.caption2)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct VisionFlightAwareView: View {
    let aircraft: Aircraft
    @State private var flight: FlightAwareFlight?
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 10) {
                Label("FlightAware", systemImage: "clock.badge.checkmark")
                    .font(.caption.bold())
                    .foregroundStyle(.cyan)
                if loading { ProgressView().controlSize(.small) }
                Spacer(minLength: 0)
                if let flight { Text(status(flight)).foregroundStyle(.green) }
            }
            if let flight {
                HStack(spacing: 12) {
                    Text("\(place(flight.origin)) → \(place(flight.destination))")
                        .font(.subheadline.bold())
                    Spacer(minLength: 0)
                    if let departure = FlightAwareTime.short(flight.actualOut)
                        ?? FlightAwareTime.short(flight.estimatedOut)
                        ?? FlightAwareTime.short(flight.scheduledOut) {
                        Text("Saída \(departure)")
                    }
                    if let arrival = FlightAwareTime.short(flight.actualIn)
                        ?? FlightAwareTime.short(flight.estimatedIn)
                        ?? FlightAwareTime.short(flight.scheduledIn) {
                        Text("Chegada \(arrival)")
                    }
                    if flight.terminalDestination != nil || flight.gateDestination != nil {
                        Text("T\(flight.terminalDestination ?? "—") · G\(flight.gateDestination ?? "—")")
                    }
                }
            } else if !loading {
                Text(error ?? "Sem dados para este voo").foregroundStyle(.secondary)
            }
        }
        .font(.caption2)
        .lineLimit(1)
        .task(id: aircraft.callsign) {
            flight = nil
            error = nil
            loading = true
            do {
                let result = try await VisionFlightEnrichmentService.shared.flightAware(for: aircraft)
                guard !Task.isCancelled else { return }
                flight = result
            } catch {
                guard !Task.isCancelled else { return }
                self.error = error.localizedDescription
            }
            loading = false
        }
    }

    private func status(_ flight: FlightAwareFlight) -> String {
        if flight.actualIn != nil || flight.actualOn != nil { return "Pousado" }
        if flight.actualOff != nil || flight.actualOut != nil { return "Em voo" }
        if flight.estimatedOut != nil || flight.scheduledOut != nil { return "Programado" }
        return "Sem status"
    }

    private func place(_ airport: FlightAwareAirportRef?) -> String {
        guard let airport else { return "—" }
        let code = airport.bestCode
        if code.hasPrefix("L ") { return airport.city ?? airport.name ?? "Localização" }
        return code
    }
}
