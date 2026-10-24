import Charts
import SwiftUI

private struct ACARSDashboard: Decodable {
    let today: Period
    let last24h: Period
    let lastHour: Int
    let topAircraft: [Aircraft]
    let topLabels: [LabelCount]
    struct Period: Decodable {
        let messages: Int
        let flights: Int
        let aircraft: Int
        let peakHour: String?
        enum CodingKeys: String, CodingKey {
            case messages, flights, aircraft
            case peakHour = "peak_hour"
        }
    }
    struct Aircraft: Decodable, Identifiable {
        let tail: String
        let flight: String?
        let count: Int
        var id: String { tail }
    }
    struct LabelCount: Decodable, Identifiable {
        let label: String
        let description: String?
        let count: Int
        var id: String { label }
    }
    enum CodingKeys: String, CodingKey {
        case today
        case last24h = "last_24h"
        case lastHour = "last_hour"
        case topAircraft = "top_aircraft"
        case topLabels = "top_labels"
    }
}

private struct ACARSHourly: Decodable {
    let hours: [Hour]
    struct Hour: Decodable, Identifiable {
        let hour: String
        let messages: Int
        let flights: Int
        var id: String { hour }
    }
}

private struct ACARSHistory: Decodable {
    let last7Days: [Day]
    let last24hHours: [Hour]
    struct Day: Decodable, Identifiable {
        let day: String
        let messages: Int
        var id: String { day }
    }
    struct Hour: Decodable, Identifiable {
        let hour: String
        let messages: Int
        var id: String { hour }
    }
    enum CodingKeys: String, CodingKey {
        case last7Days = "last_7_days", last24hHours = "last_24h_hours"
    }
}

private struct ACARSList: Decodable { let messages: [ACARSItem] }
private struct ACARSDetail: Decodable { let message: ACARSItem }
private struct ACARSSearch: Decodable { let messages: [ACARSItem] }

private struct ACARSItem: Decodable, Identifiable {
    let id: Int
    let flight: String?
    let tail: String?
    let label: String?
    let labelDesc: String?
    let departure: String?
    let destination: String?
    let text: String?
    let time: String
    let messageType: String?
    let stationId: String?
    let eta: String?
    let lat: Double?
    let lon: Double?
    let altitudeFt: Double?
    let freqMhz: Double?
    enum CodingKeys: String, CodingKey {
        case id, flight, tail, label, departure, destination, text, time, eta, lat, lon
        case labelDesc = "label_desc", messageType = "message_type", stationId = "station_id"
        case altitudeFt = "altitude_ft", freqMhz = "freq_mhz"
    }
    var title: String { flight ?? tail ?? "Sem identificação" }
    var route: String? {
        guard departure != nil || destination != nil else { return nil }
        return "\(departure ?? "—") → \(destination ?? "—")"
    }
}

