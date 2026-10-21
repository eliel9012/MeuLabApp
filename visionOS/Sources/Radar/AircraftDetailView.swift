import SwiftUI

struct AircraftDetailView: View {
    @Environment(FlightStore.self) private var store

    var body: some View {
        if let aircraft = store.selectedAircraft {
            HStack(spacing: 18) {
                Image(systemName: "airplane")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.cyan)
                    .frame(width: 64)

                VStack(alignment: .leading, spacing: 4) {
                    Text(aircraft.callsign)
                        .font(.title3.bold())
                    Text([aircraft.aircraftType, aircraft.description, aircraft.registration].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                metric("Altitude", aircraft.altitudeFeet.map { "\(Int($0).formatted()) ft" } ?? "—", "mountain.2")
                metric("Velocidade", aircraft.speedKilometersPerHour.map { "\(Int($0).formatted()) km/h" } ?? "—", "speedometer")
                metric("Rumo", aircraft.trackDegrees.map { "\(Int($0))°" } ?? "—", "location.north")

                Button("Fechar", systemImage: "xmark") { store.selectedHex = nil }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
            }
            .padding(18)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.15)))
        }
    }

    private func metric(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold())
                .monospacedDigit()
        }
        .frame(minWidth: 95, alignment: .leading)
    }
}
