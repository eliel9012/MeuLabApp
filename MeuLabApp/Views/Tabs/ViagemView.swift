import Combine
import CoreLocation
import SwiftUI
import UIKit

private enum TripPalette {
    static let navy = Color(red: 20/255, green: 35/255, blue: 52/255)
    static let mint = Color(red: 168/255, green: 230/255, blue: 211/255)
    static let canvas = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let ink = Color(uiColor: .label)
    static let muted = Color(uiColor: .secondaryLabel)
}

private struct TravelPlan: Decodable {
    let days: [TravelDay]
    let lounges: [TravelLounge]
    let notes: [String]

    static let current: TravelPlan = {
        guard let url = Bundle.main.url(forResource: "viagem-europa-2026", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let plan = try? JSONDecoder().decode(TravelPlan.self, from: data) else {
            assertionFailure("Roteiro de viagem ausente ou inválido")
            return TravelPlan(days: [], lounges: [], notes: [])
        }
        return plan
    }()
}

private struct TravelDay: Decodable, Identifiable {
    let id: String
    let date: String
    let weekday: String
    let place: String
    let strips: [TravelEntry]
}

private struct TravelEntry: Decodable {
    let kind: TravelKind
    let status: String
    let title: String
    let time: String?
    let end: String?
    let detail: String?
    let ref: String?
}

private enum TravelKind: String, Decodable, CaseIterable {
    case voo, pouso, evento, eleicao, terra, sala, nota

    var label: String {
        switch self {
        case .voo: "Voo"
        case .pouso: "Hospedagem"
        case .evento: "Evento"
        case .eleicao: "Cobertura eleitoral"
        case .terra: "Em terra"
        case .sala: "Sala VIP"
        case .nota: "Logística"
        }
    }

    var icon: String {
        switch self {
        case .voo: "airplane"
        case .pouso: "bed.double.fill"
        case .evento: "calendar"
        case .eleicao: "dot.radiowaves.left.and.right"
        case .terra: "tram.fill"
        case .sala: "cup.and.saucer.fill"
        case .nota: "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .voo: Color(red: 0.39, green: 0.59, blue: 0.76)
        case .pouso: Color(red: 0.49, green: 0.58, blue: 0.78)
        case .evento: Color(red: 0.40, green: 0.64, blue: 0.54)
        case .eleicao: Color(red: 0.58, green: 0.44, blue: 0.73)
        case .terra: Color(red: 0.70, green: 0.58, blue: 0.39)
        case .sala: Color(red: 0.83, green: 0.54, blue: 0.44)
        case .nota: Color(red: 0.55, green: 0.63, blue: 0.67)
        }
    }
}

private struct TravelLounge: Decodable, Identifiable {
    let id: String
    let date: String
    let airport: String
    let terminal: String
    let lounge: String
    let flight: String
    let window: String
    let level: String
    let access: String
    let logistics: String
    let source: String
    let showerSource: String
    let shower: Shower

    struct Shower: Decodable {
        let available: String
        let cost: String
        let practical: String
        let guidance: String
        let alternative: String?
    }
}

private enum TravelFilter: String, CaseIterable, Identifiable {
    case tudo, deslocamentos, programacao, hospedagem, salas
    var id: String { rawValue }
    var label: String {
        switch self {
        case .tudo: "Roteiro completo"
        case .deslocamentos: "Transportes"
        case .programacao: "Programação"
        case .hospedagem: "Hotéis"
        case .salas: "Salas VIP"
        }
    }
    func includes(_ kind: TravelKind) -> Bool {
        switch self {
        case .tudo: true
        case .deslocamentos: kind == .voo || kind == .terra
        case .programacao: kind == .evento || kind == .eleicao
        case .hospedagem: kind == .pouso
        case .salas: kind == .sala
        }
    }
}

struct ViagemView: View {
    @State private var filter: TravelFilter = .tudo
    @State private var showDetails = true
    @State private var onlyPracticalShowers = false
    @State private var now = Date()
    @StateObject private var alerts = TripNotifications.shared
    private let tick = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    private let plan = TravelPlan.current

    private var visibleDays: [TravelDay] {
        plan.days.filter { day in day.strips.contains { filter.includes($0.kind) } }
    }