struct VisionACARSView: View {
    @State private var summary: ACARSDashboard?
    @State private var hourly: [ACARSHourly.Hour] = []
    @State private var history: ACARSHistory?
    @State private var messages: [ACARSItem] = []
    @State private var results: [ACARSItem]?
    @State private var query = ""
    @State private var selected: ACARSItem?
    @State private var error: String?
    @State private var searchError: String?
    @State private var loading = false
    @State private var searching = false
    @State private var updatedAt: Date?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Label("ACARS", systemImage: "waveform.path").font(.largeTitle.bold())
                    Spacer()
                    if loading { ProgressView() }
                    Button("Atualizar", systemImage: "arrow.clockwise") { Task { await refresh() } }
                }
                if let error { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
                if let summary {
                    HStack(spacing: 14) {
                        metric("Mensagens hoje", summary.today.messages)
                        metric("Última hora", summary.lastHour)
                        metric("Voos", summary.today.flights)
                        metric("Aeronaves", summary.today.aircraft)
                    }
                    Text("Últimas 24 h: \(summary.last24h.messages) mensagens · pico \(summary.today.peakHour ?? "—")")
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 18) {
                    chartPanel("Mensagens por hora") {
                        if hourly.isEmpty { empty("Sem amostras por hora.") }
                        else {
                            Chart(hourly) { hour in
                                BarMark(x: .value("Hora", hour.hour), y: .value("Mensagens", hour.messages))
                                    .foregroundStyle(.cyan.gradient)
                            }
                            .chartXAxis(.hidden)
                            .frame(height: 180)
                        }
                    }
                    chartPanel("Últimos 7 dias") {
                        if let days = history?.last7Days, !days.isEmpty {
                            Chart(days) { day in
                                BarMark(x: .value("Dia", day.day), y: .value("Mensagens", day.messages))
                                    .foregroundStyle(.purple.gradient)
                            }
                            .chartXAxis(.hidden)
                            .frame(height: 180)
                        } else { empty("Sem histórico diário.") }
                    }
                }
                if let summary {
                    HStack(alignment: .top, spacing: 18) {
                        panel("Aeronaves mais recebidas") {
                            ForEach(summary.topAircraft) { aircraft in
                                Button {
                                    query = aircraft.tail
                                    Task { await search() }
                                } label: {
                                    HStack {
                                        Text(aircraft.tail).font(.headline)
                                        Text(aircraft.flight ?? "").foregroundStyle(.secondary)
                                        Spacer()
                                        Text("\(aircraft.count) msgs").monospacedDigit()
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        panel("Tipos de mensagem") {
                            ForEach(summary.topLabels) { label in
                                HStack {
                                    Text(label.label).font(.headline.monospaced())
                                    Text(label.description ?? "").foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(label.count)").monospacedDigit()
                                }
                            }
                        }
                    }
                }
                panel("Buscar mensagens") {
                    HStack {
                        TextField("Voo, matrícula ou texto", text: $query)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { Task { await search() } }
                        Button("Buscar", systemImage: "magnifyingglass") { Task { await search() } }
                            .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || searching)
                        if results != nil { Button("Limpar") { results = nil; query = "" } }
                    }
                    if searching { ProgressView("Buscando…") }
                    if let searchError { Text(searchError).foregroundStyle(.orange) }
                    let visible = results ?? messages
                    if visible.isEmpty { empty(results == nil ? "Nenhuma mensagem recente." : "Nenhuma mensagem encontrada.") }
                    ForEach(visible) { item in
                        Button { selected = item } label: { messageRow(item) }
                            .buttonStyle(.plain)
                    }
                }
                if let updatedAt { Text("Atualizado \(updatedAt.formatted(date: .omitted, time: .standard)) · MeuLab API")
                    .font(.caption).foregroundStyle(.secondary) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(28)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
        .sheet(item: $selected) { item in ACARSMessageSheet(item: item) }
        .task {
            while !Task.isCancelled {
                await refresh()
                do { try await Task.sleep(for: .seconds(30)) } catch { break }
            }
        }
    }

    private func refresh() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            let api = try VisionAPIClient()
            async let s: ACARSDashboard = api.fetch("api/acars/summary")
            async let h: ACARSHourly = api.fetch("api/acars/hourly")
            async let d: ACARSHistory = api.fetch("api/acars/history")
            async let m: ACARSList = api.fetch("api/acars/messages?limit=50&details=1&libacars=0")
            let (newSummary, newHours, newHistory, newMessages) = try await (s, h, d, m)
            guard !Task.isCancelled else { return }
            summary = newSummary
            hourly = newHours.hours
            history = newHistory
            messages = newMessages.messages
            updatedAt = Date()
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    private func search() async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        searching = true
        defer { searching = false }
        do {
            let encoded = term.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
            let response: ACARSSearch = try await VisionAPIClient().fetch("api/acars/search?q=\(encoded)&details=1&libacars=0")
            guard !Task.isCancelled else { return }
            results = response.messages
            searchError = nil
        } catch { searchError = error.localizedDescription }
    }

    private func metric(_ title: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text("\(value)").font(.title.bold()).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private func chartPanel<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        panel(title, content: content)
    }

    private func panel<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(title).font(.title2.bold())
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
    }

    private func empty(_ text: String) -> some View { Text(text).foregroundStyle(.secondary).padding(12) }

    private func messageRow(_ item: ACARSItem) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "envelope.badge").foregroundStyle(.cyan)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title).font(.headline)
                    Text(item.label ?? "—").font(.caption.monospaced()).foregroundStyle(.cyan)
                    Spacer()
                    Text(item.time).font(.caption).foregroundStyle(.secondary)
                }
                if let route = item.route { Text(route).font(.caption).foregroundStyle(.secondary) }
                Text(item.text ?? item.labelDesc ?? "Sem texto decodificado")
                    .font(.callout).lineLimit(2).foregroundStyle(.secondary)
            }
        }
        .padding(13)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct ACARSMessageSheet: View {
    let item: ACARSItem
    @Environment(\.dismiss) private var dismiss
    @State private var detail: ACARSItem?
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(detail?.title ?? item.title).font(.largeTitle.bold())
                    Spacer()
                    Button("Fechar", systemImage: "xmark") { dismiss() }
                }
                let message = detail ?? item
                if let error { Text(error).foregroundStyle(.orange) }
                field("Horário", message.time)
                field("Etiqueta", "\(message.label ?? "—") · \(message.labelDesc ?? "—")")
                if let route = message.route { field("Rota", route) }
                if let type = message.messageType { field("Tipo", type) }
                if let station = message.stationId { field("Estação", station) }
                if let eta = message.eta { field("ETA", eta) }
                if let frequency = message.freqMhz { field("Frequência", "\(frequency) MHz") }
                if let altitude = message.altitudeFt { field("Altitude", "\(altitude.formatted()) ft") }
                if let lat = message.lat, let lon = message.lon { field("Posição", "\(lat), \(lon)") }
                Text(message.text ?? "Sem texto decodificado")
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(28)
        }
        .frame(width: 760, height: 650)
        .task {
            do {
                let response: ACARSDetail = try await VisionAPIClient().fetch("api/acars/message/\(item.id)?libacars=0")
                detail = response.message
            } catch { self.error = error.localizedDescription }
        }
    }

    private func field(_ name: String, _ value: String) -> some View {
        HStack {
            Text(name).foregroundStyle(.secondary)
            Spacer()
            Text(value).textSelection(.enabled)
        }
    }
}