    private var activeMoment: TripStop? {
        TravelMomentResolver.current(at: now, stops: TripEngine.shared.stops, plan: plan)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero
                    VStack(alignment: .leading, spacing: 26) {
                        summary
                        FlightProgressCard(legs: FlightLegBuilder.legs(from: TripEngine.shared.stops), now: now)
                        nextStep(proxy: proxy)
                        highlights(proxy: proxy)
                        lounges(proxy: proxy)
                        agenda(proxy: proxy)
                        footer
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 40)
                }
            }
            .background(TripPalette.canvas.ignoresSafeArea())
            .navigationTitle("Viagem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: printItinerary) {
                        Image(systemName: "printer")
                    }
                    .accessibilityLabel("Imprimir roteiro completo")
                }
            }
            .onReceive(tick) { now = $0 }
            .task {
                TripEngine.shared.load(ViagemBridge.makeStops())
                now = Date()
                if let current = activeMoment {
                    scrollTo(current.dayID, proxy: proxy)
                } else if let first = TripEngine.shared.stops.compactMap(\.date).min(),
                          now >= first,
                          let next = TripEngine.shared.nextStop(now: now) {
                    scrollTo(next.dayID, proxy: proxy)
                }
                await alerts.requestAuthorizationIfNeeded()
                await alerts.rescheduleAll(stops: TripEngine.shared.stops)
                if let next = TripEngine.shared.nextStop() {
                    WidgetDataManager.shared.updateTrip(title: next.title, time: "\(next.dayDate) · \(next.time)", icon: next.icon, date: next.date)
                }
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("CADERNO DE VIAGEM · 2026")
                .font(.caption.weight(.bold)).tracking(2)
                .foregroundStyle(TripPalette.mint)
            Text("EUROPA **EM ROTA.**")
                .font(.system(size: 49, weight: .black, design: .rounded))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .foregroundStyle(.white)
            Text("23 de outubro a 5 de novembro · Coberturas eleitorais em Paris e Londres, workshop PostQat e OpenSky Symposium em Madri, com passagem pelo Porto.")
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
            Text("PERCURSO COMPLETO")
                .font(.caption2.weight(.bold)).tracking(1.5)
                .foregroundStyle(Color.white.opacity(0.65))
                .padding(.top, 10)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(Array(route.enumerated()), id: \.offset) { index, city in
                        if index > 0 { Image(systemName: "arrow.right").font(.caption2).foregroundStyle(TripPalette.mint) }
                        Text(city)
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 9).padding(.vertical, 7)
                            .background(index == 0 || index == route.count - 1 ? TripPalette.mint : Color.white.opacity(0.12))
                            .foregroundStyle(index == 0 || index == route.count - 1 ? TripPalette.navy : .white)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
        .padding(.horizontal, 22).padding(.top, 34).padding(.bottom, 36)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TripPalette.navy)
    }

    private let route = ["Franca", "Londrina", "São Paulo", "Madri", "Paris", "Londres", "Madri", "Londres", "Madri", "Lisboa", "Porto", "Lisboa", "Campinas", "Franca"]

    private var summary: some View {
        let entries = plan.days.flatMap(\.strips)
        return HStack(spacing: 8) {
            stat("\(plan.days.filter { $0.id != "pre" }.count)", "dias")
            stat("\(entries.filter { $0.kind == .voo }.count)", "voos")
            stat("\(entries.filter { $0.kind == .eleicao }.count)", "coberturas")
            stat("✓", "organizado")
        }
        .padding(.top, -15)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.system(size: 27, weight: .bold, design: .rounded)).foregroundStyle(TripPalette.navy)
            Text(label).font(.caption2.weight(.semibold)).foregroundStyle(TripPalette.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
        .padding(10)
        .background(TripPalette.card, in: RoundedRectangle(cornerRadius: 10))
    }

    private func nextStep(proxy: ScrollViewProxy) -> some View {
        let current = activeMoment
        let featured = current ?? TripEngine.shared.nextStop(now: now)
        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(current == nil ? "A SEGUIR" : "AGORA · EM ANDAMENTO")
                    .font(.caption2.weight(.bold)).tracking(1.2)
                    .foregroundStyle(current == nil ? TripPalette.muted : .teal)
                Spacer()
                if alerts.scheduledCount > 0 {
                    Label("\(alerts.scheduledCount) alertas", systemImage: "bell.fill")
                        .font(.caption2).foregroundStyle(TripPalette.muted)
                }
            }
            if let featured {
                Text("\(featured.icon) \(featured.title)").font(.headline)
                Text("\(featured.dayDate) · \(featured.time) · horário local")
                    .font(.subheadline).foregroundStyle(TripPalette.muted)
                if current != nil {
                    Button("Ver na agenda") {
                        filter = .tudo
                        scrollTo(featured.dayID, proxy: proxy)
                    }
                    .font(.caption.weight(.bold)).tint(.teal)
                }
            } else {
                Text("Roteiro concluído").font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(current == nil ? TripPalette.card : Color.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(current == nil ? Color.clear : .teal, lineWidth: 1.5))
    }

    private func highlights(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Momentos principais", "Acesso aos compromissos centrais")
            let items: [(String, String, String, String)] = [
                ("25 OUT", "PARIS", "Segundo turno no Brasil", "d25"),
                ("27 OUT", "LONDRES", "Eleições em Israel", "d27"),
                ("28–30 OUT", "MADRI", "PostQat + OpenSky", "d28"),
                ("03 NOV", "PORTO", "Midterms dos EUA", "d03")
            ]
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                ForEach(items, id: \.3) { item in
                    Button {
                        filter = .tudo
                        scrollTo(item.3, proxy: proxy)
                    } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(item.0)
                                Spacer()
                                Text(item.1).foregroundStyle(.teal)
                            }
                            .font(.caption2.weight(.bold))
                            Text(item.2).font(.subheadline.weight(.bold)).foregroundStyle(TripPalette.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(13).frame(height: 94, alignment: .topLeading)
                        .background(TripPalette.card, in: RoundedRectangle(cornerRadius: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func lounges(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Salas VIP e chuveiros", "6 janelas · horários locais")
            Text("Janelas estimadas após despacho e controles. Chuveiro não garante banho: confirme fila, taxa e acesso no cartão antes de entrar.")
                .font(.subheadline).foregroundStyle(TripPalette.muted)
            Text("Prioridade: Heathrow em 28/10 e Lisboa em 04/11; GRU se chegar cedo.")
                .font(.caption.weight(.semibold)).foregroundStyle(.teal)
            Toggle("Mostrar apenas banhos possíveis", isOn: $onlyPracticalShowers)
                .font(.subheadline.weight(.semibold)).tint(.teal)
            ForEach(plan.lounges.filter { !onlyPracticalShowers || $0.shower.practical != "nao_recomendado" }) { lounge in
                loungeCard(lounge, proxy: proxy)
            }
            VStack(alignment: .leading, spacing: 7) {
                Text("Quando dispensar a sala").font(.subheadline.weight(.bold))
                ForEach(plan.notes, id: \.self) { note in
                    Text("• \(note)").font(.caption).foregroundStyle(TripPalette.muted)
                }
            }
            .padding(15).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.09), in: RoundedRectangle(cornerRadius: 11))
        }
    }

    private func loungeCard(_ item: TravelLounge, proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text("\(item.date) · \(item.airport) · \(item.terminal)")
                    .font(.caption2.weight(.bold)).foregroundStyle(TripPalette.muted)
                Spacer()
                Text(item.level == "boa" ? "Boa oportunidade" : item.level == "curta" ? "Janela curta" : "Condicional")
                    .font(.caption2.weight(.bold)).foregroundStyle(item.level == "boa" ? .green : .orange)
            }
            Text(item.lounge).font(.title3.weight(.bold))
            Text("\(item.flight) · \(item.access)").font(.caption).foregroundStyle(TripPalette.muted)
            Text(item.window).font(.title2.weight(.bold)).foregroundStyle(.teal)
            Text("Janela útil prevista · horário local").font(.caption2).foregroundStyle(TripPalette.muted)
            Text(item.logistics).font(.subheadline).foregroundStyle(TripPalette.muted)
            VStack(alignment: .leading, spacing: 6) {
                Label(showerLabel(item.shower.practical), systemImage: "shower.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(item.shower.practical == "nao_recomendado" ? .orange : .green)
                Text(item.shower.cost).font(.caption.weight(.semibold))
                Text(item.shower.guidance).font(.caption).foregroundStyle(TripPalette.muted)
                if let alternative = item.shower.alternative {
                    Text(alternative).font(.caption).foregroundStyle(TripPalette.muted)
                }
            }
            .padding(11).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            HStack(spacing: 15) {
                if let url = URL(string: item.source) { Link("Acesso ↗", destination: url) }
                if let url = URL(string: item.showerSource) { Link("Duchas ↗", destination: url) }
                Button("Ir para o dia ↓") {
                    filter = .tudo
                    scrollTo(item.id, proxy: proxy)
                }
            }
            .font(.caption.weight(.bold)).tint(.teal)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(TripPalette.card, in: RoundedRectangle(cornerRadius: 12))
    }

    private func showerLabel(_ practical: String) -> String {
        switch practical {
        case "possivel": "Banho possível, sem filas"
        case "condicional": "Banho só se sobrar tempo"
        default: "Tem ducha, mas não dá tempo"
        }
    }

    private func agenda(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Agenda dia a dia", "Horários locais em cada país")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(TravelFilter.allCases) { item in
                        Button(item.label) { filter = item }
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 11).padding(.vertical, 9)
                            .background(filter == item ? Color.teal.opacity(0.18) : TripPalette.card, in: Capsule())
                            .foregroundStyle(filter == item ? .teal : TripPalette.muted)
                    }
                }
            }
            Button(showDetails ? "Ocultar descrições" : "Exibir descrições") { showDetails.toggle() }
                .font(.caption.weight(.semibold)).tint(.teal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(visibleDays) { day in
                        Button(day.date) { scrollTo(day.id, proxy: proxy) }
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10).padding(.vertical, 8)
                            .background(TripPalette.card, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            ForEach(visibleDays) { day in
                daySection(day).id(day.id)
            }
        }
    }

    private func daySection(_ day: TravelDay) -> some View {
        let entries = Array(day.strips.enumerated()).filter { filter.includes($0.element.kind) }
        return VStack(alignment: .leading, spacing: 10) {
            Rectangle().fill(Color.gray.opacity(0.25)).frame(height: 1)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(day.date).font(.title.weight(.black)).foregroundStyle(TripPalette.navy)
                Text(day.weekday.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(TripPalette.muted)
            }
            Text(day.place).font(.subheadline.weight(.medium)).foregroundStyle(TripPalette.muted)
            ForEach(entries, id: \.offset) { index, entry in
                entryCard(entry, dayID: day.id, index: index)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func entryCard(_ entry: TravelEntry, dayID: String, index: Int) -> some View {
        let isActive = activeMoment?.id == "\(dayID).\(index)"
        return HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.time ?? "—")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.75).lineLimit(1)
                if let end = entry.end { Text("até \(end)").font(.caption2).foregroundStyle(TripPalette.muted) }
            }
            .frame(width: 77, alignment: .leading).padding(.top, 3)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: entry.kind.icon)
                    Text(entry.kind.label.uppercased())
                    Spacer()
                    if isActive { Text("AGORA").foregroundStyle(.teal) }
                    else if entry.status == "ok" { Text("✓ Confirmado").foregroundStyle(.green) }
                    if entry.status == "agenda" { Text("Na agenda").foregroundStyle(.orange) }
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(entry.kind.tint)
                Text(entry.title).font(.headline).foregroundStyle(TripPalette.ink)
                if showDetails, let detail = entry.detail {
                    Text(detail).font(.subheadline).foregroundStyle(TripPalette.muted)
                }
                if entry.kind == .sala, let lounge = plan.lounges.first(where: { $0.id == dayID }) {
                    Label("\(showerLabel(lounge.shower.practical)) · \(lounge.shower.cost)", systemImage: "shower.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(lounge.shower.practical == "nao_recomendado" ? .orange : .green)
                }
                if let ref = entry.ref {
                    Text(ref).font(.caption.weight(.semibold))
                        .padding(.horizontal, 7).padding(.vertical, 4)
                        .background(Color.gray.opacity(0.11), in: RoundedRectangle(cornerRadius: 4))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isActive ? Color.teal.opacity(0.12) : TripPalette.card, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(isActive ? Color.teal : Color.clear, lineWidth: 1.5))
        .shadow(color: isActive ? Color.teal.opacity(0.16) : .clear, radius: 10, y: 3)
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 10)
                .fill(entry.kind.tint).frame(width: 4)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 9) {
            Divider()
            Text("Banhos: ducha e entrada podem ter cobranças separadas. Confira fila e acesso na recepção.")
            Text("Horas locais de cada trecho. Priorize cartões de embarque e avisos atuais dos operadores.")
        }
        .font(.caption).foregroundStyle(TripPalette.muted)
    }

    private func sectionTitle(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.title2.weight(.bold)).foregroundStyle(TripPalette.ink)
            Text(subtitle).font(.caption).foregroundStyle(TripPalette.muted)
        }
    }

    private func printItinerary() {
        let sections = plan.days.map { day in
            let entries = day.strips.map { entry in
                let time = entry.time.map { "<strong>\(escapeHTML($0))</strong> " } ?? ""
                let end = entry.end.map { " até \(escapeHTML($0))" } ?? ""
                let detail = entry.detail.map { "<p>\(escapeHTML($0))</p>" } ?? ""
                let ref = entry.ref.map { "<small>\(escapeHTML($0))</small>" } ?? ""
                return "<li>\(time)\(end) — \(escapeHTML(entry.title))\(detail)\(ref)</li>"
            }.joined()
            return "<section><h2>\(escapeHTML(day.date)) · \(escapeHTML(day.weekday)) — \(escapeHTML(day.place))</h2><ul>\(entries)</ul></section>"
        }.joined()
        let html = """
        <html><head><meta charset="utf-8"><style>
        body { font: 12px -apple-system, sans-serif; color: #142334; }
        h1 { font-size: 26px; } h2 { font-size: 16px; border-bottom: 1px solid #ccd5dc; padding-bottom: 5px; }
        section { break-inside: avoid; } li { margin: 0 0 10px; } p { margin: 3px 0; color: #425769; }
        small { color: #607484; }
        </style></head><body><h1>Europa em rota · 2026</h1>\(sections)</body></html>
        """
        let printer = UIPrintInteractionController.shared
        let info = UIPrintInfo(dictionary: nil)
        info.jobName = "Roteiro Europa 2026"
        info.outputType = .general
        printer.printInfo = info
        printer.printFormatter = UIMarkupTextPrintFormatter(markupText: html)
        printer.present(animated: true, completionHandler: nil)
    }

    private func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func scrollTo(_ id: String, proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo(id, anchor: .top) }
        }
    }
}

// All comparisons use absolute Date values. TripStop start times were parsed in
// each event's local time zone; the phone's display time zone never shifts them.
private enum TravelMomentResolver {
    static func current(at now: Date, stops: [TripStop], plan: TravelPlan) -> TripStop? {
        let timed = stops.filter { $0.date != nil }
        let flightEnds = Dictionary(uniqueKeysWithValues: FlightLegBuilder.legs(from: stops).map { ($0.stopID, $0.scheduledArrival) })
        for stop in timed.reversed() {
            guard let start = stop.date, start <= now,
                  let index = Int(stop.id.split(separator: ".").last ?? ""),
                  let entry = plan.days.first(where: { $0.id == stop.dayID })?.strips[safe: index]
            else { continue }

            let end: Date
            if entry.kind == .voo, let arrival = flightEnds[stop.id] {
                end = arrival
            } else if let endText = entry.end,
                      let parsed = TripParser.date(dateText: stop.dayDate, timeText: endText, timeZone: stop.timeZone) {
                if endText.contains("+1") || parsed <= start {
                    var calendar = Calendar(identifier: .gregorian)
                    calendar.timeZone = stop.timeZone ?? .current
                    end = calendar.date(byAdding: .day, value: 1, to: parsed) ?? parsed
                } else {
                    end = parsed
                }
            } else {
                let duration: TimeInterval = entry.kind == .eleicao ? 4 * 3600 : 2 * 3600
                let next = timed.first { ($0.date ?? .distantPast) > start }?.date ?? .distantFuture
                end = min(start.addingTimeInterval(duration), next)
            }
            if now < end { return stop }
        }
        return nil
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview { NavigationStack { ViagemView() } }

// MARK: - Itinerary bridge for notifications, widgets and flight tracking

enum ViagemBridge {
    @MainActor static func makeStops() -> [TripStop] {
        let plan = TravelPlan.current
        var stops: [TripStop] = []
        for day in plan.days {
            let dateText = parserDate(day.date)
            for (index, entry) in day.strips.enumerated() {
                let zoneID = zone(for: day.id, index: index)
                let zone = TimeZone(identifier: zoneID)
                let title = entry.kind == .voo ? flightTitle(for: day.id, index: index, fallback: entry.title) : entry.title
                let detail = entry.kind == .voo && entry.end != nil ? "Chegada \(entry.end!). \(entry.detail ?? "")" : (entry.detail ?? "")
                let coordinate = coordinate(for: entry.title)
                stops.append(TripStop(
                    id: "\(day.id).\(index)", dayID: day.id, dayTitle: day.place,
                    dayDate: dateText, time: entry.time ?? "—", icon: entry.kind.icon,
                    title: title, detail: detail, address: nil, ref: entry.ref,
                    latitude: coordinate?.latitude, longitude: coordinate?.longitude,
                    timeZoneID: zoneID,
                    date: TripParser.date(dateText: dateText, timeText: entry.time ?? "", timeZone: zone)
                ))
            }
        }
        return stops.sorted {
            switch ($0.date, $1.date) {
            case let (a?, b?): a < b
            case (nil, _?): true
            case (_?, nil): false
            case (nil, nil): $0.id < $1.id
            }
        }
    }

    private static func parserDate(_ text: String) -> String {
        guard let slash = text.firstIndex(of: "/"),
              let day = Int(text[..<slash]), let month = Int(text[text.index(after: slash)...].prefix(2)) else { return "22 out" }
        return "\(day) \(month == 11 ? "nov" : "out")"
    }

    private static func zone(for day: String, index: Int) -> String {
        switch day {
        case "d25": index >= 4 ? "Europe/Paris" : "Europe/Madrid"
        case "d26": index >= 6 ? "Europe/London" : "Europe/Paris"
        case "d27", "d01": "Europe/London"
        case "d28": index >= 3 ? "Europe/Madrid" : "Europe/London"
        case "d29", "d30": "Europe/Madrid"
        case "d31": index >= 3 ? "Europe/London" : "Europe/Madrid"
        case "d02": index >= 3 ? "Europe/Madrid" : "Europe/London"
        case "d03": index >= 3 ? "Europe/Lisbon" : "Europe/Madrid"
        case "d04": index >= 4 ? "America/Sao_Paulo" : "Europe/Lisbon"
        default: "America/Sao_Paulo"
        }
    }

    private static func flightTitle(for day: String, index: Int, fallback: String) -> String {
        let route: (String, String, String)? = switch (day, index) {
        case ("d23", 1): ("AD4211", "Ribeirão Preto", "Londrina")
        case ("d24", 0): ("G31209", "Londrina", "São Paulo")
        case ("d24", 3): ("UX058", "Guarulhos", "Madri")
        case ("d25", 3): ("TO4631", "Madri", "Paris")
        case ("d28", 2): ("IB0712", "London Heathrow", "Madri")
        case ("d31", 2): ("BA Cityflyer", "Madri", "London City")
        case ("d02", 2): ("BA Cityflyer", "London City", "Madri")
        case ("d03", 2): ("UX7854", "Madri", "Lisboa")
        case ("d04", 3): ("AD8751", "Lisboa", "Campinas")
        default: nil
        }
        guard let route else { return "Voo — \(fallback)" }
        return "Voo \(route.0) — \(route.1) → \(route.2)"
    }

    private static func coordinate(for title: String) -> CLLocationCoordinate2D? {
        let airports: [(String, Double, Double)] = [
            ("RAO →", -21.1392, -47.7765), ("LDB →", -23.3285, -51.1378),
            ("GRU →", -23.4263, -46.4817), ("MAD →", 40.4722, -3.5608),
            ("LHR →", 51.4700, -0.4543), ("LCY →", 51.5053, 0.0553),
            ("LIS →", 38.7742, -9.1342)
        ]
        guard let match = airports.first(where: { title.contains($0.0) }) else { return nil }
        return CLLocationCoordinate2D(latitude: match.1, longitude: match.2)
    }
}
